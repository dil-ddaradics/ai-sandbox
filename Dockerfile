FROM alpine:latest

RUN apk add --no-cache bash curl git nodejs npm python3 py3-pip tini inotify-tools aws-cli socat

RUN npm install -g @anthropic-ai/claude-code

ENV CLAUDE_CODE_USE_BEDROCK=1
ENV AWS_CONTAINER_CREDENTIALS_FULL_URI=http://localhost:55491/

# Create AWS credential scripts
RUN mkdir -p /usr/local/bin
# Use simple script names without path prefixes for Docker context
COPY ./.ai/scripts/container/aws-setup.sh /usr/local/bin/aws-setup.sh
COPY ./.ai/scripts/container/aws-cred-monitor.sh /usr/local/bin/aws-cred-monitor.sh
COPY ./.ai/scripts/container/aws-connectivity-check.sh /usr/local/bin/aws-connectivity-check.sh
COPY ./.ai/scripts/container/entrypoint.sh /usr/local/bin/container-entrypoint
COPY ./.ai/scripts/container/test-cred-refresh.sh /usr/local/bin/test-cred-refresh.sh
COPY ./.ai/scripts/container/aws-cred-diagnose.sh /usr/local/bin/aws-cred-diagnose.sh
RUN chmod +x /usr/local/bin/aws-setup.sh /usr/local/bin/aws-cred-monitor.sh /usr/local/bin/aws-connectivity-check.sh /usr/local/bin/container-entrypoint /usr/local/bin/test-cred-refresh.sh /usr/local/bin/aws-cred-diagnose.sh && \
    ls -la /usr/local/bin/

ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/container-entrypoint"]