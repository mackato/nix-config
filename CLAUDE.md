# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## このリポジトリの性質

macOS（aarch64-darwin）の **home 環境を nix-darwin + home-manager で宣言管理する flake**。対象はユーザー単位の CLI・dotfiles・GUI アプリ・system/nix 設定。単一マシン構成で、`flake.nix` の `darwinConfigurations.default` がエントリ（ホスト名には依存しない）。**公開リポジトリ**であり、コミット内容・全 Git 履歴は誰でも閲覧できる前提で扱う。

## 適用・検証コマンド

- **eval/ビルド検証（sudo 不要・編集後は必ずこれで確認）**:
  ```sh
  NIX_CONFIG="access-tokens = github.com=$(gh auth token)" \
    /run/current-system/sw/bin/darwin-rebuild build --flake .#default
  ```
  生成された設定値の確認は `nix eval --raw .#darwinConfigurations.default.config.<path>` が使える。
- **lint / format（編集後・sudo 不要）**: `nix fmt`（nixfmt で整形）/ `nix flake check`（nixfmt・statix・deadnix を検証、CI と同一）/ `nix develop`（ツール入り開発シェル）。
- **適用（switch）**: alias `drs`（= darwin-rebuild switch）。**sudo パスワードが必要なので対話端末で実行**。Claude のセッションからは流せない（build までで止めてユーザーに switch を依頼する）。
- **input 更新を伴う適用**: alias `dru`（= flake update してから switch）。
- `drs`/`dru` は `~/.zshrc.local` の `HOMEFILES_FLAKE`（このリポジトリのクローン先の絶対パス）を参照する（設定手順は README）。

### 必須の落とし穴（[[homefiles-nix-ops]] と同内容）

- `sudo darwin-rebuild ...` は **command not found**（sudo の secure_path に nix が無い）。常にフルパス `/run/current-system/sw/bin/darwin-rebuild` を使う。
- flake input を再解決する操作（`nix flake update`・新規 input 追加・初回解決）は **GitHub API のレート制限(403)** を踏む。`NIX_CONFIG="access-tokens = github.com=$(gh auth token)"` を付ける。`--access-tokens` は darwin-rebuild の引数ではなく nix 側オプションなので `NIX_CONFIG` 経由で渡す。flake.lock 解決済み・ストア充填後は不要。
- `git tree is dirty` 警告は未コミット変更があると出るだけで無害（flake は git 追跡ファイルを読む）。

## 構成と責務分担

| ファイル | 役割 |
| --- | --- |
| `flake.nix` | inputs（nixpkgs-unstable / nix-darwin / home-manager / nix-homebrew、すべて nixpkgs を follows）と `darwinConfigurations.default`・`formatter`・`checks`・`devShells` |
| `.github/workflows/ci.yml` | push / PR 時に Linux で `nix flake check`（nixfmt・statix・deadnix）を実行。darwin の実ビルドは CI 対象外 |
| `statix.toml` | statix 設定。dotted notation は意図的なので `repeated_keys` を無効化 |
| `darwin/configuration.nix` | system/nix 設定・`system.primaryUser`・`nix-homebrew`（Homebrew 本体）・`homebrew.casks`（GUI アプリ） |
| `home/home.nix` | `home.packages`（CLI）・`programs.*`（git/gpg/gh/starship/zsh）・`home.file`（静的 dotfiles） |
| `home/files/` | home.nix が参照する静的ファイル。`zsh/init.zsh`→`programs.zsh.initContent`、`zsh/profile.zsh`→`profileExtra`、`ghostty/`・`zed/`・`claude/` |

**ツールをどこで管理するかの原則（重要）**:
- CLI / 開発 CLI → **home-manager**（`home.packages` か `programs.*`）。**Homebrew formula としては入れない**。
- GUI アプリ → **`homebrew.casks`**（`darwin/configuration.nix`）。
- Homebrew 本体 → **nix-homebrew**（既存環境は `autoMigrate` で引き継ぐ）。
- プロジェクト単位の環境 → **devbox**（このリポの対象外）。mise は廃止。
- Claude Code CLI → **宣言管理しない**（公式インストーラのまま。高頻度リリース＋自己アップデート優先、nixpkgs 版は遅延し self-update も効かないため）。

## 編集時の注意

- **`homebrew.onActivation.cleanup = "uninstall"`**: 宣言に無い cask/formula は switch 時に自動アンインストールされる。GUI アプリを追加・存続させたいときは必ず `casks` に足す。逆に手動 `brew install` した formula は switch で消える。
- **`home/files/claude/CLAUDE.md` はこのリポの開発ガイドではない**。ユーザーのグローバル `~/.claude/CLAUDE.md` を配布するための中身なので、リポ運用ルールと混同して編集しない。
- **git 設定は `programs.git.settings`**（新スキーマ）を使う。旧 `userName/aliases/extraConfig` は deprecation。書き出し先は XDG の `~/.config/git/config`。
- **PATH 順**: `profile.zsh` で `brew shellenv` を先に積み、`profileExtra` で nix profile を再前置するので、重複する CLI は nix 版が優先される。
- **shellAliases に実行時シェル変数を埋めるとき**: Nix のダブルクォート文字列内では `$` を `\$`、`${...}` を `\${...}` とエスケープする（home-manager がシングルクォート alias を生成し、展開は実行時に遅延される）。
- **秘匿値・マシン固有値は `~/.zshrc.local`**（リポ外・未追跡、`init.zsh` が source）。リポには絶対に入れない。
- **公開リポジトリ前提**: private リポジトリ名・issue 番号・社内固有名詞・個人情報をコミットに含めない。秘匿値・マシン固有値は前項のとおり `~/.zshrc.local`（リポ外）へ。履歴も公開されるため、混入後の除去には filter-repo 等での履歴書き換えが要る。
- `system.stateVersion`（nix-darwin）と `home.stateVersion`（home-manager）は安易に変更しない。

## Git / PR

- ユーザーのグローバルルール（`~/.claude/CLAUDE.md`）に従う: 日本語・簡潔、1 コミット 1 論理変更、PR 本文は「指示の要点／変更概要／レビューのポイント／検証方法」の 4 点。
