{ pkgs, ... }:

pkgs.mkShell {
  packages = with pkgs; [
    just
    nix-diff
    betterleaks
    pinact
    zizmor
    ghalint
  ];

  shellHook = ''
    git config core.hooksPath .githooks
  '';
}
