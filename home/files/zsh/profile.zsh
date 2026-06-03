# Homebrew (GUI cask の PATH/補完用)。CLI は nix profile が優先される（下で再前置）。
[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"

[ -d "$HOME/.lmstudio/bin" ] && export PATH="$PATH:$HOME/.lmstudio/bin"
[ -d "/Applications/Obsidian.app/Contents/MacOS" ] && export PATH="$PATH:/Applications/Obsidian.app/Contents/MacOS"
