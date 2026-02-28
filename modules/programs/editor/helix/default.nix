{
  pkgs,
  inputs,
  ...
}:
{
  home-manager.sharedModules = [
    (_: {
      home.file.".config/helix/snippets.toml".text = ''
        [[snippets]]
        scope = ["cpp"]
        prefix = "cfcph"
        body = """
        #include <bits/stdc++.h>

        using namespace std;

        #define all(x) x.begin(), x.end()
        #define endl '\n'

        using ll = long long;

        [[maybe_unused]] struct {
          template <class T> operator T() const { return numeric_limits<T>::max() / 2; }

          struct NegInF {
            template <class U> operator U() const {
              return numeric_limits<U>::min() / 2;
            }
          };
          NegInF operator-() const { return {}; }
        } const InF;
        [[maybe_unused]] constexpr ll MOD = 1e9 + 7;

        template <class T, class U> istream &operator>>(istream &is, pair<T, U> &p) {
          return is >> p.first >> p.second;
        }
        template <class T> istream &operator>>(istream &is, vector<T> &v) {
          for (T &x : v)
            is >> x;
          return is;
        }

        #ifdef LOCAL
        #include <iostream>
        #include <print>

        #define debug(...) std::println(std::cerr, __VA_ARGS__)
        #define dbg(x) std::println(std::cerr, "{} = {}", #x, x)

        #else
        #define debug(...)
        #define dbg(x)
        #endif

        void solve() {
          $0
        }

        int main() {
          int tt = 1;
          // ''${1:cin >> tt;}
          while (tt--) {
            solve();
          }
          return 0;
        }
        """
      '';
      programs.helix = {
        enable = true;
        extraPackages = [
          pkgs.nixd
          pkgs.simple-completion-language-server
        ];
        settings = {
          theme = "catppuccin_mocha";
          editor = {
            auto-completion = true;
            smart-tab.enable = true;
            line-number = "relative";
            indent-guides.render = true;
            true-color = true;
            cursorline = true;
            cursorcolumn = false;
            default-line-ending = "lf";
            # rainbow-brackets = true;
            end-of-line-diagnostics = "hint";
            insert-final-newline = false;
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
            # nil = {
            #   command = "nil";
            #   config = {
            #     formatting = {
            #       command = [ "alejandra" ];
            #     };
            #     nix = {
            #       maxMemoryMB = 16000;
            #       flake = {
            #         autoArchive = true;
            #         autoEvalInputs = true;
            #       };

            #     };
            #   };
            # };
            scls = {
              command = "${pkgs.simple-completion-language-server}/bin/simple-completion-language-server";
            };
            nixd = {
              command = "nixd";
              args = [ ];
              config.nixd = {
                nixpkgs = {
                  expr = "import ${inputs.nixpkgs} { }";
                };
                formatting = {
                  command = [ "alejandra" ];
                };
              };
            };
            pyright = {
              command = "pyright-langserver";
              args = [ "--stdio" ];
              config = { }; # <- this is the important line
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
            };
          };

          language = [
            {
              name = "nix";
              language-servers = [
                "nixd"
                "nil"
              ];
              formatter.command = "alejandra";
              auto-format = true;
            }
            {
              name = "cpp";
              language-servers = [
                "clangd"
                "scls"
              ];
            }
          ];

          formatter = {
            black = {
              command = "black";
              args = [
                "-"
                "-q"
              ];
            };
            nixfmt = {
              command = "nixfmt";
            };
          };
        };
      };
    })
  ];
}
