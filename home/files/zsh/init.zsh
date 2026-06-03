# Local secrets / machine-specific overrides (リポジトリ外: ~/.zshrc.local)
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"

setopt HIST_REDUCE_BLANKS
setopt NO_NOMATCH

# On-demand completions: 補完を初回呼び出し時にだけ生成する。
on_demand_completion() {
  command -v compdef >/dev/null || return
  local cmd_name=$1
  local completion_command=$2
  local function_name="_${cmd_name}"
  local comp_cmd_name="${completion_command%% *}"

  eval "function $function_name() {
    if ! command -v \"$comp_cmd_name\" &> /dev/null; then
      return
    fi
    unfunction '$function_name'
    eval \"\$(eval $completion_command)\"
    \$_comps[$cmd_name]
  }"

  compdef $function_name $cmd_name
}

on_demand_completion 'uv' 'uv generate-shell-completion zsh'
on_demand_completion 'uvx' 'uvx generate-shell-completion zsh'
