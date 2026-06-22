# show recipe list
_:
    @just --list

# Regenerate lock/flake.lock and lock/flake.nix. Never edit lock/ by hand.
# Adds/removes packages but does NOT update locked SHAs of existing packages.
# Use `just upgrade` to update SHAs.
lock:
    nix run .\#lock --impure -L

# Update locked SHAs of Emacs packages in lock/flake.lock.
# No args: update all. With args: update named packages only.
# e.g. just upgrade evil magit
upgrade *pkgs:
    cd lock && nix flake update {{pkgs}}

# Refresh package registries (melpa, gnu-elpa, nongnu-elpa, epkgs).
update-inputs:
    nix flake update melpa gnu-elpa nongnu-elpa epkgs

# Refresh registries then update package metadata. Order: update -> lock -> review.
update: update-inputs
    nix run .\#update --impure -L

# Review what `just lock` changed in lock/flake.lock (compare links per package).
# Package pins move on `just lock` (not `just update`). Order: update -> lock -> review.
# BASE defaults to HEAD: run after `just lock`, before committing.
review base="HEAD":
    emacs -Q --batch --script scripts/review-lock.el {{base}}

# Show actual .el file diffs for packages whose revisions changed.
# Fetches diffs via GitHub/GitLab API; falls back to bare git-clone for others.
# Order: update -> lock -> review -> diff-el -> commit.
diff-el base="HEAD":
    emacs -Q --batch --script scripts/diff-el.el {{base}}

# Show derivation-level diff for native deps (poppler, vterm, etc.) after `just lock`.
# Order: update -> lock -> diff-drv -> diff-el -> commit.
diff-drv base="HEAD":
    #!/usr/bin/env bash
    set -euo pipefail
    sys=$(nix eval --raw --impure --expr builtins.currentSystem)
    root=$(git rev-parse --show-toplevel)
    base_drv=$(nix eval --raw "git+file://${root}?rev=$(git rev-parse {{base}})"#packages.${sys}.default.drvPath)
    cur_drv=$(nix eval --raw --impure ".#packages.${sys}.default.drvPath")
    nix-diff "${base_drv}" "${cur_drv}"
