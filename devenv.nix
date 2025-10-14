{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:

{
  languages.nix = {
    enable = true;
    lsp.package = pkgs.nixd;
  };

  git-hooks.hooks.nixfmt-rfc-style.enable = true;
}
