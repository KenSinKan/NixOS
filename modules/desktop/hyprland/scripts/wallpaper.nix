{ pkgs, defaultWallpaper, ... }:
let
  awww = "${pkgs.awww}/bin/awww";
in
pkgs.writeShellScriptBin "wallpaper" ''

# The daemon is managed by the systemd user service (services.awww.enable),
# starting a second one would make it crash-loop on the socket
systemctl --user start awww.service

# Wait for the daemon to accept commands
for _ in {1..20}; do
  ${awww} query &> /dev/null && break
  sleep 0.25
done

# Restore
${awww} restore &> /dev/null

# If there is no wallpaper then set the default
if ! ${awww} query | grep -q "image:" &> /dev/null; then
  ${awww} img "${../../../themes/wallpapers/${defaultWallpaper}}" --transition-step 255 --transition-duration 1 --transition-fps 60 --transition-type none
fi
''
