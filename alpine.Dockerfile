ARG ALPINE_VERSION=3.16

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
ARG CREATED
ARG COMMIT
ARG VERSION=local
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

# CA certificates
RUN apk add -q --update --progress --no-cache ca-certificates

# Timezone
RUN apk add -q --update --progress --no-cache tzdata
ENV TZ=

# Setup Git and SSH
RUN apk add -q --update --progress --no-cache git mandoc git-doc openssh-client
COPY .ssh.sh /root/
RUN chmod +x /root/.ssh.sh
# Retro-compatibility symlink
RUN ln -s /root/.ssh.sh /root/.windows.sh

WORKDIR /root

# Setup shell for root and ${USERNAME}
ENTRYPOINT [ "/bin/zsh" ]
RUN apk add -q --update --progress --no-cache zsh nano zsh-vcs
ENV EDITOR=nano \
    LANG=en_US.UTF-8 \
    # MacOS compatibility
    TERM=xterm
RUN apk add -q --update --progress --no-cache shadow && \
    usermod --shell /bin/zsh root && \
    apk del shadow

RUN git config --global advice.detachedHead false

COPY shell/.zshrc shell/.welcome.sh /root/
RUN git clone --single-branch --depth 1 https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh

COPY shell/.p10k.zsh /root/
RUN apk add -q --update --progress --no-cache zsh-theme-powerlevel10k gitstatus && \
    ln -s /usr/share/zsh/plugins/powerlevel10k ~/.oh-my-zsh/custom/themes/powerlevel10k

RUN git config --global advice.detachedHead true

# Docker CLI
COPY --from=docker /bin /usr/local/bin/docker
ENV DOCKER_BUILDKIT=1

# Docker compose
COPY --from=compose /bin /usr/libexec/docker/cli-plugins/docker-compose
ENV COMPOSE_DOCKER_CLI_BUILD=1
RUN echo "alias docker-compose='docker compose'" >> /root/.zshrc

# Buildx plugin
COPY --from=buildx /bin /usr/libexec/docker/cli-plugins/docker-buildx

# Logo ls
COPY --from=logo-ls /bin /usr/local/bin/logo-ls
RUN echo "alias ls='logo-ls'" >> /root/.zshrc

# Bit
COPY --from=bit /bin /usr/local/bin/bit
ARG TARGETPLATFORM
RUN if [ "${TARGETPLATFORM}" != "linux/s390x" ]; then echo "y" | bit complete; fi

COPY --from=gh /bin /usr/local/bin/gh

COPY --from=devtainr /devtainr /usr/local/bin/devtainr

# VSCode specific (speed up setup)
RUN apk add -q --update --progress --no-cache libstdc++
