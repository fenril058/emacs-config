# show recipe list
_:
    @just --list

# Sync lock/flake.nix and lock/archive.lock with the current package set in
# init.org, then run `nix flake lock` to add/remove entries in lock/flake.lock.
# Does NOT update locked SHAs of existing git packages — use update-lock for that.
lock:
    nix run .\#lock --impure -L

# Update locked SHAs of git packages (MELPA/ELPA) in lock/flake.lock.
# No args: update all. With args: update specific packages only.
# e.g. just update-lock evil magit
update-lock *pkgs:
    cd lock && nix flake update {{pkgs}}

# Update registry inputs (melpa, gnu-elpa, nongnu-elpa, epkgs) in flake.lock.
# Needed before update-archive or lock when you want the latest registry metadata.
update-registries:
    nix flake update melpa gnu-elpa nongnu-elpa epkgs

# Fetch latest versions from ELPA archives and write to lock/archive.lock.
# Runs update-registries first.
# (In this repo all packages are git-sourced, so archive.lock stays empty for now.)
update-archive: update-registries
    nix run .\#update --impure -L

# Review changes to lock/flake.lock (per-package compare links).
# Run after `just lock` or `just update-lock`, before committing.
review base="HEAD":
    emacs -Q --batch --script scripts/review-lock.el {{base}}

# Show .el diffs for packages whose revisions changed in lock/flake.lock.
# Fetches diffs via GitHub/GitLab API; falls back to bare git-clone.
# Run after `just review`, before committing.
diff-el base="HEAD":
    emacs -Q --batch --script scripts/diff-el.el {{base}}

# Show derivation-level diff for native deps (poppler, vterm, etc.).
# Run after `just lock` or `just update-lock` when native packages may have changed.
diff-drv base="HEAD":
    #!/usr/bin/env bash
    set -euo pipefail
    sys=$(nix eval --raw --impure --expr builtins.currentSystem)
    root=$(git rev-parse --show-toplevel)
    base_drv=$(nix eval --raw "git+file://${root}?rev=$(git rev-parse {{base}})"#packages.${sys}.default.drvPath)
    cur_drv=$(nix eval --raw --impure ".#packages.${sys}.default.drvPath")
    nix-diff "${base_drv}" "${cur_drv}"
