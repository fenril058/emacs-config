lock:
    nix run .\#lock --impure -L

update-inputs:
    nix flake update melpa elpa nongnu

update: update-inputs
    nix run .\#update --impure -L
