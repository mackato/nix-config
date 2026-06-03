# homefiles

Home 環境（このユーザー単位の CLI ツール・dotfiles・各種設定）を宣言的に管理するための private リポジトリ。

## スコープ

- **対象**: Home 環境のみ（ユーザー単位の CLI・dotfiles・設定）。プロジェクト単位の環境は対象外。
- 新規に作成したもの（履歴は引き継いでいない）。

## 構成

| パス | 役割 |
| --- | --- |
| [`dotfiles/`](./dotfiles/) | ホーム（`~`）に symlink で展開する生 dotfiles と同期スクリプト [`sync.sh`](./dotfiles/sync.sh)。詳細は [`dotfiles/README.md`](./dotfiles/README.md) |

> Nix（home-manager / nix-darwin）による宣言的管理への移行を進行中。`flake.nix` / `home/` /
> `darwin/` をリポジトリルートに追加していく予定（`dotfiles/` の symlink 対象とは別ツリーに置き、
> `sync.sh` の管理対象と混ざらないようにする）。

## 関連

- 移行に関する一次情報は省略
