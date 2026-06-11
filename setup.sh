#!/usr/bin/env bash
#
# setup.sh — Nix インストール〜初回 bootstrap を一気通貫で行う。
# 新マシン/既存マシン共通。冪等（再実行安全）。
#
#   curl -fsSL https://raw.githubusercontent.com/mackato/nix-config/main/setup.sh | bash
#
# やること:
#   1. Nix 未導入なら Determinate Systems nix-installer で導入
#   2. リポジトリを clone（既存があればそれを使う。pull はしない）
#   3. ~/.zshrc.local が無ければ minimum 雛形を作成（既存は上書きしない）
#   4. nix-darwin が衝突する /etc ファイルを初回のみ退避
#   5. 初回 darwin-rebuild switch を実行（sudo パスワードを聞かれる）
#
# 前提: Apple Silicon (aarch64-darwin)。通常ユーザーで実行する（root 不可）。
# Xcode CLT は不要（git 実体が無ければ nix の git を使う）。

set -euo pipefail

REPO_URL="https://github.com/mackato/nix-config.git"
DEFAULT_REPO="$HOME/src/nix-config"

log() { printf '\n==> %s\n' "$*"; }
die() { printf '\nError: %s\n' "$*" >&2; exit 1; }
# $1 が nix-config の checkout か（flake + darwin 設定の有無で判定）。
is_nix_config_repo() { [ -f "$1/flake.nix" ] && [ -f "$1/darwin/configuration.nix" ]; }

# --- 0. ガード -----------------------------------------------------------
[ "$(uname -s)" = "Darwin" ] || die "macOS 専用です（uname=$(uname -s)）。"
[ "$(uname -m)" = "arm64" ] || die "Apple Silicon (arm64) 専用です（uname -m=$(uname -m)）。"
[ "$(id -u)" != "0" ] || die "root では実行しないでください。通常ユーザーで実行すると必要時に sudo を求めます。"

# --- 1. Nix 導入（未導入時のみ） ----------------------------------------
# clone（手順 2）より先に Nix を入れる。git 実体が無いマシンで nix の git を使うため。
NIX_DAEMON_SH="/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
if command -v nix >/dev/null 2>&1 || [ -e "$NIX_DAEMON_SH" ]; then
  if command -v nix >/dev/null 2>&1 && [ ! -e "$NIX_DAEMON_SH" ]; then
    die "single-user の Nix と思われます。このリポジトリは multi-user Nix を前提とします（README 参照）。"
  fi
  log "Nix は既に導入済み。スキップします。"
else
  log "Nix を導入します（Determinate Systems nix-installer）。"
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
fi
# 現在シェルに nix を反映（導入直後は PATH に無い）。
if ! command -v nix >/dev/null 2>&1 && [ -e "$NIX_DAEMON_SH" ]; then
  # shellcheck disable=SC1090
  . "$NIX_DAEMON_SH"
fi
command -v nix >/dev/null 2>&1 || die "nix が見つかりません。新しいターミナルを開いて再実行してください。"
# sudo の secure_path に nix の bin が無くても動くよう絶対パスで保持する。
NIX_BIN="$(command -v nix)"

# --- 2. リポジトリ位置の決定 / clone ------------------------------------
# clone 済みローカル実行なら、このスクリプトの置かれた repo を使う。
REPO=""
SRC="${BASH_SOURCE[0]:-}"
if [ -f "$SRC" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$SRC")" && pwd)"
  if is_nix_config_repo "$SCRIPT_DIR"; then
    REPO="$SCRIPT_DIR"
    log "リポジトリ内から実行されています: $REPO"
  fi
fi

