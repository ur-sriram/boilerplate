/**
 * OpenCode Plugin: Ponytail Context Compactor
 * Enforces project-local context compaction guidelines without touching global state.
 */
export default {
  name: "ponytail-compactor",
  version: "1.0.0",
  onSessionStart() {
    return { status: "active", mode: "project-local" };
  }
};
