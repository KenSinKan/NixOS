{ host, ... }:
let
  inherit (import ../../hosts/${host}/variables.nix) username;
in
{
  services.syncthing = {
    enable = true;
    user = "${username}";
    dataDir = "/home/${username}";
    openDefaultPorts = true;
  };
}
