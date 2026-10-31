#!/usr/bin/env bash

docker volume create claude-config

docker run -it --rm \
  -v "$PWD":/workspace \
  -v claude-config:/home/claude/.claude \
  claude-box