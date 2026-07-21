{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  codelldb-pkg = pkgs.vscode-extensions.vadimcn.vscode-lldb;
  codelldb-path = "${codelldb-pkg}/share/vscode/extensions/vadimcn.vscode-lldb/adapter/codelldb";
  libcodelldb-path = "${codelldb-pkg}/share/vscode/extensions/vadimcn.vscode-lldb/lldb/lib/libcodelldb.so";
in
{
  home-manager.sharedModules = [
    (_: {
      programs.helix = {
        enable = true;

        extraPackages = with pkgs; [ nixd ];

        settings = {
          theme = "catppuccin_mocha";

          editor = {
            auto-completion = true;
            smart-tab.enable = false;
            line-number = "relative";
            indent-guides.render = true;
            true-color = true;
            cursorline = true;
            cursorcolumn = false;
            default-line-ending = "lf";
            end-of-line-diagnostics = "hint";
            insert-final-newline = false;
            auto-format = true;

            gutters = [
              "diff"
              "line-numbers"
              "spacer"
              "diagnostics"
            ];
            color-modes = true;
            bufferline = "always";
            completion-replace = false;

            cursor-shape = {
              insert = "bar";
              normal = "block";
              select = "underline";
            };

            file-picker = {
              hidden = true;
            };

            soft-wrap = {
              enable = true;
              wrap-at-text-width = false;
            };

            lsp = {
              display-inlay-hints = true;
              display-progress-messages = true;
            };

            statusline = {
              left = [
                "mode"
                "spinner"
                "read-only-indicator"
                "diagnostics"
              ];
              center = [ "file-name" ];
              right = [
                "version-control"
                "selections"
                "primary-selection-length"
                "total-line-numbers"
                "position"
                "file-encoding"
                "file-line-ending"
                "file-type"
              ];
              separator = "|";
              mode.normal = "NORMAL";
              mode.insert = "INSERT";
              mode.select = "SELECT";
            };

            whitespace = {
              render = {
                tab = "all";
              };
            };

            auto-save = {
              after-delay.enable = false;
              after-delay.timeout = 1000;
              focus-lost = true;
            };
          };
        };

        languages = {
          language-server = {

            nixd = {
              command = "nixd";
              args = [ ];
              config.nixd = {
                nixpkgs = {
                  expr = "import ${inputs.nixpkgs} { }";
                };
                formatting = {
                  command = [ "nixfmt" ];
                };
              };
            };

            ty = {
              command = "ty";
            };

            ruff = {
              command = "ruff";
              args = [ "server" ];
            };

            rust-analyzer.config = {
              checkOnSave = true;
              cachePriming.enable = true;
              diagnostics.experimental.enable = true;
              check.features = "all";
              procMacro.enable = true;
              cargo.buildScripts.enable = true;
              imports.preferPrelude = true;
              serverPath = "${pkgs.lspmux}/bin/lspmux";
              lldb.libraryPath = libcodelldb-path;
            };
          };

          language = [
            {
              name = "nix";
              language-servers = [ "nixd" ];
              formatter.command = "nixfmt";
              auto-format = true;
            }
            {
              name = "rust";
              indent = {
                tab-width = 4;
                unit = "    ";
              };
              auto-format = true;
            }
            {
              name = "python";

              language-servers = [
                "ty"
                "ruff"
              ];

              formatter = {
                command = "ruff";
                args = [
                  "format"
                  "-"
                ];
              };
              auto-format = true;
            }
            {
              name = "cpp";
              auto-format = true;
              debugger = {
                name = "codelldb";
                transport = "tcp";
                command = codelldb-path;
                templates = [ ];
              };
            }
          ];

          formatter = {
            nixfmt = {
              command = "nixfmt";
            };
          };
        };
      };
    })
  ];
}
