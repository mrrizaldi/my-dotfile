# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
*i*) ;;
*) return ;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
#[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
  debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
xterm-color | *-256color) color_prompt=yes ;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
  if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
    # We have color support; assume it's compliant with Ecma-48
    # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
    # a case would tend to support setf rather than setaf.)
    color_prompt=yes
  else
    color_prompt=
  fi
fi

if [ "$color_prompt" = yes ]; then
  PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
  PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm* | rxvt*)
  PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
  ;;
*) ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
  test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
  alias ls='ls --color=auto'
  #alias dir='dir --color=auto'
  #alias vdir='vdir --color=auto'

  #alias grep='grep --color=auto'
  #alias fgrep='fgrep --color=auto'
  #alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
#alias ll='ls -l'
#alias la='ls -A'
#alias l='ls -CF'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
  . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
export MOBILE_DEV_ENV="$HOME/dev/mobile"
export FLUTTER_HOME="$MOBILE_DEV_ENV/flutter"
export ANDROID_SDK_ROOT="$MOBILE_DEV_ENV/Android/Sdk"

export PATH="$PATH:$FLUTTER_HOME/bin"
export PATH="$PATH:$ANDROID_SDK_ROOT/emulator"
export PATH="$PATH:$ANDROID_SDK_ROOT/tools"
export PATH="$PATH:$ANDROID_SDK_ROOT/tools/bin"
export PATH="$PATH:$ANDROID_SDK_ROOT/platform-tools"

[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
export PATH="$JAVA_HOME/bin:$PATH"
# ==== generic PATH ====
export PATH="$HOME/.local/bin:$PATH"

# ==== NVM (Node + npm) ====
export NVM_DIR="$HOME/.nvm"
# Pastikan nvm terpasang di $NVM_DIR
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"                   # load nvm (bash)
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion" # optional

# Optional: aktifkan corepack supaya pnpm/yarn dikelola versi-nya
# corepack enable  # jalankan sekali di shell, tidak perlu di bashrc

# ==== PNPM ====
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
*":$PNPM_HOME:"*) ;;
*) export PATH="$PNPM_HOME:$PATH" ;;
esac
# Optional bash completion pnpm:
# command -v pnpm >/dev/null 2>&1 && source <(pnpm completion bash)

# ==== Python (pyenv) ====
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
command -v pyenv >/dev/null 2>&1 && eval "$(pyenv init -)"
command -v pyenv >/dev/null 2>&1 && eval "$(pyenv virtualenv-init -)"

# ==== Rust (cargo) ====
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# ==== Android/Java (kalau kamu pakai) ====
export MOBILE_DEV_ENV="$HOME/dev/mobile"
export FLUTTER_HOME="$MOBILE_DEV_ENV/flutter"
export ANDROID_SDK_ROOT="$MOBILE_DEV_ENV/Android/Sdk"
export PATH="$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"

# Deteksi JAVA_HOME dari javac jika ada
if command -v javac >/dev/null 2>&1; then
  export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

# ==== Aliases opsional ====
alias nvim="$HOME/Downloads/nvim-linux-x86_64.appimage"
alias fd=fdfind

# ==== Adrkt completion (jika tool ini mendukung bash) ====
# Cek dulu perintahnya. Banyak CLI punya subcommand 'completion bash'.
# Contoh umum:
# command -v adrkt >/dev/null 2>&1 && source <(adrkt completion bash)
# 
# # Set AgentRouter's API base URL
# export ANTHROPIC_BASE_URL=https://agentrouter.org/

# Set your AgentRouter API key, available at https://agentrouter.org/console/token


# Added by Antigravity CLI installer
export PATH="/home/mrrizaldi/.local/bin:$PATH"

[ -f ~/.config/shell/secrets.sh ] && . ~/.config/shell/secrets.sh
