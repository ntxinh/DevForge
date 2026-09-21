// Root entrypoint for OpenCode V2 directory-form plugin registration.
//
// OpenCode V2 hosts (2.0.4 or later) require config plugin entries to be
// directories with an index entrypoint (`index.js`) and reject bare file
// paths ("configured plugin path must be a directory"). This file serves
// only that directory form — an absolute path such as
// `"plugins": ["/path/to/DevForge"]` (`~` is not expanded). npm and git
// package installs resolve via package.json `main`, which points at
// `.opencode/plugins/devforge.js` directly and never loads this file.
export { default } from "./.opencode/plugins/devforge.js";
