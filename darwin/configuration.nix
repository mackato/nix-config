# 個人レイヤーの system 層。会社標準（system/nix 設定・nix-homebrew・homebrew.onActivation・
# 共通 cask）は airs/nix-config の darwinModules.base が宣言する。ここは個人の GUI アプリのみ。
_:

{
  homebrew = {
    taps = [ "manaflow-ai/cmux" ];
    # 個人の GUI cask。airs 側の casks と自動連結マージされ、
    # cleanup="uninstall" は合成後の和集合に対して働く。
    casks = [
      "1password"
      "adobe-creative-cloud"
      "claude"
      "cmux"
      "codex-app"
      "docker-desktop"
      "google-japanese-ime"
      "microsoft-office"
      "notion"
      "raycast"
      "zed"
    ];
  };
}
