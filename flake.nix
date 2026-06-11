{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nix-filter.url = "github:numtide/nix-filter";

    # Emacs Twist
    # Using the personal fork's local branch (carries local fixes; master
    # there mirrors upstream emacs-twist/twist.nix).
    twist.url = "github:fenril058/twist.nix/local";
    twist-overrides.url = "github:fenril058/overrides/local"; # to build vterm
    org-babel.url = "github:fenril058/org-babel/local";

    # Package registries for Twist
    melpa = {
      url = "github:melpa/melpa";
      flake = false;
    };

    gnu-elpa = {
      url = "github:elpa-mirrors/elpa";
      flake = false;
    };

    nongnu-elpa = {
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
        devShell = pkgs.callPackage ./devShell.nix { };
      in
      {
        packages.default = package;
        apps =
          let
            descriptions = {
              lock = "Regenerate lock/flake.lock and lock/flake.nix";
              update = "Update package registry inputs and regenerate lock files";
            };
          in
          pkgs.lib.mapAttrs (
            name: app:
            app
            // {
              meta = {
                description = descriptions.${name} or "Emacs config maintenance app";
              };
            }
          ) (package.makeApps { lockDirName = "lock"; });
        formatter = formatter;
        devShells.default = devShell;
        packages.earlyInitEl = profile.earlyInitFile;
      }
    )
    // {
      inherit homeModules;
    };
}
