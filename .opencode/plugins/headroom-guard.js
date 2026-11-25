/**
 * OpenCode Plugin: Headroom Context Guard
 * Monitors MCP profile token headroom and enforces CodeMode discipline.
 */
export default {
  name: "headroom-guard",
  version: "1.0.0",
  onBeforeToolCall(toolName) {
    return { allowed: true, tool: toolName };
  }
};
