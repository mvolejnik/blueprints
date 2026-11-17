#!/bin/bash
# Keeps the container alive in the background; you open shells with `docker exec`.
set -e

mkdir -p "$HOME/.claude"

# k6 agent kit (staged at build time, see Dockerfile): refresh k6-* skills at user scope.
k6_stage="$HOME/.local/share/k6-agent"
if [ -d "$k6_stage/.claude/skills" ]; then
  mkdir -p "$HOME/.claude/skills"
  for s in "$k6_stage"/.claude/skills/*/; do
    name="$(basename "$s")"
    rm -rf "$HOME/.claude/skills/$name"
    cp -r "$s" "$HOME/.claude/skills/$name"
  done
fi

# k6 MCP server (`k6 x mcp`) at user scope, so it's available in every project.
# ~/.claude.json is not on a volume, so (re)register on every start. Always remove + add at
# user scope: `claude mcp get k6` would also match a project-scoped .mcp.json in the cwd
# (e.g. /workspace/.mcp.json) and wrongly skip the user-scope registration.
if command -v k6 >/dev/null 2>&1; then
  claude mcp remove --scope user k6 >/dev/null 2>&1 || true
  claude mcp add-json --scope user k6 '{"type":"stdio","command":"k6","args":["x","mcp"]}' >/dev/null \
    || echo "warning: could not register k6 MCP server" >&2
fi

# Run whatever CMD / `docker run ... <command>` was given (default: sleep infinity)
exec "$@"
