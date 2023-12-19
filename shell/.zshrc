ZSH=~/.oh-my-zsh
ZSH_CUSTOM=$ZSH/custom
POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
ZSH_THEME="powerlevel10k/powerlevel10k"
ENABLE_CORRECTION="false"
COMPLETION_WAITING_DOTS="true"
plugins=(vscode git colorize)

# TODO Ascii art

[ -f ~/.ssh.sh ] && source ~/.ssh.sh

# SSH directory check
[ -d ~/.ssh ] ||  >&2 echo "[WARNING] No SSH directory found, SSH functionalities might not work"

# Timezone check
[ -z $TZ ] && >&2 echo "[WARNING] TZ environment variable not set, time might be wrong!"

echo
echo "Base version: $BASE_VERSION"
where code &> /dev/null && echo "VS code server `code -v | head -n 1`"
echo

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

source $ZSH/oh-my-zsh.sh
source ~/.p10k.zsh

[ -f ~/.zshrc-specific.sh ] && source ~/.zshrc-specific
