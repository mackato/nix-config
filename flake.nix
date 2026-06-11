{
  description = "kato personal layer on airs/nix-config (nix-darwin + home-manager)";

  inputs = {
    # 会社標準レイヤー。nixpkgs / nix-darwin / home-manager / nix-homebrew は
    # この input 経由で解決する（dru の flake update で nested input も更新される）。
    airs.url = "github:airs/nix-config";
  };

  outputs =
    { airs, ... }:
    let
      # formatter / checks / devShells 用の nixpkgs は airs の input を再利用する。
      inherit (airs.inputs) nixpkgs;
      # 開発機(aarch64-darwin)と CI(x86_64-linux)の 2 system だけを対象にする。
      # flake-utils を入れず nixpkgs だけで forAllSystems 相当を手書き(YAGNI)。
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # 会社標準（darwinModules.base / homeModules.base・home-manager 配線・stateVersion）は
      # airs の mkDarwinConfig が組み立てる。ここでは個人レイヤーのモジュールだけを渡す。
      # 単一マシン構成なので属性キーはラベルでよい（汎用キー default）。
      darwinConfigurations.default = airs.lib.mkDarwinConfig {
        username = "kato";
        extraModules = [ ./darwin/configuration.nix ];
        extraHomeModules = [ ./home/home.nix ];
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
