# homefiles

Home 環境（このユーザー単位の CLI ツール・dotfiles・各種設定）を Nix で宣言的・再現可能・rollback 可能に管理するリポジトリ。

## スコープ

- **対象**: Home 環境のみ（ユーザー単位の CLI・dotfiles・設定）。プロジェクト単位の環境は対象外。

## 役割分担

| 領域 | ツール | 場所 |
| --- | --- | --- |
| CLI util / 開発 CLI（git, gnupg, gh, jq, op, starship, nkf, nmap, tree, wget, awscli ...） | **home-manager** | [`home/home.nix`](./home/home.nix) |
| shell・dotfiles（zsh, git, gpg, ghostty, zed, CLAUDE.md ...） | **home-manager**（`programs.*` / `home.file`） | [`home/`](./home/) |
| GUI アプリ（cask） | **Homebrew(cask) を nix-darwin で宣言管理** | [`darwin/configuration.nix`](./darwin/configuration.nix) |
| Homebrew 本体 | **nix-homebrew で導入・管理** | [`darwin/configuration.nix`](./darwin/configuration.nix) |
| system / nix 設定 | **nix-darwin** | [`darwin/configuration.nix`](./darwin/configuration.nix) |

- Claude Code は宣言管理外（公式インストーラ `curl -fsSL https://claude.ai/install.sh | bash` のまま）。リリースが非常に高頻度で、自己アップデートで最新を即追える利点を優先する。nixpkgs 版はバージョンが遅れ self-update も効かないため採用しない。

## 構成

```
homefiles/
├── flake.nix / flake.lock   nixpkgs-unstable + nix-darwin + home-manager（follows で統一）
├── darwin/
│   └── configuration.nix    nix-darwin: nix 設定・primaryUser・stateVersion・homebrew(cask)
├── home/
│   ├── home.nix             home-manager: home.packages・programs.*・home.file
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

前提: Nix（multi-user）が導入済み。Homebrew 本体は nix-homebrew が導入・管理する（既存環境は `autoMigrate` で引き継ぐ）。

> 注意: `homebrew.onActivation.cleanup = "uninstall"` のため、宣言（`darwin/configuration.nix` の `casks`）に無い cask・formula は switch 時に自動アンインストールされる。CLI は nix/home-manager・プロジェクトは devbox 管理なので、手動導入の brew formula は残らない。

1. このリポジトリを任意の場所に clone（例: `~/src/homefiles`）。
2. シークレット・マシン固有値の雛形 `~/.zshrc.local` を用意（下記）。clone 先の絶対パスを `HOMEFILES_FLAKE` に設定する（`drs`/`dru` がこれを参照する）。
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
   drs   # 日常の適用（= sudo darwin-rebuild switch --flake "$HOMEFILES_FLAKE#default"）
   dru   # input 更新を伴う適用（nix flake update してから switch。flake 解決時の GitHub API レート制限回避にトークンを渡す）
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
export HOMEFILES_FLAKE="$HOME/src/homefiles"
# 相対 ./bin を PATH に入れると CWD 依存で危険なので固定パスのみにする。
export PATH="$HOME/.local/bin:$PATH"
# export SOME_TOKEN=...
```

`chmod 600 ~/.zshrc.local` で自分のみ可読にする。
