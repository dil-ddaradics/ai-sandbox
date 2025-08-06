FROM alpine:latest

RUN apk add --no-cache bash curl git nodejs npm python3 py3-pip tini

RUN npm install -g @anthropic-ai/claude-code

ENV CLAUDE_CODE_USE_BEDROCK=1 \
    ANTHROPIC_MODEL=us.anthropic.claude-3-sonnet-20250219-v1:0

ENTRYPOINT ["/sbin/tini","--"]
CMD ["bash"]