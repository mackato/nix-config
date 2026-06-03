{ pkgs, ... }:

{
  home.username = "kato";
  home.homeDirectory = "/Users/kato";

  # home-manager の state version (現行 home-manager リリース)。
  home.stateVersion = "26.05";

  # PR1 は検証用の最小構成。既存環境 (brew / mise / sync.sh / ~/.zshrc) と
  # 衝突しない、nix profile から引けることを確認するためだけのパッケージ。
  home.packages = [
    pkgs.tree
    pkgs.wget
  ];
}
