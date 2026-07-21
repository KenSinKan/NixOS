{ pkgs, ... }:

{
  services.xserver = {
    # enable = true;  # Already enabled in display manager
    videoDrivers = [ "amdgpu" ];
  };
  environment.systemPackages = with pkgs; [ rocmPackages.amdsmi ];
  hardware.amdgpu = {
    opencl.enable = true;
    initrd.enable = true;
    overdrive = {
      enable = true;
      ppfeaturemask = "0xffffffff";
    };
  };
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      rocmPackages.clr.icd
    ];
  };
}