# curl パイプ実行など repo 外からの起動。
if [ -z "$REPO" ]; then
  REPO="${NIX_CONFIG_FLAKE:-$DEFAULT_REPO}"
  # flake/darwin 設定が揃うかで既存判定（worktree も tarball 展開も .git の有無に依らず拾える）。
  if is_nix_config_repo "$REPO"; then
    log "既存の clone を使用します: $REPO"
  elif [ -d "$REPO" ] && [ -n "$(ls -A "$REPO" 2>/dev/null)" ]; then
    die "$REPO は存在しますが nix-config の checkout ではありません（別リポジトリ/非空ディレクトリ）。退避するか NIX_CONFIG_FLAKE を変更してください。"
  else
    log "リポジトリを clone します: $REPO"
    if [ -x /usr/bin/git ] && xcode-select -p >/dev/null 2>&1; then
      /usr/bin/git clone "$REPO_URL" "$REPO"
    else
      # CLT 未導入で git 実体が無い → nix の git を使う（CLT の GUI プロンプト回避）。
      log "git 実体が無いため nix の git で clone します。"
      nix --extra-experimental-features 'nix-command flakes' \
        run nixpkgs#git -- clone "$REPO_URL" "$REPO"
    fi
  fi
fi

# --- 3. ~/.zshrc.local（無い場合のみ作成・上書きしない） ----------------
ZLOCAL="$HOME/.zshrc.local"
if [ -f "$ZLOCAL" ]; then
  log "$ZLOCAL は既に存在します。上書きしません。"
else
  log "$ZLOCAL を minimum 雛形で作成します。"
  cat > "$ZLOCAL" <<EOF
# Local secrets / machine-specific overrides. NOT tracked in this repo.
# 追加項目（PATH 拡張やトークン等）は README の雛形を参照。
# このリポジトリの clone 先の絶対パス（drs/dru が参照する）。
export NIX_CONFIG_FLAKE="$REPO"
export GPG_TTY="\${TTY}"
EOF
  chmod 600 "$ZLOCAL"
fi

# --- 4. /etc 衝突ファイルの退避（初回のみ・冪等） -----------------------
log "nix-darwin が衝突する /etc ファイルがあれば退避します。"
for f in bashrc zshrc zprofile zshenv; do
  if [ -e "/etc/$f" ] && [ ! -e "/etc/$f.before-nix-darwin" ]; then
    sudo mv "/etc/$f" "/etc/$f.before-nix-darwin"
  fi
done
if [ -e /etc/nix/nix.conf ] && [ ! -e /etc/nix/nix.conf.before-nix-darwin ]; then
  sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.before-nix-darwin
fi

# --- 5. 初回 switch ------------------------------------------------------
# flakes を NIX_CONFIG で明示有効化（環境側で未有効でも switch が通るように）。
# GitHub API レート制限(403)対策: GITHUB_TOKEN があれば access-tokens も渡す。
# NIX_CONFIG は環境変数として sudo に引き継ぐ（--preserve-env）。`env VAR=...` で
# argv に載せるとトークンが ps から他ユーザーに見えるため、それを避ける。
NIX_CONFIG_VAL="extra-experimental-features = nix-command flakes"
if [ -n "${GITHUB_TOKEN:-}" ]; then
  NIX_CONFIG_VAL="$NIX_CONFIG_VAL
access-tokens = github.com=$GITHUB_TOKEN"
fi
export NIX_CONFIG="$NIX_CONFIG_VAL"

DARWIN_REBUILD="/run/current-system/sw/bin/darwin-rebuild"
if [ -x "$DARWIN_REBUILD" ]; then
  log "既存 nix-darwin を switch します（sudo パスワードを求められます）。"
  sudo --preserve-env=NIX_CONFIG "$DARWIN_REBUILD" switch --flake "$REPO#default"
else
  log "初回 nix-darwin を switch します（sudo パスワードを求められます）。"
  sudo --preserve-env=NIX_CONFIG "$NIX_BIN" run nix-darwin -- switch --flake "$REPO#default"
fi

log "完了しました。新しいターミナルを開く（または exec zsh -l）と drs/dru が使えます。"
