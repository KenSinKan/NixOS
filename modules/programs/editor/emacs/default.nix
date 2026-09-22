{ pkgs, ... }:
{
  home-manager.sharedModules = [
    (_: {
      programs.emacs = {
        enable = true;
        package = pkgs.emacs-pgtk;
      };
      services.emacs = {
        enable = true;
        client = {
          enable = true;
          arguments = [
            "-c"
            "-a"
            "'emacs'"
          ];
        };
      };
    })
  ];
}
