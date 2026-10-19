{
  config,
  lib,
  pkgs,
  flake,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;

  # flake inputs を推移的に集める（評価時に fetch されるソース）
  collectInputs =
    inputs:
    lib.concatMap (input: [ input.outPath ] ++ collectInputs (input.inputs or { })) (
      lib.attrValues inputs
    );

  # 各パッケージの src（lock/flake.lock や archive.lock から評価時に fetch される）
  packageSources = lib.concatMap (p: lib.optional (p ? src) "${p.src}") (
    lib.attrValues flake.packages.${system}.default.packageInputs
  );
in
{
  config = lib.mkIf config.programs.emacs-twist.enable {
    programs.emacs-twist = {
      emacsclient.enable = true;
      createInitFile = true;
      createManifestFile = true;
      config = flake.packages.${system}.default;
      earlyInitFile = flake.packages.${system}.earlyInitEl;
      # We define our own xdg.desktopEntries.emacs-nix below, so suppress the
      # module's desktop item to avoid a duplicate launcher entry.
      desktopItem.enable = false;
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

    # 評価に使うソースを世代の閉包に入れ、GC 後の再ダウンロードを防ぐ
    home.extraDependencies = lib.unique (collectInputs flake.inputs ++ packageSources);

    home.file = {
      ".config/emacs/snippets".source = ./snippets;
      ".config/emacs/insert".source = ./insert;
    };
  };
}
