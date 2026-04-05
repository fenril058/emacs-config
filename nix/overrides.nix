{ pkgs }:

_tself: tsuper: {
  elispPackages = tsuper.elispPackages.overrideScope (
    _eself: esuper: {
      auctex = esuper.auctex.overrideAttrs (old: {
        outputs = [ "out" ];
        # buildInputs = (old.buildInputs or []) ++ [
        #   pkgs.perl
        #   pkgs.texliveMinimal
        # ];
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
          pkgs.perl
          pkgs.texliveSmall
        ];

        # GNUmakefileを書き換えてChangeLogの生成を避ける
        postPatch = (old.postPatch or "") + ''
          sed -i '/^ChangeLog:/,/^[^[:space:]]/c\
          ChangeLog:\n\
          \ttouch $@\n' GNUmakefile
        '';
        # homeless-shelter を避ける
        preBuild = (old.preBuild or "") + ''
          export HOME=$PWD/.home
          export XDG_CONFIG_HOME=$HOME/.config
          export XDG_CACHE_HOME=$HOME/.cache
          export XDG_DATA_HOME=$HOME/.local/share
          mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME"
        '';

        # infoまで必要ならallにしないとだめ。必要ないなら make elpaでOK
        buildPhase = (old.buildPhase or "") + ''
          make all
        '';

        # infoは手動で移動しないとだめ
        installPhase = (old.installPhase or "") + ''
          mkdir -p $out/share/info
          if [ -d doc ]; then
              cp doc/*.info $out/share/info/ || true
          fi
          install-info $out/share/info/auctex.info $out/share/info/dir || true
          install-info $out/share/info/preview-latex.info $out/share/info/dir || true
        '';
      });
    }
  );
}
