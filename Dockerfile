FROM node:25-bookworm

# Install dependencies for terminal and clipboard support
RUN apt-get update && apt-get install -y \
    dumb-init \
    curl \
    git \
    openssh-client \
    gpg \
    ripgrep \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI (gh)
# See https://github.com/cli/cli/blob/trunk/docs/install_linux.md#debian
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && sudo apt-get update \
    && sudo apt-get install gh \
    && sudo rm -rf /etc/apt/sources.list.d/github-cli.list

ENV PATH="/home/node/.local/bin:$PATH"

RUN mkdir -p /home/node/.pi/agent
RUN mkdir /workspace

RUN chown -R node:node /home/node/.pi
RUN chown -R node:node /workspace

USER node

RUN npm config set prefix /home/node/.local

RUN npm install -g @mariozechner/pi-coding-agent
RUN npm install -g lean-ctx-bin
RUN npm install -g @aliou/pi-guardrails
RUN npm install -g @mjakl/pi-subagent

RUN touch /home/node/.bashrc && lean-ctx setup
RUN lean-ctx init --global
RUN lean-ctx init --agent pi

WORKDIR /workspace

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Default command
CMD ["pi"]