/**
 * DevForge plugin for OpenCode.ai — registers this repository's skills.
 *
 * Dual-compatible with OpenCode V1 and V2.
 *
 * V1 (opencode 1.x): loaded via the named export DevForgePlugin, whose
 * config hook pushes the skills directory onto config.skills.paths.
 *
 * V2 (opencode 2.0.4 or later): loaded via the default export { id, setup }.
 * setup() registers each skill natively through ctx.skill.transform().
 *
 * DevForge ships no session bootstrap, so there is no message or context
 * hook here — only skill registration.
 *
 * No external dependencies: works in both V1 and V2 without installing
 * @opencode-ai/plugin.
 */

import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Skills directory shared by V1 (config hook) and V2 (ctx.skill.transform).
const skillsDir = path.resolve(__dirname, '../../skills');

// Simple frontmatter extraction. Handles plain `key: value` lines, quoted
// values (including quotes that close on an indented continuation line),
// YAML block scalar markers (`>`, `|`) with indented continuation lines, and
// CRLF line endings. Not a full YAML parser — nested maps flatten into their
// parent key's value, which is fine for the name/description fields consumed
// here.
const extractAndStripFrontmatter = (content) => {
  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
  if (!match) return { frontmatter: {}, content };

  const frontmatterStr = match[1];
  const body = match[2];
  const frontmatter = {};
  let lastKey = null;

  for (const rawLine of frontmatterStr.split('\n')) {
    const line = rawLine.replace(/\r$/, '');
    const colonIdx = line.indexOf(':');
    if (colonIdx > 0 && !/^\s/.test(line)) {
      const key = line.slice(0, colonIdx).trim();
      const value = line.slice(colonIdx + 1).trim();
      // Block scalar markers (>, |, optionally with +/- chomping) carry no
      // value themselves; the indented lines that follow do.
      frontmatter[key] = /^(>[+-]?|\|[+-]?)$/.test(value) ? '' : value;
      lastKey = key;
    } else if (lastKey !== null && line.trim() !== '') {
      // Continuation of a multi-line value: append rather than drop so long
      // descriptions survive parsing.
      frontmatter[lastKey] = `${frontmatter[lastKey]} ${line.trim()}`.trim();
    }
  }

  // A quoted value may close on a continuation line, so unquote only once the
  // value is fully assembled: strip exactly one matching surrounding pair and
  // leave unbalanced quotes alone.
  for (const key of Object.keys(frontmatter)) {
    frontmatter[key] = frontmatter[key].replace(/^(["'])([\s\S]*)\1$/, '$2');
  }

  return { frontmatter, content: body };
};

// Read every skills/<name>/SKILL.md into the Skill.Info shape V2 expects:
// { id, name, description?, path, content }. The file field is `path` —
// renamed from `location` upstream and released in OpenCode v2.0.4.
const readSkills = () => {
  const skills = [];
  if (!fs.existsSync(skillsDir)) return skills;

  for (const entry of fs.readdirSync(skillsDir, { withFileTypes: true })) {
    if (!entry.isDirectory() || entry.name.startsWith('.')) continue;
    const skillPath = path.join(skillsDir, entry.name, 'SKILL.md');
    if (!fs.existsSync(skillPath)) continue;

    const { frontmatter, content } = extractAndStripFrontmatter(
      fs.readFileSync(skillPath, 'utf8'),
    );
    skills.push({
      id: entry.name,
      name: frontmatter.name || entry.name,
      ...(frontmatter.description ? { description: frontmatter.description } : {}),
      path: skillPath,
      content,
    });
  }

  return skills;
};

/**
 * V1 plugin function (named export, also re-exported as default.server).
 *
 * Injects the skills path into the live config so OpenCode discovers DevForge
 * skills without manual symlinks or config file edits.
 */
export const DevForgePlugin = async () => ({
  config: async (config) => {
    // V2 represents skills as a flat array — leave it to setup().
    if (Array.isArray(config.skills)) return;

    // V1 represents skills as { paths: [...] }.
    config.skills = config.skills || {};
    config.skills.paths = config.skills.paths || [];
    if (!config.skills.paths.includes(skillsDir)) {
      config.skills.paths.push(skillsDir);
    }
  },
});

/**
 * V2 setup function (default.setup), called by the V2 PluginSupervisor.
 *
 * V1 also invokes default.setup, but with a V1-shaped ctx that lacks the
 * skill domain — detect that and return quietly, since V1 is served entirely
 * by the DevForgePlugin named export.
 */
async function setup(ctx) {
  if (!ctx || !ctx.skill || typeof ctx.skill.transform !== 'function') return;

  try {
    const skills = readSkills();
    await ctx.skill.transform((draft) => {
      // draft.add() decodes against the host's Skill.Info schema and throws
      // synchronously on a mismatch. A throw escaping this callback is what
      // the host escalates into a hard-disable of the whole plugin, so
      // contain failures per skill: one rejected payload skips that skill
      // instead of killing registration entirely.
      for (const skill of skills) {
        try {
          draft.add(skill);
        } catch (err) {
          console.error(`[devforge] skill "${skill.id}" rejected by host, skipping:`, err);
        }
      }
    });
  } catch (err) {
    // Never break plugin activation: one failing plugin takes down the whole
    // V2 generation, including provider plugins.
    console.error('[devforge] skill registration failed:', err);
  }
}

export default {
  id: 'devforge',
  server: DevForgePlugin,
  setup,
};
