FROM node:25-bookworm

# Install dependencies for terminal and clipboard support
RUN apt-get update && apt-get install -y \
    dumb-init \
    curl \
    git \
    openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Install pi globally
RUN npm install -g @mariozechner/pi-coding-agent

# Set up pi config directory structure for node user
RUN mkdir -p /home/node/.pi/agent
RUN mkdir /workspace

WORKDIR /workspace

# Use node user (UID 1000) created by base image
USER node

# Use dumb-init to handle signals properly
ENTRYPOINT ["dumb-init", "--"]

# Default command
CMD ["pi"]