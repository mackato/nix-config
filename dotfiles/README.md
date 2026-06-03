# dotfiles

ホームディレクトリ（`~`）に置く dotfiles をリポジトリで管理するためのディレクトリ。配下のファイルはホーム側のシンボリックリンクから参照される。

## 仕組み

- このディレクトリ配下の各ファイルは、ホーム側の対応位置（同じ相対パス）に symlink として張られる。例: `dotfiles/.zshrc` → `~/.zshrc`、`dotfiles/.aliases` → `~/.aliases`、`dotfiles/.config/zed/settings.json` → `~/.config/zed/settings.json`、`dotfiles/.claude/CLAUDE.md` → `~/.claude/CLAUDE.md`。ネスト配下のファイルも同様に対象になる。
- リンクの作成・更新は [`sync.sh`](./sync.sh) が行う。冪等で、再実行しても安全。
- `.zshrc` 冒頭に **auto-sync フック**が組み込まれている。シェル起動時に `dotfiles/` 配下の更新を検知すると、自動で `sync.sh --quiet` を呼び出して symlink を最新化する。
  - 直前同期からの変更がない場合は数 ms のガード判定だけでスキップするので、シェル起動を遅くしない。
  - スタンプファイル: `~/.cache/dotfiles-sync.stamp`、過去の symlink リスト: `~/.cache/dotfiles-sync.manifest`。
  - `--quiet` 時は WARN 系のみ stderr に出る無音モード（成功時の `Linked:` / `Removed orphan:` 等は抑止）。手動実行時は通常モードで詳細表示。
- リポジトリの場所は `.zshrc` の symlink から自動的に逆引きされる（`readlink "$HOME/.zshrc"` の結果から推測）。`~/gh/mackato/homefiles` 以外に clone しても以降の起動で正しく追従する。symlink が無い状態のフォールバックは `~/gh/mackato/homefiles`、`HOMEFILES_REPO_DIR` 環境変数で上書きできる。

## ディレクトリ運用

- ファイル名・ディレクトリ名はホームでの配置に合わせる（`dotfiles/.zshrc` がそのまま `~/.zshrc` になる）。
- 新しい dotfile を管理したくなったら、ホームから `dotfiles/` 配下の対応位置に `mv` するだけでよい。次回シェル起動時に auto-sync が symlink を張る。
- 管理を止めたいときは `dotfiles/` 配下の実体を削除（または別の場所へ移動）すると、次回 sync 実行時にホーム側の対応 symlink も自動で撤去される（`~/.cache/dotfiles-sync.manifest` の差分で判定）。`$DOTFILES_DIR` を指していない symlink・実体ファイルには触らない。
- 以下のファイルは symlink 対象外（メタファイル・キャッシュ・バックアップ）:
  - `sync.sh`、`README.md`、`.DS_Store`、`.git/` 配下、`*.bak.*`

## バックアップ動作

`sync.sh` がホーム側にすでに実体ファイルや別の symlink を見つけた場合、`<元のパス>.bak.YYYYMMDDHHMMSS.<pid>` にリネームしてから新しい symlink を張る。誤って既存設定を上書きしないためのフェイルセーフ。`<pid>` 付きなのは同一秒内に別プロセスから sync.sh が走った場合の衝突回避用。

## zsh 設定の構成

`.zshrc` は薄い入口として、ホームの 2 ファイルを source する:

| ファイル | 役割 | リポジトリ管理 |
| --- | --- | --- |
| `~/.zshrc.local` | 環境変数（PATH 等）とシークレット。マシン固有の値を置く | × （ホーム実体・gitignore 不要なリポ外ファイル） |
| `~/.aliases` | エイリアス定義 | ○ （`dotfiles/.aliases` から symlink） |

source 順は `.zshrc.local` → `.aliases` → tool init（mise / starship 等）。`.zshrc.local` を先に読むので、後続の tool init が PATH 等を前提にできる。

## シークレット・環境変数の扱い（`~/.zshrc.local`）

API キーやトークン、マシン固有の PATH などリポジトリに含めたくない値は `~/.zshrc.local` に書く。新マシン bootstrap 時の雛形:

```sh
# Local secrets / machine-specific overrides.
# Sourced by ~/.zshrc. NOT tracked in the dotfiles repository.

# --- env / PATH ---
export GPG_TTY=${TTY}

export PATH="$PATH:/Users/<you>/.lmstudio/bin"
export PATH="./bin:$HOME/.local/bin:$PATH"
export PATH="/Users/<you>/.antigravity/antigravity/bin:$PATH"

# --- secrets ---
export HEROUI_PERSONAL_TOKEN=...
```

