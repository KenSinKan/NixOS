{
  # User Configuration
  username = "maksim"; # Your username (auto-set with install.sh, live-install.sh, rebuild)
  desktop = "hyprland"; # Options: hyprland, i3-gaps, gnome, plasma6
  terminal = "alacritty"; # Options: kitty, alacritty
  editor = "vscode"; # Options: nixvim, vscode, helix, nvchad, neovim, emacs (WIP)
  browser = "firefox"; # Options: firefox, floorp, zen
  tuiFileManager = "yazi"; # Options: yazi, lf
  sddmTheme = "astronaut"; # Options: astronaut, black_hole, purple_leaves, jake_the_dog, hyprland_kath
  wallpaper = "moon"; # See modules/themes/wallpapers for options
  shell = "zsh"; # Options: zsh, bash
  games = true; # Whether to enable the gaming module

  # Hardware Configuration
  videoDriver = "amdgpu"; # CRITICAL: Choose your GPU driver (nvidia, amdgpu, intel)
  hostname = "Laptop"; # Your system hostname

  # Localization
  clock24h = true; # 24H or 12H clock in waybar
  locale = "ru_RU.UTF-8"; # System locale
  timezone = "Europe/Moscow"; # Your timezone
  kbdLayout = "us,ru"; # Keyboard layout
  kbdVariant = ""; # Keyboard variant (can be empty)
  consoleKeymap = "us"; # TTY keymap
}
