{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";

    # Emacs Twist
    twist.url = "github:emacs-twist/twist.nix";
    # 
    org-babel.url = "github:emacs-twist/org-babel";

    # Package registries for Twist
    elpa = {
      url = "github:elpa-mirrors/elpa";
      flake = false;
    };

    melpa = {
      url = "github:melpa/melpa";
      flake = false;
    };

    nongnu = {
      url = "github:elpa-mirrors/nongnu";
      flake = false;
    };

    epkgs = {
      url = "github:emacsmirror/epkgs";
      flake = false;
    };

    # emacs-overlay.url = "github:nix-community/emacs-overlay";
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, ... }:
  let
    # system 非依存で公開したいものはここで定義
    homeModules = {
      twist = { config, lib, pkgs, ... }: {
        # home-module.nix が flake を使えるように渡す
        _module.args.flake = self;

        imports = [
          inputs.twist.homeModules.emacs-twist
          ./home-module.nix
        ];
      };
    };
  in
  # system 依存の packages/apps は eachDefaultSystem
  flake-utils.lib.eachDefaultSystem (system:
  let
    pkgs = import nixpkgs {
      inherit system;
      overlays = [ inputs.org-babel.overlays.default ];
    };

    profile = {
      emacsPackage = pkgs.emacs-gtk;
      lockDir = ./lock;
      extraRecipeDir = ./recipes;
      exportManifest = true;
      extraPackages = [ "setup" ];
      initParser = inputs.twist.lib.parseSetup { inherit (inputs.nixpkgs) lib; } { }; # for setup.el
      extraInputOverrides = { };
      earlyInitFile = pkgs.tangleOrgBabelFile "early-init.el" ./early-init.org { };
      initFiles = [ (pkgs.tangleOrgBabelFile "init.el" ./init.org { }) ];
    };

    package =
      (inputs.twist.lib.makeEnv {
        inherit pkgs;
        inherit (profile) emacsPackage lockDir initFiles extraPackages initParser;
        registries = [
          { name = "custom";
            type = "melpa";
            path = profile.extraRecipeDir;
          }                     # exstraRecipeDirを優先
        ] ++ (import ./nix/registries.nix inputs);
        inputOverrides = profile.extraInputOverrides;
      })
        .overrideScope (_tself: tsuper: {
          elispPackages = tsuper.elispPackages.overrideScope (_eself: esuper: {
            # helm = esuper.helm.overrideAttrs (old:
          #     let
          #       asyncLisp = "${esuper.async}/share/emacs/site-lisp";
          #     in {
          #       preBuild = (old.preBuild or "") + ''
          #   export EMACSLOADPATH="${asyncLisp}:${EMACSLOADPATH:-}"
          # '';
          #     });
            auctex = esuper.auctex.overrideAttrs (old: {
              outputs = [ "out" ];
              # buildInputs = (old.buildInputs or []) ++ [
              #   pkgs.perl
              #   pkgs.texliveMinimal
              # ];
              nativeBuildInputs = (old.nativeBuildInputs or []) ++ [
                pkgs.perl
                # pkgs.git
                pkgs.texliveSmall
              ];

              # homeless-shelter を避ける
              # doc/tex-ref.pdf など重い生成物はダミーを置いて回避
              preBuild = (old.preBuild or "") + ''
                       export HOME=$PWD/.home
                       export XDG_CONFIG_HOME=$HOME/.config
                       export XDG_CACHE_HOME=$HOME/.cache
                       export XDG_DATA_HOME=$HOME/.local/share
                       mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME"
                       mkdir -p doc
                       touch doc/tex-ref.pdf
                       '';

              # git repo でない場合は ChangeLog 生成をスキップして成功させる
              postPatch = (old.postPatch or "") + ''
                  if [ -f build-aux/gitlog-to-auctexlog ]; then
                  # ".git が無ければ exit 0" を冒頭に挿入
                  sed -i '1i\
                  if [ ! -d .git ]; then\n\
                  echo "gitlog-to-auctexlog: no .git directory; skipping" >&2\n\
                  exit 0\n\
                  fi\n' build-aux/gitlog-to-auctexlog
                  fi
                  '';
            });
          });
        });
  in {
    packages.default = package;
    apps = package.makeApps { lockDirName = "lock"; };
    earlyInitEl = profile.earlyInitFile; # home-moduleから参照できるように
  }
  )
  // { inherit homeModules; };
}
