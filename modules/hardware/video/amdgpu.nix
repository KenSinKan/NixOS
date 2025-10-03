# This module is untested since i don't own an amd gpu!
{ pkgs, ... }:
{
  services.xserver = {
    enable = true;
    videoDrivers = [ "amdgpu" ];
  };
  boot.initrd.kernelModules = [ "amdgpu" ];
  hardware.amdgpu.initrd.enable = true;
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    # driSupport = true;
    # driSupport32Bit = true;
    extraPackages = with pkgs; [
      rocmPackages.clr.icd
      rocmPackages.clr
      rocmPackages.clr
      rocmPackages.rocminfo
      rocmPackages.rocm-runtime
      mesa
      libva
      libvdpau-va-gl
      vulkan-loader
      vulkan-validation-layers
      amdvlk # Optional: AMD's proprietary Vulkan driver
      mesa.opencl # Enables Rusticl (OpenCL) support
    ];
  };
  environment.variables = {
    RUSTICL_ENABLE = "radeonsi";
    ROC_ENABLE_PRE_VEGA = "1";
  };
}
