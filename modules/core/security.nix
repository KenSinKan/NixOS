{ pkgs, ... }:
{
  security = {
    rtkit.enable = true;
    polkit.enable = true;
    apparmor = {
      enable = true;
      killUnconfinedConfinables = true;
      packages = [ pkgs.apparmor-profiles ];
    };
    sudo.extraRules = [
      {
        users = [
          "maksim"
        ];
        commands = [
          {
            command = "/run/current-system/sw/bin/tlp";
            options = [
              "SETENV"
              "NOPASSWD"
            ];
          }
        ];
      }
    ];
  };
}
