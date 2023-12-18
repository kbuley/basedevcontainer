ARG ALPINE_VERSION=3.19

ARG LOGOLS_VERSION=v1.3.7
ARG BIT_VERSION=v1.1.2
ARG GH_VERSION=v2.40.1

FROM kbuley/binpot:logo-ls-${LOGOLS_VERSION} AS logo-ls
FROM kbuley/binpot:bit-${BIT_VERSION} AS bit
FROM kbuley/binpot:gh-${GH_VERSION} AS gh

FROM alpine:${ALPINE_VERSION} as neovim
ARG NEOVIM_VERSION=v0.9.4
WORKDIR /builder

#hadolint ignore=DL3018
RUN apk add -q --update --progress --no-cache build-base cmake coreutils curl wget unzip gettext-tiny-dev git \
  && git clone --depth 1 --branch "${NEOVIM_VERSION}" https://github.com/neovim/neovim 
WORKDIR /builder/neovim
RUN make CMAKE_BUILD_TYPE=Release
WORKDIR /builder/neovim/build
RUN cpack -G STGZ && mkdir /package && cp nvim-linux64.sh /package

FROM alpine:${ALPINE_VERSION}
ARG TIMEZONE=EST5EDT
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

COPY --from=neovim /package/nvim-linux64.sh /tmp

#hadolint ignore=DL3018
RUN apk add -q --update --progress --no-cache shadow sudo icu bash tmux python3 neovim clang lazygit fzf fd \
  ca-certificates tzdata git mandoc git-doc openssh-client make ncurses zsh nano zsh-vcs less libstdc++ curl wget clang zsh-theme-powerlevel10k gitstatus\
  && addgroup -g ${USER_GID} ${USERNAME} \
  && adduser -D -G ${USERNAME} -u ${USER_UID} ${USERNAME} \
  && adduser ${USERNAME} wheel \
  && sed -e 's;^# \(%wheel.*NOPASSWD.*\);\1;g' -i /etc/sudoers \
  && /tmp/nvim-linux64.sh --skip-license \
  && rm /tmp/nvim-linux64.sh


WORKDIR /tmp

RUN case "${TARGETARCH}" in \
  arm64) export GVARCH='arm64' ;; \
  amd64) export GVARCH='x64' ;; \
  esac  \
  && wget --progress=dot:giga "https://github.com/GitTools/GitVersion/releases/download/${GITVERSION_VERSION}/gitversion-linux-musl-${GVARCH}-${GITVERSION_VERSION}.tar.gz" \
  && tar zxvf "gitversion-linux-musl-${GVARCH}-${GITVERSION_VERSION}.tar.gz" \
  && cp gitversion /bin \
  && chmod +rx /bin/gitversion \
  && usermod --shell /bin/zsh ${USERNAME}

# Bit
COPY --from=bit --chmod=755 /bin /usr/local/bin/bit
COPY --from=logo-ls --chmod=755 /bin /usr/local/bin/logo-ls
COPY --from=gh --chmod=755 /bin /usr/local/bin/gh

USER ${USERNAME}

WORKDIR /home/${USERNAME}

ENV TZ=${TIMEZONE}
ENV EDITOR=nano
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV LANGUAGE=en_US
ENV TERM=xterm-256color

COPY --chown=${USERNAME}:${USERNAME} shell/.p10k.zsh /home/${USERNAME}/
COPY --chown=${USERNAME}:${USERNAME} shell/.zshrc /home/${USERNAME}/

RUN git clone --single-branch --depth 1 https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh \
  && ln -s /usr/share/zsh/plugins/powerlevel10k ~/.oh-my-zsh/custom/themes/powerlevel10k \
  && echo "alias ls='logo-ls'" >> .zshrc

ENTRYPOINT [ "/bin/zsh" ]
