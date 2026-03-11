{ pkgs, ... }:
{
  home-manager.sharedModules = [
    (_: {
      programs.zed-editor = {
        enable = true;
        extraPackages = with pkgs; [
          nixd
          lldb
        ];
      };
    })
  ];
}
