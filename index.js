// Root entrypoint for OpenCode V2 directory-form plugin registration.
//
// OpenCode V2 hosts (2.0.4 or later) require config plugin entries to be
// directories with an index entrypoint (`index.js`) and reject bare file
// paths ("configured plugin path must be a directory"). npm and git package
// installs resolve via package.json `main`; this file serves the directory
// form, an absolute path such as `"plugins": ["/path/to/DevForge"]`
// (`~` is not expanded).
export { default } from "./.opencode/plugins/devforge.js";
