FROM node:25-bookworm

# Install dependencies for terminal and clipboard support
RUN apt-get update && apt-get install -y \
    dumb-init \
    curl \
    git \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

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

WORKDIR /workspace

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Default command
CMD ["pi"]