{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "fmt";
  runtimeInputs = [
    pkgs.treefmt
    pkgs.nixfmt
    pkgs.lychee
    pkgs.typos
  ];
  text = ''
    set -euo pipefail
    root="''${PRJ_ROOT:-$(pwd)}"
    exec treefmt --config-file "$root/treefmt.toml" --tree-root "$root" "$@"
  '';
}
