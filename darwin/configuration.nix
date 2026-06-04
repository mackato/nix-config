_:

{
  # このマシン (aarch64-darwin) のプラットフォーム。
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

  # Homebrew 本体を nix-homebrew で導入・管理する（bootstrap 前提を Nix のみにする）。
  # 既存の /opt/homebrew は autoMigrate で再インストールせず引き継ぐ。
  nix-homebrew = {
    enable = true;
    user = "kato";
    autoMigrate = true;
    # 宣言 cask はすべて arm 対応のため Intel(Rosetta) prefix は不要。
    enableRosetta = false;
  };

  # GUI cask は Homebrew(cask) を nix-darwin の homebrew モジュールで宣言管理する
  # （このモジュールは brew bundle を駆動する）。
  homebrew = {
    enable = true;
    # 宣言外の formula/cask を自動でアンインストールする。
    # formula は宣言しない方針（CLI は nix/home-manager、プロジェクトは devbox）なので
    # これにより手動導入の brew formula は一掃される。
    onActivation.cleanup = "uninstall";
    caskArgs.appdir = "/Applications";
    taps = [ "manaflow-ai/cmux" ];
    casks = [
      "1password"
      "adobe-creative-cloud"
      "claude"
      "cmux"
      "codex-app"
      "docker-desktop"
      "google-chrome"
      "google-drive"
      "google-japanese-ime"
      "microsoft-office"
      "notion"
      "raycast"
      "slack"
      "zed"
    ];
  };

  # nix-darwin の state version。新規導入時の現行値。
  system.stateVersion = 6;
}
