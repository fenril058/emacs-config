{
  org = _: _: {
    origin = {
      # git.savannah.org is unstable
      type = "github";
      owner = "elpa-mirrors";
      repo = "org-mode";
      ref = "bugfix";
    };
  };

  auctex = _: _: {
    origin = {
      # git.savannah.gnu.org is unstable
      type = "github";
      owner = "emacsmirror";
      repo = "auctex";
    };
  };

  repl-toggle = _: _: {
    origin = {
      type = "github";
      owner = "emacsmirror";
      repo = "repl-toggle";
    };
  };

  # codeberg.org is unstable in CI; these emacsmirror mirrors track upstream
  # and (as of this change) their default branch points at the same revision.
  undo-fu = _: _: {
    origin = {
      type = "github";
      owner = "emacsmirror";
      repo = "undo-fu";
    };
  };

  setup = _: _: {
    origin = {
      type = "github";
      owner = "emacsmirror";
      repo = "setup";
    };
  };

  gdb-x = _: _: {
    origin = {
      type = "github";
      owner = "emacsmirror";
      repo = "gdb-x";
    };
  };

  haskell-ts-mode = _: _: {
    origin = {
      type = "github";
      owner = "emacsmirror";
      repo = "haskell-ts-mode";
    };
  };

  # akib's packages live only on codeberg and have no usable emacsmirror mirror,
  # so we self-host a mirror under fenril058/*. The `master` branch of each
  # mirror tracks upstream verbatim (force-synced from codeberg by a workflow on
  # the repo's default `mirror` branch); track that `master` here.
  eat = _: _: {
    origin = {
      type = "github";
      owner = "fenril058";
      repo = "emacs-eat";
      ref = "master";
    };
  };

  corfu-terminal = _: _: {
    origin = {
      type = "github";
      owner = "fenril058";
      repo = "emacs-corfu-terminal";
      ref = "master";
    };
  };

  popon = _: _: {
    origin = {
      type = "github";
      owner = "fenril058";
      repo = "emacs-popon";
      ref = "master";
    };
  };

  async = _: super: {
    files = builtins.removeAttrs super.files [
      "tests/test-async.el"
      "async-test.el"
    ];
  };

  lispy = _: super: {
    origin = {
      type = "github";
      owner = "fenril058";
      repo = "lispy";
      ref = "master";
    };
    files = builtins.removeAttrs super.files [
      # le-js depends on indium, which I don't want to install.
      "le-js.el"
      # lispy-occur depends on swiper
      "lispy-occur.el"
    ];
    packageRequires =
      (builtins.removeAttrs super.packageRequires [
        "swiper"
        "ace-window"
      ])
      // {
        avy = "0";
      };
  };
}
