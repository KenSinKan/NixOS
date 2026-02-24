{ ... }:
{
  services.auto-cpufreq = {
    enable = false;
    settings = {
      charger = {
        governor = "performance";
        turbo = "auto";
      };
      battery = {
        governor = "schedutil";
        turbo = "never";
      };
    };
  };
}
