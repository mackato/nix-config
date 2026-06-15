# nix-config

Home 環境（このユーザー単位の CLI ツール・dotfiles・各種設定）を Nix で宣言的・再現可能・rollback 可能に管理するリポジトリ。

## スコープ（2層構成の個人レイヤー）

- **対象**: Home 環境のみ（ユーザー単位の CLI・dotfiles・設定）。プロジェクト単位の環境は対象外。
- 会社標準（共通 GUI アプリ・共通 CLI・system/nix 設定・Homebrew 本体）は [airs/nix-config](https://github.com/airs/nix-config) が**会社標準レイヤー**として提供し、本リポジトリはそれを flake input に取って**個人レイヤー**を上乗せする。switch は本リポジトリから 1 回（2層が 1 つの構成に合成される）。

## 役割分担

| 領域 | ツール | 場所 |
| --- | --- | --- |
| 会社標準（共通 cask・共通 CLI・gh・git 中立設定・system/nix 設定・Homebrew 本体） | **airs/nix-config**（flake input） | [`flake.nix`](./flake.nix) |
| 個人の CLI util / 開発 CLI（op, awscli, nmap, uv ...） | **home-manager** | [`home/home.nix`](./home/home.nix) |
| shell・dotfiles（zsh, git identity, gpg, starship, ghostty, zed, CLAUDE.md ...） | **home-manager**（`programs.*` / `home.file`） | [`home/`](./home/) |
| 個人の GUI アプリ（cask） | **Homebrew(cask) を nix-darwin で宣言管理** | [`darwin/configuration.nix`](./darwin/configuration.nix) |

- Claude Code は宣言管理外（公式インストーラ `curl -fsSL https://claude.ai/install.sh | bash` のまま）。リリースが非常に高頻度で、自己アップデートで最新を即追える利点を優先する。nixpkgs 版はバージョンが遅れ self-update も効かないため採用しない。

## 構成

```
nix-config/
├── flake.nix / flake.lock   inputs は airs/nix-config のみ（nixpkgs 等は airs 経由で解決）。
│                            airs.lib.mkDarwinConfig に個人モジュールを渡して合成する
├── darwin/
│   └── configuration.nix    個人の GUI cask（airs 側の cask と自動連結マージ）
├── home/
│   ├── home.nix             個人の home.packages・programs.*・home.file
│   └── files/               home.file / programs.* が参照する静的ファイル（zsh, ghostty, zed, claude）
└── README.md
```

## 開発（lint / format）

`.nix` の整形・静的解析は flake の output として提供する。GitHub Actions（`.github/workflows/ci.yml`）が
push / PR 時に `nix flake check` を Linux で実行する（darwin の実ビルドは CI 対象外でローカル `drs` に委ねる）。

```sh
nix fmt            # nixfmt で整形（formatter = nixfmt-tree）
nix flake check    # nixfmt(--check) / statix / deadnix をまとめて検証（CI と同一）
nix develop        # nixfmt・statix・deadnix が入った開発シェル
```

## bootstrap（新マシン or 初回導入）

### かんたんセットアップ（推奨）

新マシン/既存マシン共通。Nix 未導入なら導入し、clone・`~/.zshrc.local` 生成・初回 switch まで一気に行う:

```sh
curl -fsSL https://raw.githubusercontent.com/mackato/nix-config/main/setup.sh | bash
```

- Apple Silicon (aarch64-darwin) 前提。通常ユーザーで実行する（途中で sudo パスワードを求められる）。Xcode CLT は不要。
- clone 先は既定で `~/gh/mackato/nix-config`（`NIX_CONFIG_FLAKE` 設定済みならそれを使う）。`home/home.nix` の `repoRoot`（CC/Codex 共有設定の symlink 先）もこのパスを指すため、別の場所に clone する場合は両方を揃える。
- `~/.zshrc.local` は無い場合のみ minimum 雛形を作成し、既存ファイルは上書きしない。
- 既存マシンでは Nix 導入をスキップし、`/etc` 退避も衝突時のみ行う。
- 処理の正本は `setup.sh`。下記の手動手順は同スクリプトが内部で行う内容の説明。

### 手動手順

前提: Nix（multi-user）が導入済み。Homebrew 本体は airs/nix-config（nix-homebrew）が導入・管理する（既存環境は `autoMigrate` で引き継ぐ）。

> 注意: `homebrew.onActivation.cleanup = "uninstall"`（airs 側で宣言）のため、宣言（airs と本リポジトリの `casks` の和集合）に無い cask・formula は switch 時に自動アンインストールされる。CLI は nix/home-manager・プロジェクトは devbox 管理なので、手動導入の brew formula は残らない。

1. このリポジトリを clone（既定 `~/gh/mackato/nix-config`。別の場所にするなら `home/home.nix` の `repoRoot` と `NIX_CONFIG_FLAKE` を揃える）。
2. シークレット・マシン固有値の雛形 `~/.zshrc.local` を用意（下記）。clone 先の絶対パスを `NIX_CONFIG_FLAKE` に設定する（`drs`/`dru` がこれを参照する）。
3. 初回のみ、nix-darwin が管理する既存 `/etc` ファイルが衝突する場合は退避:
   ```sh
   for f in bashrc zshrc zprofile zshenv; do sudo mv /etc/$f /etc/$f.before-nix-darwin 2>/dev/null; done
   sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.before-nix-darwin 2>/dev/null
   ```
4. clone 先のディレクトリで初回 switch（flakes 未有効なら明示フラグが要る）:
   ```sh
   sudo nix run --extra-experimental-features 'nix-command flakes' \
     nix-darwin -- switch --flake .#default
   ```
5. 以降の適用・更新（`drs` = darwin-rebuild switch / `dru` = darwin-rebuild update の alias を用意）:
   ```sh
   drs   # 日常の適用（= sudo darwin-rebuild switch --flake "$NIX_CONFIG_FLAKE#default"）
   dru   # input 更新を伴う適用（nix flake update してから switch。会社標準=airs の更新もこれで取り込む）
   ```
   世代一覧・rollback（`darwin-rebuild` は sudo の secure_path に無いためフルパス）:
   ```sh
   sudo /run/current-system/sw/bin/darwin-rebuild --list-generations
   sudo /run/current-system/sw/bin/darwin-rebuild --rollback
   ```

## シークレット・環境変数（`~/.zshrc.local`）

API キー・トークン・マシン固有の PATH などリポジトリに含めたくない値は `~/.zshrc.local`（リポ外）に置く。`~/.zshrc`（home-manager 管理）が起動時に source する。雛形:

```sh
# Local secrets / machine-specific overrides. NOT tracked in this repo.
export GPG_TTY="${TTY}"
# このリポジトリの clone 先の絶対パス（drs/dru が参照する）。
export NIX_CONFIG_FLAKE="$HOME/gh/mackato/nix-config"
# 適用する darwinConfigurations の属性名（未設定なら default）。
# export NIX_CONFIG_ATTR="default"
# 相対 ./bin を PATH に入れると CWD 依存で危険なので固定パスのみにする。
export PATH="$HOME/.local/bin:$PATH"
# export SOME_TOKEN=...
```

`chmod 600 ~/.zshrc.local` で自分のみ可読にする。
