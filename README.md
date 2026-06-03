# homefiles

Home 環境（このユーザー単位の CLI ツール・dotfiles・各種設定）を Nix で宣言的・再現可能・rollback 可能に管理する private リポジトリ。

## スコープ

- **対象**: Home 環境のみ（ユーザー単位の CLI・dotfiles・設定）。プロジェクト単位の環境は対象外（devbox 担当）。
- 新規に作成したもの（履歴は引き継いでいない）。

## 役割分担

| 領域 | ツール | 場所 |
| --- | --- | --- |
| CLI util / 開発 CLI（git, gnupg, gh, jq, op, starship, nkf, nmap, tree, wget, awscli ...） | **home-manager** | [`home/home.nix`](./home/home.nix) |
| shell・dotfiles（zsh, git, gpg, ghostty, zed, CLAUDE.md ...） | **home-manager**（`programs.*` / `home.file`） | [`home/`](./home/) |
| GUI アプリ（cask） | **Homebrew(cask) を nix-darwin で宣言管理** | [`darwin/configuration.nix`](./darwin/configuration.nix) |
| system / nix 設定 | **nix-darwin** | [`darwin/configuration.nix`](./darwin/configuration.nix) |

- VS Code 拡張は宣言管理外（手動）。
- プロジェクト環境は devbox 継続。mise は廃止。

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

## bootstrap（新マシン or 初回導入）

前提: Nix（multi-user）と Homebrew 本体が導入済み。hostname は `default`（別マシンでは `darwin/`・`flake.nix` の構成名を合わせる）。

1. このリポジトリを `~/gh/mackato/homefiles` に clone。
2. シークレット・マシン固有値の雛形 `~/.zshrc.local` を用意（下記）。
3. 初回のみ、nix-darwin が管理する既存 `/etc` ファイルが衝突する場合は退避:
   ```sh
   for f in bashrc zshrc zprofile zshenv; do sudo mv /etc/$f /etc/$f.before-nix-darwin 2>/dev/null; done
   sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.before-nix-darwin 2>/dev/null
   ```
4. 初回 switch（flakes 未有効なら明示フラグが要る）:
   ```sh
   sudo nix run --extra-experimental-features 'nix-command flakes' \
     nix-darwin -- switch --flake ~/gh/mackato/homefiles#default
   ```
5. 以降の適用・更新:
   ```sh
   sudo darwin-rebuild switch --flake ~/gh/mackato/homefiles#default
   ```
   世代一覧・rollback:
   ```sh
   sudo darwin-rebuild --list-generations
   sudo darwin-rebuild --rollback
   ```

## シークレット・環境変数（`~/.zshrc.local`）

API キー・トークン・マシン固有の PATH などリポジトリに含めたくない値は `~/.zshrc.local`（リポ外）に置く。`~/.zshrc`（home-manager 管理）が起動時に source する。雛形:

```sh
# Local secrets / machine-specific overrides. NOT tracked in this repo.
export GPG_TTY="${TTY}"
# 相対 ./bin を PATH に入れると CWD 依存で危険なので固定パスのみにする。
export PATH="$HOME/.local/bin:$PATH"
# export SOME_TOKEN=...
```

`chmod 600 ~/.zshrc.local` で自分のみ可読にする。

## 関連

- 一次情報は省略
