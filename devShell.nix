{ pkgs, ... }:

pkgs.mkShell {
  packages = with pkgs; [
    just
    nix-diff
    betterleaks
    pinact
    zizmor
    ghalint
    lychee # `just check-links` (no longer part of `nix fmt`)
  ];

  shellHook = ''
    git config core.hooksPath .githooks
  '';
}
