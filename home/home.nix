{ config, pkgs, ... }:

{
  home.username = "kato";
  home.homeDirectory = "/Users/kato";

  # home-manager の state version (現行 home-manager リリース)。
  home.stateVersion = "26.05";

  # CLI util / 開発 CLI。git/gnupg/gh/starship は programs.* が個別に導入する。
  # op (_1password-cli) は unfree（darwin の allowUnfree で許可済み）。
  home.packages = [
    pkgs.nkf
    pkgs.nmap
    pkgs.tree
    pkgs.ripgrep
    pkgs.fd
    pkgs.wget
    pkgs.awscli2
    pkgs.jq
    pkgs.uv
    pkgs._1password-cli
    pkgs.pinentry_mac
  ];

  programs.git = {
    enable = true;
    settings = {
      user.name = "Masakuni Kato";
      user.email = "7091+mackato@users.noreply.github.com";
      alias = {
        b = "branch";
        ci = "commit";
        co = "checkout";
        st = "status";
      };
      fetch.prune = true;
      init.defaultBranch = "main";
      # gpg.program のハードコード (/opt/homebrew/bin/gpg) は撤去し nix の gpg を使う。
      gpg.program = "${pkgs.gnupg}/bin/gpg";
    };
    signing = {
      key = "6054AA174EC010B988C00C92C8B4B8518B0395EB";
      signByDefault = true;
    };
    ignores = [ "**/.claude/settings.local.json" ];
  };

  programs.gpg.enable = true;

  programs.gh.enable = true;

  programs.starship.enable = true;

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;

    history = {
      size = 100000;
      save = 100000;
      share = true;
      ignoreDups = true;
      ignoreSpace = true;
    };

    shellAliases = {
      # Claude Code
      cc = "claude --allow-dangerously-skip-permissions";
      ccp = "claude --permission-mode plan --allow-dangerously-skip-permissions";
      ccw = "claude --allow-dangerously-skip-permissions --worktree";
      # Devbox
      dbx = "devbox";
      dbr = "devbox run";
      dbs = "devbox shell";
      # Docker
      dc = "docker compose";
      dcx = "docker compose exec";
      # Git / Python / Obsidian
      g = "git";
      python = "python3";
      ob = "Obsidian";
      # nix-darwin（単一マシン構成。flake の darwinConfigurations.default を適用）
      # flake のパスは ~/.zshrc.local の HOMEFILES_FLAKE（このリポジトリのクローン先の絶対パス）を参照する。
      # drs = darwin-rebuild switch: 日常の適用（flake.lock 不変なら GitHub API を叩かずトークン不要）
      drs = "sudo /run/current-system/sw/bin/darwin-rebuild switch --flake \"\${HOMEFILES_FLAKE:?set HOMEFILES_FLAKE in ~/.zshrc.local}#default\"";
      # dru = darwin-rebuild update: input 更新を伴う適用（flake update は GitHub API を叩くのでトークンを渡す）
      dru = "( cd \"\${HOMEFILES_FLAKE:?set HOMEFILES_FLAKE in ~/.zshrc.local}\" && NIX_CONFIG=\"access-tokens = github.com=\$(gh auth token)\" nix flake update ) && sudo /run/current-system/sw/bin/darwin-rebuild switch --flake \"\$HOMEFILES_FLAKE#default\"";
    };

    initContent = builtins.readFile ./files/zsh/init.zsh;

    # .zprofile (login)。brew shellenv が /opt/homebrew を PATH 前段に積むため、
    # 最後に nix profile を再前置して git/gpg 等が nix 版を指すようにする。
    profileExtra = (builtins.readFile ./files/zsh/profile.zsh) + ''

      export PATH="${config.home.profileDirectory}/bin:$PATH"
    '';
  };

  # GPG agent の pinentry を nix の pinentry-mac に向ける。
  home.file.".gnupg/gpg-agent.conf".text = ''
    pinentry-program ${pkgs.pinentry_mac}/bin/pinentry-mac
  '';

  # 残りの静的 dotfiles。
  home.file.".config/ghostty/config".source = ./files/ghostty/config;
  home.file.".config/zed/settings.json".source = ./files/zed/settings.json;
  home.file.".claude/CLAUDE.md".source = ./files/claude/CLAUDE.md;
}
