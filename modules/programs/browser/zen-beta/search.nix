{ pkgs, ... }:
{
  force = true;
  default = "google";
  privateDefault = "google";
  # order = [
  #   "Startpage"
  #   "Brave"
  #   "NixOS Packages"
  #   "NixOS Options"
  #   "NixOS Wiki"
  #   "Home Manager Options"
  #   "google"
  # ];
  engines =
    let
      icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
    in
    {
      # "Startpage" = {
      #   urls = [
      #     {
      #       template = "https://www.startpage.com/sp/search?query={searchTerms}";
      #     }
      #   ];
      #   # icon = "''${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
      #   icon = "https://www.startpage.com/sp/cdn/favicons/favicon-gradient.ico";
      #   definedAliases = [ "@sp" ];
      # };
      # "Brave" = {
      #   urls = [
      #     {
      #       template = "https://search.brave.com/search";
      #       params = [
      #         {
      #           name = "q";
      #           value = "{searchTerms}";
      #         }
      #       ];
      #     }
      #   ];
      #   icon = "https://brave.com/static-assets/images/brave-logo-sans-text.svg";
      #   definedAliases = [ "@br" ];
      # };
      # "NixOS Packages" = {
      #   inherit icon;
      #   urls = [
      #     {
      #       template = "https://search.nixos.org/packages";
      #       params = [
      #         {
      #           name = "type";
      #           value = "packages";
      #         }
      #         {
      #           name = "query";
      #           value = "{searchTerms}";
      #         }
      #       ];
      #     }
      #   ];
      #   definedAliases = [
      #     "@np"
      #     "@nixpkgs"
      #   ];
      # };
      # "NixOS Options" = {
      #   inherit icon;
      #   urls = [
      #     {
      #       template = "https://search.nixos.org/options";
      #       params = [
      #         {
      #           name = "type";
      #           value = "packages";
      #         }
      #         {
      #           name = "query";
      #           value = "{searchTerms}";
      #         }
      #       ];
      #     }
      #   ];
      #   definedAliases = [
      #     "@no"
      #     "@nixopts"
      #   ];
      # };
      "NixOS Wiki" = {
        inherit icon;
        urls = [ { template = "https://nixos.wiki/index.php?search={searchTerms}"; } ];
        definedAliases = [ "@nw" ];
      };
      # "Home Manager" = {
      #   inherit icon;
      #   urls = [ { template = "https://home-manager-options.extranix.com/?query={searchTerms}"; } ];
      #   # urls = [
      #   #   {
      #   #     template = "https://mipmip.github.io/home-manager-option-search";
      #   #     params = [
      #   #       {
      #   #         name = "query";
      #   #         value = "{searchTerms}";
      #   #       }
      #   #     ];
      #   #   }
      #   # ];
      #   definedAliases = [
      #     "@hm"
      #     "@home"
      #     "homeman"
      #   ];
      # };
      # "My NixOS" = {
      #   inherit icon;
      #   urls = [ { template = "https://mynixos.com/search?q={searchTerms}"; } ];
      #   definedAliases = [
      #     "@mn"
      #     "@nx"
      #     "@mynixos"
      #   ];
      # };
      # "Noogle" = {
      #   inherit icon;
      #   urls = [ { template = "https://noogle.dev/q?term={searchTerms}"; } ];
      #   definedAliases = [
      #     "@noogle"
      #     "@ng"
      #   ];
      # };
      # "youtube" = {
      #   urls = [ { template = "https://youtube.com/results?search_query={searchTerms}"; } ];
      #   definedAliases = [ "@yt" ];
      # };
      "bing".metaData.hidden = true;
      "Ebay".metaData.hidden = true;
      "google".metaData.alias = "@g"; # builtin engines only support specifying one additional alias
    };
}
