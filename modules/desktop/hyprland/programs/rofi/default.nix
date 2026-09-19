{
  pkgs,
  lib,
  host,
  ...
}:
let
  inherit (import ../../../../../hosts/${host}/variables.nix) terminal;
  inherit (lib) getExe;
in
{
  home-manager.sharedModules = [
    (_: {
      programs.rofi = {
        enable = true;
        plugins = with pkgs; [
          rofi-emoji # https://github.com/Mange/rofi-emoji 🤯
          rofi-games # https://github.com/Rolv-Apneseth/rofi-games 🎮
        ];
        settings = {
          terminal = "${getExe pkgs.${terminal}}";
          extraConfig = import ./config.nix;
        };
      };
      xdg.configFile."rofi/launchers" = {
        source = ./launchers;
        recursive = true;
      };
      xdg.configFile."rofi/colors" = {
        source = ./colors;
        recursive = true;
      };
    })
  ];
}
