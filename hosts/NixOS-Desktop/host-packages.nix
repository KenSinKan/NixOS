{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    (llama-cpp.override { cudaSupport = true; })
  ];

  programs.coolercontrol.enable = true;
}
