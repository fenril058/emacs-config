{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nix-filter.url = "github:numtide/nix-filter";

    # Emacs Twist
    twist.url = "github:emacs-twist/twist.nix";
    twist-overrides.url = "github:emacs-twist/overrides"; # to built vterm
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

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    let
      # system 非依存で公開したいものはここで定義
      homeModules = {
        twist =
          {
            ...
          }:
          {
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
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ inputs.org-babel.overlays.default ];
        };

        profile = {
          emacsPackage = pkgs.emacs-gtk;
          lockDir = ./lock;
          extraRecipeDir = ./recipes;
          extraPackages = [ "setup" ];
          initParser = inputs.twist.lib.parseSetup { inherit (inputs.nixpkgs) lib; } { }; # for setup.el
          earlyInitFile = pkgs.tangleOrgBabelFile "early-init.el" ./early-init.org { };
          initFiles = [ (pkgs.tangleOrgBabelFile "init.el" ./init.org { }) ];
        };

        package =
          (inputs.twist.lib.makeEnv {
            inherit pkgs;
            inherit (profile)
              emacsPackage
              lockDir
              initFiles
              extraPackages
              initParser
              ;
            registries = [
              {
                name = "custom";
                type = "melpa";
                path = profile.extraRecipeDir;
              } # exstraRecipeDirを優先
            ]
            ++ (import ./nix/registries.nix inputs);
            exportManifest = true;
            inputOverrides = (import ./nix/inputs.nix) // {
              myutils = _: _: {
                src = inputs.nix-filter.lib {
                  root = inputs.self;
                  include = [ "site-lisp" ];
                };
              };
            };
            localPackages = [
              "myutils"
            ];
          }).overrideScope
            (
              pkgs.lib.composeExtensions inputs.twist-overrides.overlays.twistScope (
                import ./nix/overrides.nix { inherit pkgs; }
              )
            );

        formatter = pkgs.callPackage ./formatter.nix { };
      in
      {
        packages.default = package;
        apps = package.makeApps { lockDirName = "lock"; };
        formatter = formatter;
        earlyInitEl = profile.earlyInitFile; # home-moduleから参照できるように
      }
    )
    // {
      inherit homeModules;
    };
}
