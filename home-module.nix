{ config, lib, pkgs, flake, ... }:
let
  system = pkgs.stdenv.hostPlatform.system;
  emacsDesktopItem = pkgs.makeDesktopItem {
    name = "emacs-nix";
    desktopName = "Emacs (nix)";
    genericName = "Text Editor";
    comment = "GNU Emacs Text Editor";
    exec = "${pkgs.emacs-gtk}/bin/emacs %F";
    icon = "${pkgs.emacs-gtk}/share/icons/hicolor/128x128/apps/emacs.png";
    type = "Application";
    startupNotify=true;
    startupWMClass = "Emacs";
    terminal = false;
    categories = [ "Utility" "Development" "TextEditor" ];
    mimeTypes = [
      "text/english"
      "text/plain"
      "text/x-makefile"
      "text/x-c++hdr"
      "text/x-c++src"
      "text/x-chdr"
      "text/x-csrc"
      "text/x-java"
      "text/x-moc"
      "text/x-pascal"
      "text/x-tcl"
      "text/x-tex"
      "application/x-shellscript"
      "text/x-c"
      "text/x-c++"
    ];
  };
in
{
  programs.emacs-twist = {
    enable = true;
    emacsclient.enable = true;
    createInitFile = true;
    createManifestFile = true;
    config = flake.packages.${system}.default;
    earlyInitFile = flake.earlyInitEl.${system};
  };

  home.packages =  [
    emacsDesktopItem
    pkgs.tree-sitter
  ];

  home.file = {
    ".local/bin/mozc_emacs_helper.sh" = {
      text = ''
           #!/bin/sh
           cd
           mozc_emacs_helper.exe "$@" 2> /dev/null
           '';
      executable = true;
    };
  };
}