ファイルは `chmod 600 ~/.zshrc.local` で自分のみ可読にする。

## ランタイム環境の注意

- Ruby / Node / Python 等のバージョン管理は **mise** に一本化。`rbenv init` は `.zshrc` から外している（rbenv バイナリ自体は残るが、shim 経由の解決はしない）。Ruby を使う場合は `mise use -g ruby@<version>` で登録する。
- `compinit` は `-C` 付きで起動高速化。homebrew 配下の補完ファイルを信頼する前提。

## ツール導入の役割分担

- **mise**: システムワイドに使う **開発 CLI のインストールとバージョン管理**。設定は [`.config/mise/config.toml`](./.config/mise/config.toml)、lockfile は [`.config/mise/mise.lock`](./.config/mise/mise.lock)。プロジェクト固有のランタイム（プロジェクト単位の `mise.toml` 等）はこのリポジトリでは扱わない。
- **Homebrew**: mise registry 外のシステム util（`gnupg` / `nmap` / `tree` / `wget` / `nkf`）、zsh プラグイン（`zsh-autosuggestions` 等）、GUI cask アプリ。
- mise 設定の方針:
  - 各ツールは **メジャーバージョンで指定**（例: `gh = "2"`）。新マシン bootstrap で意図せず将来のメジャーが入らないようにする。
  - `[settings] lockfile = true` を有効化し、`mise.lock` を git 管理。マシン間で同一 patch バージョンに揃え、使用バージョンの履歴は git log から追える。
  - `[settings] minimum_release_age = "3d"` を設定。公開後 3 日経過していないリリースは取得しない（supply chain 攻撃対策）。
- lockfile を更新したいときは `mise lock -g`（global config 用には `-g` が必要）。新ツール追加時は `config.toml` 更新後に `mise install && mise lock -g` を流す。

## login シェルの構成

zsh / bash・sh の login 設定を DRY に保つため、共通部分を [`.profile`](./.profile) に集約している:

| ファイル | 役割 |
| --- | --- |
| `.profile` | brew shellenv、その他 PATH（lmstudio 等）。POSIX 互換構文で書く |
| `.zprofile` | zsh login shell 用。中身は `emulate sh -c '. ~/.profile'` の 1 行のみ |

zsh 専用設定（autosuggestions、starship、mise activate 等）は `.zshrc` に置く。`.zshenv` と `.bashrc` は管理対象から外している（zsh しか使わず、bash を対話的に起動する場面が無いため）。

## 新マシンへのブートストラップ

1. リポジトリを clone する（既定の置き場所は `~/gh/mackato/homefiles`、別の場所でも可）。
2. Homebrew を導入し、`.Brewfile` で必要パッケージ（`gnupg`、`mise`、`zsh-autosuggestions` 等）を入れる。

   ```sh
   brew bundle --file=<clone path>/dotfiles/.Brewfile
   ```

3. 初回だけ手動で同期スクリプトを実行する（`.zshrc` symlink がまだないので auto-sync は効かない）。

   ```sh
   bash <clone path>/dotfiles/sync.sh
   ```

   既定の置き場所なら `bash ~/gh/mackato/homefiles/dotfiles/sync.sh`。

4. 既存の `~/.zshrc` 等があれば自動で `*.bak.YYYYMMDDHHMMSS.<pid>` にバックアップされ、symlink に置き換わる。以降のシェル起動では `~/.zshrc` の symlink から実 path が逆引きされるので、clone 場所を別途指定する必要はない。
5. `~/.config/mise/config.toml` で管理しているツール（`awscli` / `gh` / `jq` / `op` / `starship` 等）を実体としてインストールする。

   ```sh
   mise install
   ```

   `mise activate` だけでは shim が PATH に並ぶのみで、実バイナリは入らないため必須。lockfile（`mise.lock`）が同梱されているので、解決される patch バージョンはマシン間で同一になる。

6. `~/.zshrc.local` を上記雛形を元に作成し、`chmod 600 ~/.zshrc.local`。
7. **GPG 署名鍵を別マシンから持ち込む**（`gpg --import private.asc` 等）。`~/.gitconfig` で `commit.gpgsign = true` と固有の `signingkey` を設定しているため、鍵が無いと `git commit` が失敗する。鍵管理の都合で署名を一時的に止めたい場合は `git -c commit.gpgsign=false commit ...` で個別に回避。
8. 新しい zsh セッションを起動して動作確認。必要なら `mise use -g ruby@<version>` 等を実行。
