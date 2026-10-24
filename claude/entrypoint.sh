#!/bin/bash
# Keeps the container alive in the background; you open shells with `docker exec`.
set -e
 
mkdir -p "$HOME/.claude"
 
# Run whatever CMD / `docker run ... <command>` was given (default: sleep infinity)
exec "$@"
 