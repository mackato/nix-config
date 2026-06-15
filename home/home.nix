# 個人レイヤーの home 層。会社標準（共通 CLI util・gh・git の中立設定）は airs/nix-config の
# homeModules.base が宣言する。home.username / homeDirectory / stateVersion は
# airs の mkDarwinConfig が username 引数から導出する。
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Claude Code(CC) / Codex CLI で共有する正本（このリポジトリの作業ツリー）の絶対パス。
  # mkOutOfStoreSymlink は store ではなく作業ツリーを指す可変 symlink を張るため絶対パスが要る
  # （編集が switch なしで即反映され、編集対象がそのまま git 追跡される）。eval 時に確定する
  # 定数なので実行時の NIX_CONFIG_FLAKE は参照できない。clone を別の場所にする場合は、ここ・
  # setup.sh の DEFAULT_REPO・~/.zshrc.local の NIX_CONFIG_FLAKE の 3 箇所を必ず揃えること
  # （ズレると CC/Codex 用 symlink が dangling になり共有ファイルを読めない）。
  repoRoot = "${config.home.homeDirectory}/gh/mackato/nix-config";
  ccDir = "${repoRoot}/home/files/claude";
  mkLink = config.lib.file.mkOutOfStoreSymlink;

  # Claude Code の user スコープ MCP サーバ（ともに npx 起動の stdio サーバ。node が前提）。
  # command は ${config.home.profileDirectory}/bin/npx（= pkgs.nodejs の npx）を絶対指定し、
  # spawn 時の PATH や Homebrew npx に依存しないようにする。
  mcpServers = {
    context7 = {
      type = "stdio";
      command = "${config.home.profileDirectory}/bin/npx";
      args = [
        "-y"
        "@upstash/context7-mcp"
      ];
    };
    playwright = {
      type = "stdio";
      command = "${config.home.profileDirectory}/bin/npx";
      # -y は初回 npx 実行時のインストール確認プロンプトを抑止する（非対話 spawn でのハング防止）。
      args = [
        "-y"
        "@playwright/mcp@latest"
      ];
    };
  };
in
{
  # 個人の CLI util / 開発 CLI。gnupg/starship は programs.* が個別に導入する。
  # op (_1password-cli) は unfree（airs 側の allowUnfree で許可済み）。
  home.packages = [
    pkgs._1password-cli
    pkgs.awscli2
    pkgs.nmap
    pkgs.nodejs
    pkgs.pinentry_mac
    pkgs.uv
  ];

  # git の identity・署名・alias・ignores は個人設定。
  # 中立設定（enable / init.defaultBranch / fetch.prune）は airs 側が mkDefault で宣言する。
  programs.git = {
    settings = {
      user.name = "Masakuni Kato";
      user.email = "7091+mackato@users.noreply.github.com";
      alias = {
        b = "branch";
        ci = "commit";
        co = "checkout";
        st = "status";
      };
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
      # nix-darwin（単一マシン構成）。flake のパスは ~/.zshrc.local の NIX_CONFIG_FLAKE
      # （このリポジトリのクローン先の絶対パス）、適用する darwinConfigurations の属性名は
      # NIX_CONFIG_ATTR（未設定なら default）を参照する。
      # drs = darwin-rebuild switch: 日常の適用（flake.lock 不変なら GitHub API を叩かずトークン不要）
      drs = "sudo /run/current-system/sw/bin/darwin-rebuild switch --flake \"\${NIX_CONFIG_FLAKE:?set NIX_CONFIG_FLAKE in ~/.zshrc.local}#\${NIX_CONFIG_ATTR:-default}\"";
      # dru = darwin-rebuild update: input 更新を伴う適用（flake update は GitHub API を叩くのでトークンを渡す）
      dru = "( cd \"\${NIX_CONFIG_FLAKE:?set NIX_CONFIG_FLAKE in ~/.zshrc.local}\" && NIX_CONFIG=\"access-tokens = github.com=\$(gh auth token)\" nix flake update ) && sudo /run/current-system/sw/bin/darwin-rebuild switch --flake \"\$NIX_CONFIG_FLAKE#\${NIX_CONFIG_ATTR:-default}\"";
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

  # AI コーディングツールの共有設定。CC を正本（source of truth）とし、Codex は同一実体を参照する。
  # 可変 symlink（mkOutOfStoreSymlink）で repo 作業ツリーを直接指すので、編集は switch なしで両者に反映される。
  # CLAUDE.md は @import 等の CC 固有記法を含まず、Codex には literal テキストとして渡る（見出しの "CLAUDE.md" もそのまま表示される）。
  # 指示ファイル: ~/.claude/CLAUDE.md と ~/.codex/AGENTS.md を同一実体（repo の CLAUDE.md）へ直接向ける（チェーンしない）。
  home.file.".claude/CLAUDE.md".source = mkLink "${ccDir}/CLAUDE.md";
  home.file.".codex/AGENTS.md".source = mkLink "${ccDir}/CLAUDE.md";
  # skills: repo 管理スキルを ~/.claude/skills/ 配下に個別配置する（repo 外の既存スキルは温存される）。
  home.file.".claude/skills/cycle".source = mkLink "${ccDir}/skills/cycle";
  # Codex のユーザースキルは ~/.agents/skills。実ディレクトリ ~/.claude/skills を指し、全スキル（repo 管理＋既存）を共有する。
  home.file.".agents/skills".source = mkLink "${config.home.homeDirectory}/.claude/skills";

  # Claude Code の MCP は user スコープでも ~/.claude.json（Claude が常時書き込むステートフルファイル）に
  # 保存されるため、CLAUDE.md/skills のような symlink 宣言管理ができない。switch のたびに top-level の
  # mcpServers へ上記サーバを冪等に注入し、他サーバ（chrome-devtools 等）と Claude 側の他状態（projects 等）は
  # 温存する。$DRY_RUN_CMD はリダイレクトと相性が悪いので実書き込みする mv のみ包む（jq の出力先は捨てる temp）。
  home.activation.claudeMcpServers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    claudeJson="${config.home.homeDirectory}/.claude.json"
    # temp は同一ディレクトリにテンプレート付きで作る（BSD/GNU 両対応、かつ mv が atomic rename に
    # なり Claude が読むファイルの破損を防ぐ）。jq 失敗時は元ファイルを残し temp を掃除して中断する。
    tmp="$(mktemp "$claudeJson.XXXXXX")"
    if { [ -e "$claudeJson" ] && cat "$claudeJson" || echo '{}'; } \
         | ${pkgs.jq}/bin/jq \
             --argjson servers '${builtins.toJSON mcpServers}' \
             '.mcpServers = (.mcpServers // {}) + $servers' \
             > "$tmp"; then
      $DRY_RUN_CMD mv "$tmp" "$claudeJson"
    else
      rm -f "$tmp"
      exit 1
    fi
  '';
}
