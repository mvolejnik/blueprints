# syntax=docker/dockerfile:1

# ---- Versions (override with --build-arg, e.g. --build-arg JAVA_VERSION=26) ----
# Java: latest LTS. Go / k6: "latest" resolves at build time.
# Python: empty = latest stable (installed via uv). WireMock: empty = latest stable from Maven Central.
# Gradle: empty = current release from services.gradle.org. kubectl: empty = latest stable from dl.k8s.io.
# Ansible: empty = latest stable from PyPI, run on ANSIBLE_PYTHON_VERSION (a Python ansible-core supports).
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
ARG GRADLE_VERSION=
ARG GOLANGCI_LINT_VERSION=2.15.0
ARG XK6_VERSION=1.4.7
ARG KUBECTL_VERSION=
ARG ANSIBLE_VERSION=
ARG ANSIBLE_PYTHON_VERSION=3.14

RUN apt-get update && apt-get install -y --no-install-recommends \
      curl ca-certificates gnupg git ripgrep less openssh-client \
      gcc libc6-dev make fontconfig tzdata unzip \
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
ENV PATH="${JAVA_HOME}/bin:/usr/local/go/bin:/opt/gradle/bin:${PATH}"

# Gradle: current release unless GRADLE_VERSION is set
RUN set -eux; \
    v="${GRADLE_VERSION}"; \
    if [ -z "$v" ]; then \
      v=$(curl -fsSL https://services.gradle.org/versions/current | grep -oP '(?<="version" : ")[^"]+'); \
    fi; \
    curl -fsSL -o /tmp/gradle.zip "https://services.gradle.org/distributions/gradle-$v-bin.zip"; \
    unzip -q /tmp/gradle.zip -d /opt; \
    mv "/opt/gradle-$v" /opt/gradle; \
    rm /tmp/gradle.zip

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

# kubectl: latest stable unless KUBECTL_VERSION is set (e.g. 1.34.1), checksum-verified
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    v="${KUBECTL_VERSION}"; \
    if [ -z "$v" ]; then v=$(curl -fsSL https://dl.k8s.io/release/stable.txt); else v="v${v#v}"; fi; \
    base="https://dl.k8s.io/release/$v/bin/linux/$arch"; \
    curl -fsSL -o /usr/local/bin/kubectl "$base/kubectl"; \
    echo "$(curl -fsSL "$base/kubectl.sha256")  /usr/local/bin/kubectl" | sha256sum -c -; \
    chmod +x /usr/local/bin/kubectl

# GitHub CLI from GitHub's apt repo (Debian's gh is old), jq, node + tsc for typings checks
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
       > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh jq nodejs npm \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g typescript

# Docker CLI + Compose v2 + Buildx from Docker's official apt repo (latest, not Debian's docker.io).
# CLI only: talks to the "docker" (docker:dind) sidecar from compose.yaml via DOCKER_HOST,
# never to the host daemon.
RUN set -eux; \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg; \
    . /etc/os-release; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" \
      > /etc/apt/sources.list.d/docker.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin docker-buildx-plugin; \
    rm -rf /var/lib/apt/lists/*; \
    docker --version; docker compose version

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

# Ansible from PyPI (not the distro package) in an isolated venv via uv (pipx equivalent).
# Latest stable unless ANSIBLE_VERSION is set; exposes ansible-core's CLIs (ansible, ansible-playbook, ...)
# Runs on its own Python (ANSIBLE_PYTHON_VERSION): ansible-core lags new CPython releases
# (e.g. breaks on 3.15 with "dataclasses has no attribute _is_type").
RUN uv tool install --python "${ANSIBLE_PYTHON_VERSION}" \
      --with-executables-from ansible-core \
      "ansible${ANSIBLE_VERSION:+==${ANSIBLE_VERSION}}" \
    && ansible --version

# Claude Code (native installer)
RUN curl -fsSL https://claude.ai/install.sh | bash

COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]