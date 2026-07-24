# Managed from ~/.dev_environment/home/.config/zsh/.zshrc

# Home Manager session variables are generated without taking ownership of the
# system zsh binary.
[[ -r "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]] && \
  source "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"

# Nested shells can inherit Home Manager's "already sourced" guard from an
# older parent shell. Set the activation contract in the managed Zsh file too,
# so every new interactive Zsh can prove which workstation environment it read.
export DEV_ENVIRONMENT_ACTIVE=1
export DEV_ENVIRONMENT_ROOT="$HOME/.dev_environment"

export ZSH="$HOME/.local/share/oh-my-zsh"
export ZSH_CUSTOM="$HOME/.local/share/oh-my-zsh-custom"
export VISUAL=nvim
export EDITOR=nvim
export PAGER=cat
export GOBIN="$HOME/go/bin"
export BUN_INSTALL="$HOME/.bun"
export NVM_DIR="$HOME/.nvm"

# Build a complete PATH first. The final normalization below makes Brewfile-owned
# workstation tools win over old apt and user-local installer copies.
typeset -U path PATH
path=(
  "$HOME/.nix-profile/bin"
  "$HOME/bin"
  "$HOME/go/bin"
  "$BUN_INSTALL/bin"
  "$HOME/.local/bin"
  $path
)

if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi
[[ -d /home/linuxbrew/.linuxbrew/opt/libpq/bin ]] && \
  path=(/home/linuxbrew/.linuxbrew/opt/libpq/bin $path)

ZSH_THEME=""
plugins=(git gh golang tmux ubuntu docker zsh-syntax-highlighting)
source "$ZSH/oh-my-zsh.sh"

# Familiar prompt: [HH:MM:SS] hostname ~/dir/path (branch*) »
ZSH_THEME_GIT_PROMPT_PREFIX=" %F{magenta}("
ZSH_THEME_GIT_PROMPT_SUFFIX=")%f"
ZSH_THEME_GIT_PROMPT_DIRTY="%F{red}*%F{magenta}"
ZSH_THEME_GIT_PROMPT_CLEAN=""
PROMPT='%F{8}[%*]%f %F{cyan}%m%f %F{green}%3~%f$(git_prompt_info) %B%(?.%F{blue}.%F{red})»%f%b '

# General
alias zshreload='source ~/.zshrc'
alias ll='ls -lhrt'
alias lll='ls -lahrt'
alias ccat='bat'
alias duh='du -h --max-depth=2 | sort -rh | head -10'

dev-env-status() {
  emulate -L zsh

  local configured_root=${DEV_ENVIRONMENT_ROOT:-$HOME/.dev_environment}
  local resolved_root=${configured_root:A}
  local active_zshrc=$HOME/.zshrc
  local expected_zshrc=$resolved_root/home/.config/zsh/.zshrc

  if [[ ${DEV_ENVIRONMENT_ACTIVE:-0} == 1 && \
    ${active_zshrc:A} == ${expected_zshrc:A} ]]; then
    print -r -- 'dev_environment: active'
    print -r -- "repository: $resolved_root"
    print -r -- "zsh config: ${active_zshrc:A}"
    if [[ -n ${IN_NIX_SHELL:-} ]]; then
      print -r -- "nix dev shell: $IN_NIX_SHELL"
    else
      print -r -- 'nix dev shell: not entered (not required for the workstation environment)'
    fi
    return 0
  fi

  print -ru2 -- 'dev_environment: inactive or not applied'
  print -ru2 -- 'run ~/.dev_environment/rebuild.sh, then start a new zsh'
  return 1
}

# Config shortcuts
alias vimrc='nvim ~/.config/nvim/init.lua'
alias zshrc='nvim ~/.zshrc'
alias tmuxconf='nvim ~/.tmux.conf'
alias herdrconf='nvim ~/.config/herdr/config.toml'
alias oc_json='nvim ~/.config/opencode/opencode.json'

# Vim-to-Neovim transition
alias vi='nvim'
alias vim='nvim'
alias oldvim='/usr/bin/vim'

# tmux sessions
alias ipad='tmux attach -t ipad'
alias mac='tmux attach -t mac'
alias strada='tmux attach -t strada'
alias ubu='tmux attach -t ubu'

# Git
alias lg='lazygit'
alias gl='git log --oneline -n5'
alias gll="git log --pretty='%h|%ad|%al|%s' --date=relative -n 5 | column -t -s'|'"
alias gr='git remote'
alias gs='git status'
alias gd='git diff'
alias grv='git remote -v'

gitclean() {
  local branches
  branches=$(git for-each-ref --format '%(refname:short)' refs/heads \
    | grep -vE '^(master|main|dev|sandbox|stage)$')
  if [[ -z $branches ]]; then
    echo 'No local branches to delete.'
    return 0
  fi
  echo "$branches"
  echo "Delete these local branches? Type 'yes' to continue:"
  local confirm_delete
  read -r confirm_delete
  [[ $confirm_delete == yes ]] && echo "$branches" | xargs git branch -D
}

# Docker
alias dpj='docker ps --format "{{json .}}" | jq "{Name: .Names, Ports: .Ports, Uptime: .RunningFor, Image: .Image}"'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'

# AI tools
alias o='opencode'

# Preserve existing runtimes during the first migration phase. NVM is removed
# only after Brew Node is verified against active projects.
[[ -s "$BUN_INSTALL/_bun" ]] && source "$BUN_INSTALL/_bun"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
[[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
[[ -f "$HOME/.openclaw/completions/openclaw.zsh" ]] && \
  source "$HOME/.openclaw/completions/openclaw.zsh"

command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"

# Never place secret values in Home Manager/Nix. Prefer the new mode-0600 file,
# with the legacy file retained only during migration.
if [[ -r "$HOME/.config/dev_environment/secrets.env" ]]; then
  source "$HOME/.config/dev_environment/secrets.env"
elif [[ -r "$HOME/.envStuff" ]]; then
  source "$HOME/.envStuff"
fi

# brew/Brewfile is authoritative for workstation-level tools. Keep other
# installers available as fallbacks without allowing them to shadow Brew.
if [[ -n ${HOMEBREW_PREFIX:-} ]]; then
  path=("$HOMEBREW_PREFIX/bin" "$HOMEBREW_PREFIX/sbin" $path)
fi
