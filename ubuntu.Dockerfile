ARG UBUNTU_VERSION=latest

ARG LOGOLS_VERSION=v1.3.7
ARG BIT_VERSION=v1.1.2
ARG GH_VERSION=v2.40.1
ARG LAZYGIT_VERSION=v0.40.2

FROM kbuley/binpot:logo-ls-${LOGOLS_VERSION} AS logo-ls
FROM kbuley/binpot:bit-${BIT_VERSION} AS bit
FROM kbuley/binpot:gh-${GH_VERSION} AS gh
FROM kbuley/binpot:lazygit-${LAZYGIT_VERSION} as lazygit

FROM ubuntu:${UBUNTU_VERSION} as neovim
ARG NEOVIM_VERSION=v0.9.4
WORKDIR /builder
# hadolint ignore=DL3008
RUN apt-get update -y && apt-get install -y --no-install-recommends \
  build-essential file make git ninja-build gettext cmake unzip curl ca-certificates \
  && git clone --depth 1 --branch "${NEOVIM_VERSION}" https://github.com/neovim/neovim
WORKDIR /builder/neovim
RUN make CMAKE_BUILD_TYPE=Release
WORKDIR /builder/neovim/build
RUN cpack -G DEB && mkdir /package && cp nvim-linux64.deb /package

FROM ubuntu:${UBUNTU_VERSION}
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
  org.opencontainers.image.title="Base Dev container Ubuntu" \
  org.opencontainers.image.description="Base Ubuntu development container for remote containers development"
ENV BASE_VERSION="${VERSION}-${CREATED}-${COMMIT}"

ENV TZ=${TIMEZONE}
ENV EDITOR=nano
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV LANGUAGE=en_US
ENV TERM=xterm-256color

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

WORKDIR /tmp

COPY --from=neovim /package/*.deb /tmp

# hadolint ignore=DL3008, SC2016
RUN ln -fs "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime \ 
  && apt-get update -y \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends adduser sudo wget icu-devtools \
  tzdata ca-certificates apt-utils man openssh-client less make ncurses-bin \ 
  zsh nano locales wget git tmux python3 make fzf \
  && dpkg -i -- *.deb \
  && rm -f -- *.deb \
  && addgroup --gid ${USER_GID} ${USERNAME} \
  && adduser --disabled-password --home /home/${USERNAME} --gid ${USER_GID} --uid ${USER_UID} ${USERNAME} \
  && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
  && echo "LC_ALL=en_US.UTF-8" | tee -a /etc/environment \
  && echo "en_US.UTF-8 UTF-8" | tee -a /etc/locale.gen \
  && echo "LANG=en_US.UTF-8" | tee /etc/locale.conf \
  && locale-gen en_US.UTF-8 \
  && dpkg-reconfigure --frontend noninteractive tzdata \
  && echo export XDG_CONFIG_HOME='"$HOME/.config"' >> /etc/zsh/zshenv \
  && echo export XDG_DATA_HOME='"$HOME/.local/share"'  >> /etc/zsh/zshenv \
  && echo export XDG_CACHE_HOME='"$HOME/.cache"'  >> /etc/zsh/zshenv \
  && case "${TARGETARCH}" in \
  arm64) export GVARCH='arm64' ;; \
  amd64) export GVARCH='x64' ;; \
  esac \
  && wget --progress=dot:giga "https://github.com/GitTools/GitVersion/releases/download/${GITVERSION_VERSION}/gitversion-linux-${GVARCH}-${GITVERSION_VERSION}.tar.gz" \
  && tar zxvf "gitversion-linux-${GVARCH}-${GITVERSION_VERSION}.tar.gz" \
  && cp gitversion /bin  \
  && chmod +rx /bin/gitversion \
  && usermod --shell /bin/zsh ${USERNAME} \
  && apt-get autoremove \
  && apt-get clean -y \
  && rm -r /var/cache/* /var/lib/apt/lists/* 

COPY --chown=${USERNAME}:${USERNAME} shell/.p10k.zsh /home/${USERNAME}/
COPY --chown=${USERNAME}:${USERNAME} shell/.zshrc /home/${USERNAME}/

# Logo ls
COPY --from=logo-ls --chmod=755 /bin /usr/local/bin/logo-ls
COPY --from=lazygit --chmod=755 /bin /usr/local/bin/lazygit

# Bit
COPY --from=bit --chmod=755 /bin /usr/local/bin/bit
ARG TARGETPLATFORM
RUN if [ "${TARGETPLATFORM}" != "linux/s390x" ]; then echo "y" | bit complete; fi

COPY --from=gh --chmod=755 /bin /usr/local/bin/gh

USER $USERNAME

WORKDIR /home/${USERNAME}

ARG POWERLEVEL10K_VERSION=v1.16.1
RUN git clone --single-branch --depth 1 https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh \
  && git clone --branch ${POWERLEVEL10K_VERSION} --single-branch --depth 1 https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k \
  && rm -rf ~/.oh-my-zsh/custom/themes/powerlevel10k/.git && echo "alias ls='logo-ls'" >> /home/${USERNAME}/.zshrc
ENTRYPOINT [ "/bin/zsh" ]
