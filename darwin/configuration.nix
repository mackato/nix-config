{ ... }:

{
  # このマシン (default / aarch64-darwin) のプラットフォーム。
  nixpkgs.hostPlatform = "aarch64-darwin";

  # op (1Password CLI) など unfree パッケージを許可する。
  nixpkgs.config.allowUnfree = true;

  # flakes を恒久的に有効化する。/etc/nix/nix.conf は nix-installer 由来で
  # nix-command のみ有効なので、ここで flakes も足して nix-darwin に管理させる。
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # 最近の nix-darwin では homebrew / ユーザー系オプションに primaryUser が必須。
  system.primaryUser = "kato";

  users.users.kato.home = "/Users/kato";

  # GUI cask は Homebrew(cask) を nix-darwin の homebrew モジュールで宣言管理する。
  # Homebrew 本体は導入済みなので nix-homebrew は使わない（このモジュールは
  # brew bundle を駆動するだけ）。
  homebrew = {
    enable = true;
    # 宣言外の cask を自動削除しない（安全側）。
    onActivation.cleanup = "none";
    caskArgs.appdir = "/Applications";
    taps = [ "manaflow-ai/cmux" ];
    casks = [
      "1password"
      "cmux"
      "emdash"
      "google-chrome"
      "google-drive"
      "google-japanese-ime"
      "iterm2"
      "raycast"
      "slack"
      "visual-studio-code"
      "zed"
    ];
    # VS Code 拡張は宣言しない（手動管理）。
  };

  # nix-darwin の state version。新規導入時の現行値。
  system.stateVersion = 6;
}
