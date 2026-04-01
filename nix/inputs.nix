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
