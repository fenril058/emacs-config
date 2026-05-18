# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A personal Emacs configuration built with [emacs-twist](https://github.com/emacs-twist/twist.nix). Packages are pinned via Nix and the configuration is installed through home-manager. Target platform is WSL (Windows Subsystem for Linux).

`README.org` is a symlink to `init.org`.

## Literate configuration: init.org is the source of truth

The Emacs configuration is written as literate Org files. **Do not edit the tangled `.el` files** — edit the Org sources and let the Nix build tangle them.

- `init.org` → tangled to `init.el` at build time via `pkgs.tangleOrgBabelFile` (see `flake.nix`).
- `early-init.org` → tangled to `early-init.el`.
- The parser used is `inputs.twist.lib.parseSetup` because configuration uses `setup.el` blocks (not `use-package`).

When you need to add or change Emacs behavior, find the relevant `** Section` in `init.org` and edit the `#+begin_src emacs-lisp ... #+end_src` block there.

## Build / update commands

The justfile wraps the common Nix invocations:

- `just lock` — regenerate `lock/flake.lock` and `lock/flake.nix` (the auto-generated package lock; never edit `lock/` by hand). Equivalent to `nix run .#lock --impure -L`.
- `just update-inputs` — `nix flake update melpa gnu-elpa nongnu-elpa epkgs` (refresh the package registries).
- `just update` — runs `update-inputs` then `nix run .#update --impure -L` to refresh package metadata.
- `nix flake show --all-systems` — list flake outputs (`packages`, `apps`, `formatter`, etc.).
- `nix fmt` — format Nix files. Uses `treefmt` with `nixfmt`, configured in `treefmt.toml` (excludes `lock/**`).
- `home-manager switch` — apply the configuration after pulling new commits / updating inputs.

`--impure` is required for the `lock` and `update` apps because they read from the working tree.

## Architecture

### Nix layer

- `flake.nix` — defines `homeModules.twist` (system-independent) and per-system `packages.default`, `apps`, `formatter`, plus `earlyInitEl`. The build calls `inputs.twist.lib.makeEnv` to produce a package set composed of `init.org`'s declared packages.
- `home-module.nix` — the home-manager module surface (`programs.emacs-twist.enable`). Wires `emacsclient`, the init/manifest files, an XDG desktop entry, and copies `snippets/` and `insert/` into `~/.config/emacs/`.
- `nix/registries.nix` — package sources (MELPA, GNU/NonGNU ELPA, devel archives, emacsmirror). A `custom` registry pointing to `./recipes` is prepended in `flake.nix` so local recipes override upstream.
- `nix/inputs.nix` — per-package source/file/dependency overrides (e.g., pin `org` to `elpa-mirrors/org-mode#bugfix`, fork of `lispy`, strip `swiper`/`ace-window` deps).
- `nix/overrides.nix` — derivation-level overrides for packages needing a special build (currently `auctex` and `pdf-tools`).
- `lock/` — auto-generated lock data. Do not edit; regenerate with `just lock`.

### Emacs configuration layer (`init.org`)

- Uses [`setup.el`](https://codeberg.org/pkal/setup.el), not `use-package` or `leaf.el`. Per-package config looks like `(setup (:package foo) (:opt …) (:global-keymap …))`.
- Custom `setup.el` local macros are defined under the `** Setup.el` section. Common ones:
  - `:package` — fake-installs a package (real installation is done by Nix/twist, not Emacs).
  - `:opt` — wraps `setopt` (deferred until after load).
  - `:nixpkgs` — declarative marker: "this Emacs package expects these Nix executables on PATH." Does nothing at runtime; intended as documentation/metadata. Reference these when adding native dependencies.
  - `:global-keymap` / `:keymap` / `:keymap-unset` / `:override-map` — keybinding helpers.
  - `:defer` — `(run-with-timer SEC nil FN)` from `after-init-hook` for pseudo-async loading.
  - `:key-chord`, `:blackout`, `:reformatter`, `:mode-repl`, `:mode-remap`, `:foreach`, `:auto-insert` — see the `** Setup.el` subsections.
- `early-init.org` aliases `setopt` → `setq` for the duration of init (faster) and restores the real `setopt` from `emacs-startup-hook`. Keep this in mind when reading config: `(setopt …)` in `init.org` is effectively `setq` until startup completes.
- Adding a package: pick the relevant section in `init.org`, add a `(setup (:package NAME) …)` block, then `just lock` to refresh `lock/flake.lock` so Nix can fetch it. If the package name is not in the upstream registries, add a recipe under `recipes/<NAME>`.

### Local Emacs code

- `site-lisp/` — Emacs Lisp utility code bundled as the local package `myutils` (declared in `flake.nix` under `localPackages`, scoped by `inputs.nix-filter` to the `site-lisp` directory). The recipe in `recipes/myutils` excludes `*-test.el`.
- `recipes/` — MELPA-style recipe files for packages not on a registry, or to override upstream recipes (the `custom` registry is first in the registry list).
- `snippets/` — yasnippet snippets, installed to `~/.config/emacs/snippets` by `home-module.nix`.
- `insert/` — auto-insert templates, installed to `~/.config/emacs/insert`.

### First-run interactive commands

After installing for the first time, the user must run inside Emacs (noted in `init.org` Introduction):

- `M-x treesit-auto-install-all`
- `M-x nerd-icons-install-fonts`
- `M-x eat-compile-terminfo`

## Conventions

- Configuration text and prose in `init.org` is partly Japanese; preserve the existing language when editing nearby prose.
- When editing `init.org`, keep section structure (`** Section / *** Subsection`) and the `#+begin_src emacs-lisp` / `#+end_src` fences intact — tangling depends on them.
- Don't add `(setopt …)` to `early-init.org` expecting `setopt`-specific behavior during init; it's aliased to `setq` until startup completes (see `early-init.org`).
- The repo history is occasionally rewritten with `git rebase -i`; the README tells consumers to `git reset --hard origin/main` after fetches. Avoid amending commits silently when collaborating.
