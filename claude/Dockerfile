# syntax=docker/dockerfile:1

# ---- Versions (override with --build-arg, e.g. --build-arg JAVA_VERSION=26) ----
# Java: latest LTS. Go / k6: "latest" resolves at build time.
# Python: empty = latest stable (installed via uv). WireMock: empty = latest stable from Maven Central.
ARG JAVA_VERSION=26
ARG GO_VERSION=latest
ARG K6_VERSION=latest

FROM golang:${GO_VERSION} AS go
FROM grafana/k6:${K6_VERSION} AS k6

# ------------------------------------------------------------------------------
FROM debian:bookworm-slim

ARG JAVA_VERSION
ARG PYTHON_VERSION=
ARG WIREMOCK_VERSION=
ARG GOLANGCI_LINT_VERSION=2.15.0
ARG XK6_VERSION=1.4.7

RUN apt-get update && apt-get install -y --no-install-recommends \
      curl ca-certificates gnupg git ripgrep less openssh-client \
      gcc libc6-dev make fontconfig tzdata \
    && rm -rf /var/lib/apt/lists/*

# Java: Azul Zulu JDK (OpenJDK build) from Azul's apt repo
RUN curl -fsSL https://repos.azul.com/azul-repo.key | gpg --dearmor -o /usr/share/keyrings/azul.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/azul.gpg] https://repos.azul.com/zulu/deb stable main" \
       > /etc/apt/sources.list.d/zulu.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends "zulu${JAVA_VERSION}-jdk-headless" \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s "$(dirname "$(dirname "$(readlink -f /usr/bin/javac)")")" /opt/java

# Go toolchain, k6
COPY --from=go /usr/local/go /usr/local/go
COPY --from=k6 /usr/bin/k6   /usr/local/bin/k6

ENV JAVA_HOME=/opt/java
ENV PATH="${JAVA_HOME}/bin:/usr/local/go/bin:${PATH}"

# WireMock standalone: latest stable (betas excluded) unless WIREMOCK_VERSION is set
RUN set -eux; \
    base=https://repo1.maven.org/maven2/org/wiremock/wiremock-standalone; \
    v="${WIREMOCK_VERSION}"; \
    if [ -z "$v" ]; then \
      v=$(curl -fsSL "$base/maven-metadata.xml" \
          | grep -oP '(?<=<version>)[0-9]+\.[0-9]+\.[0-9]+(?=</version>)' \
          | sort -V | tail -1); \
    fi; \
    curl -fsSL -o /opt/wiremock-standalone.jar "$base/$v/wiremock-standalone-$v.jar"; \
    printf '#!/bin/sh\nexec java -jar /opt/wiremock-standalone.jar "$@"\n' > /usr/local/bin/wiremock; \
    chmod +x /usr/local/bin/wiremock

# golangci-lint (same version as CI)
RUN curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/HEAD/install.sh \
    | sh -s -- -b /usr/local/bin "v${GOLANGCI_LINT_VERSION}"

# xk6 release binary (CI uses grafana/xk6:latest, release workflow pins 1.4.7)
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    curl -fsSL "https://github.com/grafana/xk6/releases/download/v${XK6_VERSION}/xk6_${XK6_VERSION}_linux_${arch}.tar.gz" \
      | tar -xz -C /usr/local/bin xk6

# GitHub CLI from GitHub's apt repo (Debian's gh is old), jq, node + tsc for typings checks
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh jq nodejs npm \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g typescript

# Non-root user
RUN useradd -m -s /bin/bash claude
USER claude
WORKDIR /workspace

ENV PATH="/home/claude/.local/bin:/home/claude/go/bin:${PATH}"

# Python via uv (latest stable unless PYTHON_VERSION is set), exposed as python/python3
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && uv python install ${PYTHON_VERSION} \
    && py="$(uv python find ${PYTHON_VERSION})" \
    && ln -sf "$py" /home/claude/.local/bin/python3 \
    && ln -sf "$py" /home/claude/.local/bin/python

# Claude Code (native installer)
RUN curl -fsSL https://claude.ai/install.sh | bash

COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]