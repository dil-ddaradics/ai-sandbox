FROM alpine:latest

RUN apk add --no-cache bash curl git nodejs npm python3 py3-pip tini inotify-tools

RUN npm install -g @anthropic-ai/claude-code

ENV CLAUDE_CODE_USE_BEDROCK=1 \
    ANTHROPIC_MODEL=us.anthropic.claude-3-sonnet-20250219-v1:0

# Create AWS credential scripts
RUN mkdir -p /usr/local/bin
COPY scripts/container/aws-cred-refresh.sh /usr/local/bin/aws-cred-refresh
COPY scripts/container/aws-cred-monitor.sh /usr/local/bin/aws-cred-monitor
COPY scripts/container/aws-connectivity-check.sh /usr/local/bin/aws-connectivity-check
COPY scripts/container/entrypoint.sh /usr/local/bin/container-entrypoint
COPY scripts/container/test-cred-refresh.sh /usr/local/bin/test-cred-refresh
RUN chmod +x /usr/local/bin/aws-cred-refresh /usr/local/bin/aws-cred-monitor /usr/local/bin/aws-connectivity-check /usr/local/bin/container-entrypoint /usr/local/bin/test-cred-refresh

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/container-entrypoint"]
CMD ["bash"]