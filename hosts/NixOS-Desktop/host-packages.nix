{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [ ];

  programs.coolercontrol.enable = true;
}
