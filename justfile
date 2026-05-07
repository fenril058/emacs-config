lock:
    nix run .\#lock --impure -L

update-inputs:
    nix flake update melpa gnu-elpa nongnu-elpa epkgs

update: update-inputs
    nix run .\#update --impure -L
