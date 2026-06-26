# CLAUDE.md

## Overview

Personal Emacs configuration built with [emacs-twist](https://github.com/emacs-twist/twist.nix): packages pinned via Nix, installed through home-manager, targeting WSL. `README.org` is a symlink to `init.org`.

## init.org is the source of truth

The config is literate Org. **Do not edit the tangled `.el` files** — edit `init.org` / `early-init.org` and let the Nix build tangle them (`pkgs.tangleOrgBabelFile` in `flake.nix`). Keep the `** Section` structure and the `#+begin_src emacs-lisp` / `#+end_src` fences intact — tangling depends on them.

Config uses [`setup.el`](https://codeberg.org/pkal/setup.el), not use-package/leaf: `(setup (:package foo) (:opt …) …)`. Local macros are defined under the `** Setup.el` section — read it before using one. Notable: `:package` only fake-installs (the real install is Nix/twist), and `:nixpkgs` is documentation-only metadata that does nothing at runtime.

Gotcha: `early-init.org` aliases `setopt` → `setq` until `emacs-startup-hook`, so `(setopt …)` is effectively `setq` during init. Don't put `setopt`-specific config in `early-init.org`.

## Adding / updating packages

- Add a package: add a `(setup (:package NAME) …)` block in the right `init.org` section, then `just lock`. If NAME isn't in the upstream registries, add a recipe under `recipes/<NAME>` (the local `custom` registry overrides upstream).
- `lock/` is auto-generated — never edit by hand; regenerate with `just lock`.
- Build/update commands live in the `justfile` (`just --list`). Intended refresh order: `update` → `lock` → `review` → `diff-el` → commit. Apply changes with `home-manager switch`.

## Architecture map

- `flake.nix` — homeModule + per-system packages/apps/formatter; calls `inputs.twist.lib.makeEnv`.
- `home-module.nix` — home-manager surface (`programs.emacs-twist.enable`); installs init/manifest, `snippets/`, `insert/`.
- `nix/registries.nix` / `nix/inputs.nix` / `nix/overrides.nix` — registry sources / per-package source & dep overrides / derivation-level build overrides.
- `site-lisp/` — local package `myutils`.

## Conventions

- `init.org` prose is partly Japanese — preserve the existing language when editing nearby prose.
- History is append-only: don't `git rebase -i` published history or force-push `main`.
