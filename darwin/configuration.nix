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

  # nix-darwin の state version。新規導入時の現行値。
  system.stateVersion = 6;
}
