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
ARG GITVERSION_VERSION=5.12.0
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

RUN apk add -q --update --progress --no-cache shadow sudo icu \
    && addgroup -g ${USER_GID} ${USERNAME} \
    && adduser -D -G ${USERNAME} -u ${USER_UID} ${USERNAME} \
    && adduser ${USERNAME} wheel \
    && sed -e 's;^# \(%wheel.*NOPASSWD.*\);\1;g' -i /etc/sudoers \
    && mkdir /go \
    && chown -R vscode /go
USER $USERNAME

# CA certificates
RUN sudo apk add -q --update --progress --no-cache ca-certificates

# Timezone
RUN sudo apk add -q --update --progress --no-cache tzdata
ENV TZ=

# Setup Git and SSH
RUN sudo apk add -q --update --progress --no-cache git mandoc git-doc openssh-client
COPY --chown=${USERNAME}:${USERNAME} --chmod=700 .ssh.sh /home/${USERNAME}/
# Retro-compatibility symlink
RUN ln -s /home/${USERNAME}/.ssh.sh /home/${USERNAME}/.windows.sh

RUN apkArch="$(apk --print-arch)"; \
    case "$apkArch" in \
    aarch64) export GVARCH='arm64' ;; \
    arm64) export GVARCH='arm64' ;; \
    amd64) export GVARCH='x64' ;; \
    esac; \
    cd /tmp ; \
    wget https://github.com/GitTools/GitVersion/releases/download/${GITVERSION_VERSION}/gitversion-linux-musl-${GVARCH}-${GITVERSION_VERSION}.tar.gz ; \
    tar zxvf gitversion-linux-musl-${GVARCH}-${GITVERSION_VERSION}.tar.gz ; \
    sudo cp gitversion /bin ; \
    sudo chmod +rx /bin/gitversion

WORKDIR /home/${USERNAME}

# Make
RUN sudo apk add -q --update --progress --no-cache make ncurses

# Setup shell for ${USERNAME}
ENTRYPOINT [ "/bin/zsh" ]
RUN sudo apk add -q --update --progress --no-cache zsh nano zsh-vcs less
ENV EDITOR=nano \
    LANG=en_US.UTF-8 \
    # MacOS compatibility
    TERM=xterm
RUN sudo usermod --shell /bin/zsh ${USERNAME}

RUN git config --global advice.detachedHead false

COPY --chown=${USERNAME}:${USERNAME} shell/.zshrc shell/.welcome.sh /home/${USERNAME}/
RUN git clone --single-branch --depth 1 https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh

COPY --chown=${USERNAME}:${USERNAME} shell/.p10k.zsh /home/${USERNAME}/
RUN sudo apk add -q --update --progress --no-cache zsh-theme-powerlevel10k gitstatus && \
    ln -s /usr/share/zsh/plugins/powerlevel10k ~/.oh-my-zsh/custom/themes/powerlevel10k

RUN git config --global advice.detachedHead true

# Docker CLI
COPY --from=docker --chmod=755 /bin /usr/local/bin/docker
ENV DOCKER_BUILDKIT=1
RUN sudo touch /var/run/docker.sock && sudo chown ${USERNAME}:${USERNAME} /var/run/docker.sock

# Docker compose
COPY --from=compose --chmod=755 /bin /usr/libexec/docker/cli-plugins/docker-compose
ENV COMPOSE_DOCKER_CLI_BUILD=1
RUN echo "alias docker-compose='docker compose'" >> /home/${USERNAME}/.zshrc

# Buildx plugin
COPY --from=buildx --chmod=755 /bin /usr/libexec/docker/cli-plugins/docker-buildx

# Logo ls
COPY --from=logo-ls --chmod=755 /bin /usr/local/bin/logo-ls
RUN echo "alias ls='logo-ls'" >> /home/${USERNAME}/.zshrc

# Bit
COPY --from=bit --chmod=755 /bin /usr/local/bin/bit
ARG TARGETPLATFORM
RUN if [ "${TARGETPLATFORM}" != "linux/s390x" ]; then echo "y" | bit complete; fi

COPY --from=gh --chmod=755 /bin /usr/local/bin/gh

COPY --from=devtainr --chmod=755 /devtainr /usr/local/bin/devtainr

# VSCode specific (speed up setup)
RUN sudo apk add -q --update --progress --no-cache libstdc++
