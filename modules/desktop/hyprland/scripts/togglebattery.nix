{ pkgs, ... }:
pkgs.writeShellScriptBin "toggle-battery" ''
  PATH_FILE="/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode"

  STATUS=$(${pkgs.coreutils}/bin/cat "$PATH_FILE")

  if [ "$STATUS" -eq "0" ]; then
      echo 1 > "$PATH_FILE"
      ${pkgs.libnotify}/bin/notify-send "Battery" "Режим защиты батареи 🛡️" -i battery-good-symbolic
  else
      echo 0 > "$PATH_FILE"
      ${pkgs.libnotify}/bin/notify-send "Battery" "Режим макс. зарядки ⚡" -i battery-full
  fi
''
