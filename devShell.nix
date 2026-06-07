{ pkgs, ... }:

pkgs.mkShell {
  packages = with pkgs; [
    just
    lychee
    betterleaks
    pinact
    zizmor
    ghalint
  ];

  # https://nixos.org/manual/nixpkgs/stable/#javascript-packages-nixpkgs
  postShellHook = ''
    git config core.hooksPath .githooks
  '';
}
