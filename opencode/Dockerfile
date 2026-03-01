FROM ghcr.io/anomalyco/opencode:latest

RUN printf '%s\n' \
  'https://dl-cdn.alpinelinux.org/alpine/v3.23/main' \
  'https://dl-cdn.alpinelinux.org/alpine/v3.23/community' \
  > /etc/apk/repositories \
  && apk update \
  && apk add --no-cache \
  git \
  nodejs \
  npm \
  openssh-client
