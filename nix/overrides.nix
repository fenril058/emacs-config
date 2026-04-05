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
    }
  );
}
