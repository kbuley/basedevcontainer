ARG DEBIAN_VERSION=bullseye-slim

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

FROM debian:${DEBIAN_VERSION}
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
    org.opencontainers.image.title="Base Dev container Debian" \
    org.opencontainers.image.description="Base Debian development container for Visual Studio Code Remote Containers development"
ENV BASE_VERSION="${VERSION}-${CREATED}-${COMMIT}"

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends adduser sudo \
    && addgroup --gid ${USER_GID} ${USERNAME} \
    && adduser --disabled-password --home /home/${USERNAME} --gid ${USER_GID} --uid ${USER_UID} ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && mkdir /go \
    && chown -R vscode /go
USER $USERNAME

# CA certificates
RUN sudo apt-get update -y && \
    sudo apt-get install -y --no-install-recommends ca-certificates && \
    sudo rm -r /var/cache/* /var/lib/apt/lists/*

# Timezone
RUN sudo apt-get update -y && \
    sudo apt-get install -y --no-install-recommends tzdata && \
    sudo rm -r /var/cache/* /var/lib/apt/lists/*
ENV TZ=

# Setup Git and SSH
# Workaround for older Debian in order to be able to sign commits
RUN echo "deb https://deb.debian.org/debian bookworm main" | sudo tee -a /etc/apt/sources.list && \
    sudo apt-get update && \
    sudo apt-get install -y --no-install-recommends -t bookworm git git-man && \
    sudo rm -r /var/cache/* /var/lib/apt/lists/*
RUN sudo apt-get update -y && \
    sudo apt-get install -y --no-install-recommends man openssh-client less && \
    sudo rm -r /var/cache/* /var/lib/apt/lists/*
COPY --chown=${USERNAME}:${USERNAME} --chmod=700 .ssh.sh /home/${USERNAME}/
# Retro-compatibility symlink
RUN  ln -s /home/${USERNAME}/.ssh.sh /home/${USERNAME}/.windows.sh

# Make
RUN sudo apt-get update && sudo apt-get install -y --no-install-recommends make ncurses-bin && sudo rm -r /var/cache/* /var/lib/apt/lists/*

# Setup shell
ENTRYPOINT [ "/bin/zsh" ]
RUN sudo apt-get update -y && \
    sudo apt-get install -y --no-install-recommends zsh nano locales wget && \
    sudo apt-get autoremove -y && \
    sudo apt-get clean -y && \
    sudo rm -r /var/cache/* /var/lib/apt/lists/*
ENV EDITOR=nano \
    LANG=en_US.UTF-8 \
    # MacOS compatibility
    TERM=xterm
RUN echo "LC_ALL=en_US.UTF-8" | sudo tee -a /etc/environment && \
    echo "en_US.UTF-8 UTF-8" | sudo tee -a /etc/locale.gen && \
    echo "LANG=en_US.UTF-8" | sudo tee /etc/locale.conf && \
    sudo locale-gen en_US.UTF-8
RUN sudo usermod --shell /bin/zsh ${USERNAME}

RUN git config --global advice.detachedHead false

COPY --chown=${USERNAME}:${USERNAME} shell/.zshrc shell/.welcome.sh /home/${USERNAME}/
RUN git clone --single-branch --depth 1 https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh

ARG POWERLEVEL10K_VERSION=v1.16.1
COPY --chown=${USERNAME}:${USERNAME} shell/.p10k.zsh /home/${USERNAME}/
RUN git clone --branch ${POWERLEVEL10K_VERSION} --single-branch --depth 1 https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k && \
    sudo rm -rf ~/.oh-my-zsh/custom/themes/powerlevel10k/.git

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
