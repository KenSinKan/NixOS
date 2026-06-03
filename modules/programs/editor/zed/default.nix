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
      programs.zed-editor = {
        enable = true;
        extensions = [
          "nix"
          "toml"
          "slint"
          "typst"
        ];
        mutableUserSettings = false;
        userSettings = {
          auto_update = false;
          project_panel.dock = "left";
          git_panel.dock = "left";
          collaboration_panel.dock = "left";
          outline_panel.dock = "left";
          terminal.dock = "bottom";
          diagnostics.inline.enabled = true;
          disable_ai = true;
          telemetry.diagnostics = false;
          telemetry.metrics = false;
          sticky_scroll.enabled = false;
          minimap.show = "never";
          scrollbar.axes.horizontal = false;
          scrollbar.axes.vertical = false;
          max_tabs = 10;
          auto_indent_on_paste = true;
          show_edit_predictions = true;
          tab_size = 2;
          base_keymap = "VSCode";
          autosave = "on_focus_change";
          buffer_font_size = 14.0;
          debugger.dock = "right";
          debugger.log_dap_communications = true;
          debugger.format_dap_log_messages = true;
          edit_predictions.mode = "subtle";
          format_on_save = "on";
          inlay_hints.enabled = true;
          inlay_hints.show_other_hints = true;
          inlay_hints.show_parameter_hints = true;
          inlay_hints.show_type_hints = true;
          inlay_hints.show_value_hints = true;
          journal.hour_format = "hour24";
          languages."C++" = {
            auto_indent_on_paste = true;
            show_edit_predictions = true;
          };
          languages.Nix.language_servers = [
            "nixd"
            "!nil"
          ];
          languages.Python = {
            language_servers = [
              "ty"
              "ruff"
              "!..."
            ];
          };
          languages.Rust = {
            tab_size = 4;
          };
          lsp = {
            ruff.binary = {
              path = lib.getExe pkgs.ruff;
              arguments = [ "server" ];
            };
            ty.binary = {
              path = lib.getExe pkgs.ty;
              arguments = [ "server" ];
            };
            nixd.binary.path = lib.getExe pkgs.nixd;
            clangd.binary.path = lib.getExe' pkgs.clang-tools "clangd";
            package-version-server.binary.path = lib.getExe pkgs.package-version-server;
            rust-analyzer.initialization_options.lldb.libraryPath = libcodelldb-path;
            slint.binary.path = lib.getExe pkgs.slint-lsp;
            tinymist.binary.path = lib.getExe pkgs.tinymist;
          };
          load_direnv = "shell_hook";
          theme.dark = "One Dark";
          theme.light = "One Light";
          theme.mode = "dark";
          ui_font_size = 16;
          vim_mode = false;
          node = {
            path = lib.getExe pkgs.nodejs;
            npm_path = lib.getExe' pkgs.nodejs "npm";
          };
          dap.CodeLLDB.binary = codelldb-path;
        };
      };
    })
  ];
}
