# --- dotfiles auto-sync ---
if [[ -L "$HOME/.zshrc" ]]; then
  DOTFILES_DIR="$(dirname "$(readlink "$HOME/.zshrc")")"
else
  DOTFILES_DIR="${HOMEFILES_REPO_DIR:-$HOME/gh/mackato/homefiles}/dotfiles"
fi
__dotfiles_sync() {
  [[ -d "$DOTFILES_DIR" ]] || return 0
  local stamp="$HOME/.cache/dotfiles-sync.stamp"
  mkdir -p "$(dirname "$stamp")"
  if [[ -f "$stamp" ]] && [[ -z "$(find "$DOTFILES_DIR" -newer "$stamp" -print -quit 2>/dev/null)" ]]; then
    return 0
  fi
  "$DOTFILES_DIR/sync.sh" --quiet && touch "$stamp"
}
__dotfiles_sync
unfunction __dotfiles_sync
# --- end dotfiles auto-sync ---

[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
[ -f "$HOME/.aliases" ]    && source "$HOME/.aliases"

# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS

# Brew-managed completions / plugins
if type brew &>/dev/null; then
  BREW_PREFIX="$(brew --prefix)"
  FPATH="$BREW_PREFIX/share/zsh-completions:$FPATH"
  [ -f "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ] && source "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  autoload -Uz compinit && compinit -C
fi

# On-demand completions
on_demand_completion() {
  command -v compdef >/dev/null || return
  local cmd_name=$1
  local completion_command=$2
  local function_name="_${cmd_name}"
  local comp_cmd_name="${completion_command%% *}"

  eval "function $function_name() {
    if ! command -v "$comp_cmd_name" &> /dev/null; then
      return
    fi
    unfunction '$function_name'
    eval \"\$(eval $completion_command)\"
    \$_comps[$cmd_name]
  }"

  compdef $function_name $cmd_name
}

# mise (Ruby/Node/Python など全般のバージョン管理)
[ -x /opt/homebrew/bin/mise ] && eval "$(/opt/homebrew/bin/mise activate zsh)"

on_demand_completion 'uv' 'uv generate-shell-completion zsh'
on_demand_completion 'uvx' 'uvx generate-shell-completion zsh'

setopt NO_NOMATCH

command -v starship >/dev/null && eval "$(starship init zsh)"
