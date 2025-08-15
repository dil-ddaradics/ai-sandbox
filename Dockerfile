FROM alpine:latest

RUN apk add --no-cache bash curl git nodejs npm python3 py3-pip tini inotify-tools aws-cli socat gosu

RUN npm install -g @anthropic-ai/claude-code

ENV CLAUDE_CODE_USE_BEDROCK=1
ENV AWS_CONTAINER_CREDENTIALS_FULL_URI=http://localhost:55491/

# Create claude-user with wide permissions
RUN addgroup -S claude && \
    adduser -S -G claude -s /bin/bash claude-user && \
    mkdir -p /home/claude-user && \
    chown -R claude-user:claude /home/claude-user

# Give claude-user access to key directories
RUN mkdir -p /workspace && \
    chown claude-user:claude /workspace && \
    chmod 755 /workspace

# Configure claude-user's .bashrc to automatically source AWS credentials
RUN echo 'source /etc/profile.d/aws-credentials.sh' >> /home/claude-user/.bashrc && \
    chown claude-user:claude /home/claude-user/.bashrc

# Copy Claude configuration template
COPY ./.ai/templates/claude.json.template /tmp/claude.json.template

# Configure claude-user with preset claude.json configuration
RUN cp /tmp/claude.json.template /home/claude-user/.claude.json && \
    chown claude-user:claude /home/claude-user/.claude.json

# Create AWS credential scripts
RUN mkdir -p /usr/local/bin
# Use simple script names without path prefixes for Docker context
COPY ./.ai/scripts/container/aws-setup.sh /usr/local/bin/aws-setup.sh
COPY ./.ai/scripts/container/aws-cred-monitor.sh /usr/local/bin/aws-cred-monitor.sh
COPY ./.ai/scripts/container/aws-connectivity-check.sh /usr/local/bin/aws-connectivity-check.sh
COPY ./.ai/scripts/container/entrypoint.sh /usr/local/bin/container-entrypoint
COPY ./.ai/scripts/container/test-cred-refresh.sh /usr/local/bin/test-cred-refresh.sh
COPY ./.ai/scripts/container/aws-cred-diagnose.sh /usr/local/bin/aws-cred-diagnose.sh
COPY ./.ai/scripts/container/claudy /usr/local/bin/claudy
COPY ./.ai/scripts/container/test-aws-env.sh /usr/local/bin/test-aws-env.sh
RUN chmod +x /usr/local/bin/aws-setup.sh /usr/local/bin/aws-cred-monitor.sh /usr/local/bin/aws-connectivity-check.sh /usr/local/bin/container-entrypoint /usr/local/bin/test-cred-refresh.sh /usr/local/bin/aws-cred-diagnose.sh /usr/local/bin/claudy /usr/local/bin/test-aws-env.sh && \
    ls -la /usr/local/bin/

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/container-entrypoint"]