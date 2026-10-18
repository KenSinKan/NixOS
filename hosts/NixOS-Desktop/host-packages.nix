{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [ llama-cpp ];

  programs.coolercontrol.enable = true;
}
