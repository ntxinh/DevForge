// Asserts the OpenCode plugin registers this repository's skills on both the
// V1 (config hook) and V2 (ctx.skill.transform) code paths, and that it stays
// quiet when handed a context shape it does not understand.
import assert from 'node:assert/strict';
import plugin from '../index.js';
import { DevForgePlugin } from '../.opencode/plugins/devforge.js';

assert.equal(plugin.id, 'devforge', 'default export carries the plugin id');
assert.equal(typeof plugin.setup, 'function', 'default export exposes setup()');

// --- V2: setup() registers skills via ctx.skill.transform -------------------
const added = [];
await plugin.setup({
  skill: { transform: async (fn) => fn({ add: (s) => added.push(s) }) },
});

const jira = added.find((s) => s.id === 'jira-issue-to-markdown');
assert.ok(jira, 'jira-issue-to-markdown is registered');
assert.equal(jira.name, 'jira-issue-to-markdown', 'name comes from frontmatter');
assert.ok(jira.description && jira.description.length > 20, 'description is populated');
assert.ok(jira.path.endsWith('/skills/jira-issue-to-markdown/SKILL.md'), 'path is absolute');
assert.ok(!jira.content.startsWith('---'), 'frontmatter is stripped from content');
assert.ok(jira.content.includes('# Jira Issue'), 'body content survives');

// --- V2: a rejecting host skips one skill without throwing ------------------
await plugin.setup({
  skill: {
    transform: async (fn) => fn({ add: () => { throw new Error('rejected'); } }),
  },
});

// --- V1: named export config hook appends the skills directory --------------
const hooks = await DevForgePlugin({});
const config = {};
await hooks.config(config);
assert.ok(
  config.skills.paths.some((p) => p.endsWith('/skills')),
  'V1 config hook adds the skills directory',
);

// Calling it twice must not duplicate the entry.
await hooks.config(config);
assert.equal(config.skills.paths.length, 1, 'skills path is not duplicated');

// V2-shaped config (flat array) is left alone by the V1 hook.
const v2Config = { skills: [] };
await hooks.config(v2Config);
assert.deepEqual(v2Config.skills, [], 'V2 config shape untouched by the V1 hook');

// --- A V1-shaped ctx passed to setup() must return quietly ------------------
await plugin.setup({});
await plugin.setup(undefined);

console.log('ok: opencode plugin registers skills on V1 and V2');
