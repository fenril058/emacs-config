# show recipe list
_:
    @just --list

# Kept out of `nix fmt` so a dead link or network blip never blocks commits.
# Check external links in init.org with lychee (on demand; not run by hooks/CI).
check-links:
    lychee --no-progress --config ./lychee.toml init.org

# Sync lock/flake.nix and lock/archive.lock with the current package set in
# init.org, then run `nix flake lock` to add/remove entries in lock/flake.lock.
# Does NOT update locked SHAs of existing git packages — use update-lock for that.
# Typical order: update-registries -> lock -> update-archive / update-lock -> diff-*
lock:
    nix run .\#lock --impure -L

# Update locked SHAs of git packages (MELPA/ELPA) in lock/flake.lock.
# No args: update all. With args: update specific packages only.
# Run after `just lock`. e.g. just update-lock evil magit
update-lock *pkgs:
    cd lock && nix flake update {{pkgs}}

# Update registry inputs (melpa, gnu-elpa, nongnu-elpa, epkgs) in flake.lock.
# Run before `just lock` when you want the latest registry metadata.
update-registries:
    nix flake update melpa gnu-elpa nongnu-elpa epkgs

# Fetch latest versions from ELPA archives and write to lock/archive.lock.
# Run after `just lock`. Run `just update-registries` separately beforehand if needed.
update-archive:
    nix run .\#update --impure -L

# Show per-package compare links for changes in lock/flake.lock.
# Run after `just lock` or `just update-lock`, before committing.
diff-lock base="HEAD":
    emacs -Q --batch --script scripts/diff-lock.el {{base}}

# Show .el diffs for packages whose revisions changed in lock/flake.lock.
# Fetches diffs in parallel via GitHub/GitLab API; falls back to bare git-clone.
# viewer=terminal (default): syntax-highlighted output in terminal via bat.
# viewer=emacs: write Markdown to a temp file and open with emacsclient.
# Run after `just diff-lock`, before committing.
diff-el base="HEAD" viewer="terminal":
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{viewer}}" in
      emacs)
        outfile=$(mktemp --suffix=.md /tmp/diff-el-XXXXXX)
        bash scripts/diff-el.sh {{base}} md > "$outfile"
        printf '→ %s\n' "$outfile"
        emacsclient -n "$outfile"
        ;;
      *)
        if command -v bat >/dev/null 2>&1; then
          bash scripts/diff-el.sh {{base}} raw | bat --language=diff --paging=always
        else
          bash scripts/diff-el.sh {{base}} raw | less -R
        fi
        ;;
    esac

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
