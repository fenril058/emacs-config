{
  config,
  lib,
  pkgs,
  flake,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  config = lib.mkIf config.programs.emacs-twist.enable {
    programs.emacs-twist = {
      emacsclient.enable = true;
      createInitFile = true;
      createManifestFile = true;
      config = flake.packages.${system}.default;
      earlyInitFile = flake.earlyInitEl.${system};
    };

    xdg.desktopEntries.emacs-nix = {
      name = "Emacs (nix)";
      genericName = "Text Editor";
      comment = "GNU Emacs Text Editor";
      exec = "${config.home.profileDirectory}/bin/emacs %F";
      icon = "${pkgs.emacs-gtk}/share/icons/hicolor/128x128/apps/emacs.png";
      terminal = false;
      startupNotify = true;
      categories = [
        "Utility"
        "Development"
        "TextEditor"
      ];
      mimeType = [
        "text/plain"
        "text/x-makefile"
        "text/x-c"
        "text/x-c++"
        "text/x-java"
        "application/x-shellscript"
      ];
      settings = {
        StartupWMClass = "Emacs";
      };
    };

    home.packages = with pkgs; [
      just
      nixd
      hunspell
      hunspellDicts.en_US

      # Packages below are managed in init.org
      # tree-sitter
      # nixfmt
    ];

    home.file = {
      ".config/emacs/snippets".source = ./snippets;
    };
  };
}
