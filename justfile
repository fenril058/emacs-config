lock:
    nix run .\#lock --impure -L

update-inputs:
    nix flake update melpa gnu-elpa nongnu-elpa epkgs

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
