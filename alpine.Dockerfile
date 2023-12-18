ARG ALPINE_VERSION=3.19

ARG DOCKER_VERSION=v20.10.22
ARG COMPOSE_VERSION=v2.14.2
ARG BUILDX_VERSION=v0.9.1
ARG LOGOLS_VERSION=v1.3.7
ARG BIT_VERSION=v1.1.2
ARG GH_VERSION=v2.21.1
ARG DEVTAINR_VERSION=v0.6.0

FROM kbuley/binpot:docker-${DOCKER_VERSION} AS docker
FROM kbuley/binpot:compose-${COMPOSE_VERSION} AS compose
FROM kbuley/binpot:buildx-${BUILDX_VERSION} AS buildx
FROM kbuley/binpot:logo-ls-${LOGOLS_VERSION} AS logo-ls
FROM kbuley/binpot:bit-${BIT_VERSION} AS bit
FROM kbuley/binpot:gh-${GH_VERSION} AS gh
FROM kbuley/devtainr:${DEVTAINR_VERSION} AS devtainr

FROM alpine:${ALPINE_VERSION}
ARG GITVERSION_VERSION=5.12.0
ARG TARGETARCH
ARG CREATED
ARG COMMIT
ARG VERSION=local
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=${USER_UID}
ENV BASE_USERNAME=${USERNAME}
LABEL \
  org.opencontainers.image.authors="kevin@buley.org" \
  org.opencontainers.image.created=$CREATED \
  org.opencontainers.image.version=$VERSION \
  org.opencontainers.image.revision=$COMMIT \
  org.opencontainers.image.url="https://github.com/kbuley/basedevcontainer" \
  org.opencontainers.image.documentation="https://github.com/kbuley/basedevcontainer" \
  org.opencontainers.image.source="https://github.com/kbuley/basedevcontainer" \
  org.opencontainers.image.title="Base Dev container" \
  org.opencontainers.image.description="Base Alpine development container for Visual Studio Code Remote Containers development"
ENV BASE_VERSION="${VERSION}-${CREATED}-${COMMIT}"

RUN apk add -q --update --progress --no-cache shadow sudo icu bash tmux python3 neovim clang lazygit fzf fd \
  ca-certificates tzdata git mandoc git-doc openssh-client make ncurses zsh nano zsh-vcs less libstdc++ curl clang\
  && addgroup -g ${USER_GID} ${USERNAME} \
  && adduser -D -G ${USERNAME} -u ${USER_UID} ${USERNAME} \
  && adduser ${USERNAME} wheel \
  && sed -e 's;^# \(%wheel.*NOPASSWD.*\);\1;g' -i /etc/sudoers

ENV TZ=

COPY --chown=${USERNAME}:${USERNAME} --chmod=700 .ssh.sh /home/${USERNAME}/

RUN ln -s /home/${USERNAME}/.ssh.sh /home/${USERNAME}/.windows.sh

RUN case "${TARGETARCH}" in \
  arm64) export GVARCH='arm64' ;; \
  amd64) export GVARCH='x64' ;; \
  esac ; \
  cd /tmp ; \
  wget https://github.com/GitTools/GitVersion/releases/download/${GITVERSION_VERSION}/gitversion-linux-musl-${GVARCH}-${GITVERSION_VERSION}.tar.gz ; \
  tar zxvf gitversion-linux-musl-${GVARCH}-${GITVERSION_VERSION}.tar.gz ; \
  cp gitversion /bin ; \
  chmod +rx /bin/gitversion

RUN usermod --shell /bin/zsh ${USERNAME}

# Docker CLI
COPY --from=docker --chmod=755 /bin /usr/local/bin/docker
ENV DOCKER_BUILDKIT=1
RUN touch /var/run/docker.sock && chown ${USERNAME}:${USERNAME} /var/run/docker.sock

# Docker compose
COPY --from=compose --chmod=755 /bin /usr/libexec/docker/cli-plugins/docker-compose
ENV COMPOSE_DOCKER_CLI_BUILD=1
RUN echo "alias docker-compose='docker compose'" >> /home/${USERNAME}/.zshrc

# Buildx plugin
COPY --from=buildx --chmod=755 /bin /usr/libexec/docker/cli-plugins/docker-buildx

# Bit
COPY --from=bit --chmod=755 /bin /usr/local/bin/bit

COPY --from=gh --chmod=755 /bin /usr/local/bin/gh

COPY --from=devtainr --chmod=755 /devtainr /usr/local/bin/devtainr

WORKDIR /home/${USERNAME}

USER $USERNAME

ENV EDITOR=nvim \
  LANG=en_US.UTF-8 \
  # MacOS compatibility
  TERM=xterm

ENTRYPOINT [ "/bin/zsh" ]
