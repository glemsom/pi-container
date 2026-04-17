FROM node:25-bookworm

# Install dependencies for terminal and clipboard support
RUN apt-get update && apt-get install -y \
    dumb-init \
    apt-utils \
    curl \
    git \
    openssh-client \
    gpg \
    ripgrep \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI (gh)
# See https://github.com/cli/cli/blob/trunk/docs/install_linux.md#debian
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install gh \
    && rm -rf /etc/apt/sources.list.d/github-cli.list

# Install Docker CLI for host docker access
RUN apt-get update && apt-get install -y docker.io && rm -rf /var/lib/apt/lists/*

ENV PATH="/home/node/.local/bin:$PATH"
ENV BASH_ENV="/home/node/.lean-ctx/env.sh"

RUN mkdir -p /home/node/.pi/agent/extensions \
                /home/node/.pi/agent/skills \
                /home/node/.pi/agent/themes \
                /home/node/.pi/agent/prompts
RUN mkdir /workspace

RUN chown -R node:node /home/node/.pi
RUN chown -R node:node /workspace

# Store default MCP configuration at a fixed location (not under ~/.pi to avoid mount conflicts)
# Must run as root before USER change
RUN mkdir -p /etc/pi-mcp && \
    cat > /etc/pi-mcp/default.json << 'EOF'
{
  "settings": {
    "toolPrefix": "none",
    "idleTimeout": 10
  },
  "mcpServers": {
    "lean-ctx": {
      "command": "lean-ctx",
      "lifecycle": "lazy"
    },
    "context7": {
      "command": "context7-mcp",
      "env": {
        "CONTEXT7_API_KEY": "${CONTEXT7_API_KEY}"
      },
      "lifecycle": "lazy"
    }
  }
}
EOF

USER node

RUN npm config set prefix /home/node/.local

RUN npm install -g @mariozechner/pi-coding-agent
RUN npm install -g lean-ctx-bin
RUN npm install -g @aliou/pi-guardrails
RUN npm install -g @mjakl/pi-subagent

# Install MCP servers
RUN npm install -g @upstash/context7-mcp

# Install Pi extensions
RUN pi install npm:pi-mcp-adapter

RUN touch /home/node/.bashrc && lean-ctx bootstrap

RUN npm install -g ctx7

# Copy entrypoint script (before USER change, as root)
COPY entrypoint.sh /entrypoint.sh

WORKDIR /workspace
RUN lean-ctx init --agent pi



# Use dumb-init to handle signals properly, then entrypoint for MCP bootstrap
ENTRYPOINT ["dumb-init", "--", "/entrypoint.sh"]

# Default command
CMD ["pi"]