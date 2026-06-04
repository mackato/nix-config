{
  description = "kato home environment (nix-darwin + home-manager)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    nix-darwin.url = "github:nix-darwin/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs =
    {
      nixpkgs,
      nix-darwin,
      home-manager,
      nix-homebrew,
      ...
    }:
    let
      # 開発機(aarch64-darwin)と CI(x86_64-linux)の 2 system だけを対象にする。
      # flake-utils を入れず nixpkgs だけで forAllSystems 相当を手書き(YAGNI)。
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # ホスト名直書きをやめ汎用キー default に。単一マシン構成なので属性キーはラベルでよい。
      darwinConfigurations.default = nix-darwin.lib.darwinSystem {
        modules = [
          ./darwin/configuration.nix
          nix-homebrew.darwinModules.nix-homebrew
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # 既存の sync.sh 由来 symlink・実ファイルと衝突した場合は失敗させず退避する。
            home-manager.backupFileExtension = "hm-bak";
            home-manager.users.kato = import ./home/home.nix;
          }
        ];
      };

      # nix fmt 用。nixfmt 公式の treefmt ラッパー(ディレクトリ再帰・nix fmt 連携に対応)。
      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);

      # nix flake check で format / lint をまとめて検証する。検出時は非ゼロ終了で fail。
      checks = forAllSystems (pkgs: {
        nixfmt = pkgs.runCommand "check-nixfmt" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
          cd ${./.}
          find . -name '*.nix' -print0 | xargs -0 nixfmt --check
          touch $out
        '';

        statix = pkgs.runCommand "check-statix" { nativeBuildInputs = [ pkgs.statix ]; } ''
          cd ${./.}
          statix check .
          touch $out
        '';

        deadnix = pkgs.runCommand "check-deadnix" { nativeBuildInputs = [ pkgs.deadnix ]; } ''
          cd ${./.}
          deadnix --fail .
          touch $out
        '';
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.nixfmt
            pkgs.statix
            pkgs.deadnix
          ];
        };
      });
    };
}
