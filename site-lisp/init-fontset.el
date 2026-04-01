;;; init-fontset.el -*- lexical-binding: t; -*-

;; Author: Shun-ichi Tahara <https://x.com/st_jado>
;; Maintainer:
;; Version: 1.0
;; Keywords:
;; Package-Requires: ((emacs "28.1"))
;; URL: https://qiita.com/jado4810/items/5dd9f1b41ea5d1a4ec74

;;; Commentary:

;; set-face-attributeでベースのフォントセットを作成し、set-fontset-fontで
;; 個別にコード範囲とフォントを追加。
;;
;; init-fontsetを呼ぶたびにデフォルトフォントセットを上書きする。
;;
;; 東アジアの文字幅を適用したい記号やギリシャ文字等については、コードポイント
;; 単位でフォントセットの設定を上書きすることができる。

;;; Test用テキスト
;;
;; 0123456789|
;; こんにちは|
;; 你好早晨①|
;; ㈱㈳㈠⑴㎢|
;; ○×■αд|
;; 㔫华𠮷啃遼|
;; 안녕하세요|
;;

;;;  設定例

;; (setq default-font-size 14)
;;
;; (setq fs:font-base     "Meslo LG S")
;; (setq fs:font-unicode  '("Meiryo"
;;                          "Noto Sans Mono CJK JP"
;;                          "Noto Sans Mono CJK SC"
;;                          "Noto Sans Mono CJK TC"
;;                          "Noto Sans Mono CJK KR"))
;; (setq fs:font-japanese "Meiryo")
;; (setq fs:font-chinese  "Noto Sans Mono CJK SC")
;; (setq fs:font-taiwan   "Noto Sans Mono CJK TC")
;; (setq fs:font-korean   "Noto Sans Mono CJK KR")
;; (setq fs:font-eaw-ovr-symbol "BIZ UDGothic")
;; (setq fs:font-eaw-ovr-cyril  "BIZ UDGothic")
;; (setq fs:font-eaw-ovr-greek  "BIZ UDGothic")
;; (setq fs:font-fw-ovr-hangul  "Malgun Gothic")
;;
;; (let* ((dpi (/ (cadddr (frame-monitor-attribute 'geometry))
;;                (/ (cadr (frame-monitor-attribute 'mm-size)) 25.4)))
;;        (rescale (cond
;;                  ((> dpi 240) 1.2) ;; Consolasの場合1.12
;;                  (t 1.24))))       ;; Consolasの場合1.18

;;   (setq face-font-rescale-alist
;;         `((".*メイリオ.*" . ,rescale)
;;           (".*Noto Sans.*" . ,rescale)
;;           (".*BIZ UD.*" . ,rescale)
;;           (".*Malgun Gothic.*" . ,rescale)
;;           )))
;; ;;; Code:

;; 初期化処理の予約

(when window-system
  (add-hook 'after-init-hook 'init-fontset))

;; 設定値

(defvar default-font-size 12
  "フォントサイズの初期値。ポイント単位で指定。")

(defvar fs:font-base
  (cond
   ((eq window-system 'x) "VL Gothic")
   ((eq window-system 'w32) "MS Gothic")
   ((memq window-system '(mac ns)) "Osaka")
   (t "Fixed"))
  "ASCIIおよびラテン文字系言語用のフォントファミリー名。リスト指定不可。
他のフォントを指定しない場合、全てこのフォントが使われる。
東アジア系言語環境では、当該言語用の等幅フォントを指定すること。")

(defvar fs:font-unicode nil
  "Unicode汎用のフォントファミリー名。
ASCIIを含めた他言語用のフォントと重複するため、必ずリストで指定すること。
リスト指定の場合、優先リストの後方にフォントを追加する。
nilの場合は無効。")

(defvar fs:font-japanese nil
  "日本語用のフォントファミリー名。指定した場合、強制的にこちらを使う。
`fs:font-chinese', `fs:font-taiwan', `fs:font-korean'と重複するコードポイントではこちらを優先する。
nilの場合は無効。
かなの文字幅が狭い場合や、かなのみ別フォントを使いたい場合は、`fs:font-fw-ovr-kana'も指定するとよい。")

(defvar fs:font-chinese nil
  "中国語(簡体字)用のフォントファミリー名。指定した場合、強制的にこちらを使う。
`fs:font-korean'と重複するコードポイントではこちらを優先する。
nilの場合は無効。")

(defvar fs:font-taiwan nil
  "中国語(繁体字)用のフォントファミリー名。指定した場合、強制的にこちらを使う。
`fs:font-chinese', `fs:font-korean'と重複するコードポイントではこちらを優先する。
nilの場合は無効。")

(defvar fs:font-korean nil
  "韓国語用のフォントファミリー名。指定した場合、強制的にこちらを使う。
nilの場合は無効。
ハングルの文字幅が狭い場合や、ハングルのみ別フォントを使いたい場合は、`fs:font-fw-ovr-hangul'も指定するとよい。")

(defvar fs:font-cyrillic nil
  "キリル文字用のフォントファミリー名。指定した場合、強制的にこちらを使う。
nilの場合は無効。
東アジア言語環境では当該言語用フォントや`fs:font-eaw-cyrillic'で指定すること。")

(defvar fs:font-arabic nil
  "アラビア文字用のフォントファミリー名。指定した場合、強制的にこちらを使う。
nilの場合は無効。")

(defvar fs:font-greek nil
  "ギリシア文字用のフォントファミリー名。指定した場合、強制的にこちらを使う。
nilの場合は無効。
東アジア言語環境では当該言語用フォントや`fs:font-eaw-cyrillic'で指定すること。")

(defvar fs:font-hebrew nil
  "ヘブライ文字用のフォントファミリー名。指定した場合、強制的にこちらを使う。
nilの場合は無効。")

(defvar fs:font-thai nil
  "タイ文字用のフォントファミリー名。指定した場合、強制的にこちらを使う。
nilの場合は無効。")

(defvar fs:font-viet nil
  "ベトナム文字用のフォントファミリー名。指定した場合、強制的にこちらを使う。
nilの場合は無効。")

(defvar fs:font-eaw-ovr-symbol nil
  "東アジアの文字幅が適用される文字のうち、記号向けにフォント設定を上書きする場合に指定。
nilの場合は無効。")

(defvar fs:font-eaw-ovr-cyril nil
  "東アジアの文字幅が適用される文字のうち、キリル文字向けにフォント設定を上書きする場合に指定。
nilの場合は無効。")

(defvar fs:font-eaw-ovr-greek nil
  "東アジアの文字幅が適用される文字のうち、ギリシャ文字向けにフォント設定を上書きする場合に指定。
nilの場合は無効。")

(defvar fs:font-fw-ovr-kana nil
  "文字幅がFWである文字のうち、かな文字向けにフォント設定を上書きする場合に指定。
`fs:font-japanese'に、かなの文字幅が狭い日本語フォントを指定した場合や、かなのみ別フォントを使いたい場合に有効。
nilの場合は無効。")

(defvar fs:font-fw-ovr-hangul nil
  "文字幅がFWである文字のうち、ハングル文字向けにフォント設定を上書きする場合に指定。
`fs:font-korean'に、ハングルの文字幅が狭い韓国語フォントを指定した場合や、ハングルのみ別フォントを使いたい場合に有効。
nilの場合は無効。")

;; Symbol系でASCII用フォントを強制的に使うモードを解除(Emacs25 or later)

(setq use-default-font-for-symbols nil)

;; 各種定数

(defconst fontset-override-char-alist
  '((eaw-ovr-symbol
     . (#xa2 #xa3 #xa7 #xa8 #xac #xb0 #xb1 #xb4 #xb6 #xd7 #xf7
        #x2010 #x2015 #x2016 #x2018 #x2019 #x201c #x201d
        #x2020 #x2021 #x2025 #x2026 #x2030 #x2032 #x2033 #x203b
        #x2103 #x212b (#x2190 . #x2193) #x21d2 #x21d4
        #x2200 #x2202 #x2203 #x2207 #x2208 #x220b #x2212 #x221a #x221d #x221e
        #x2220 #x2225 (#x2227 . #x222c) #x2234 #x2235 #x223d #x2252
        #x2260 #x2261 #x2266 #x2267 #x226a #x226b
        #x2282 #x2283 #x2286 #x2287 #x22a5 #x2312))
    (eaw-ovr-cyril
     . (#x401 (#x410 . #x44f) #x451))
    (eaw-ovr-greek
     . ((#x391 . #x3a9) (#x3b1 . #x3c9)))
    (fw-ovr-kana
     . ((#x3041 . #x3096) (#x3099 . #x30ff)))
    (fw-ovr-hangul
     . ((#xac00 . #xd7a3)))
    )
  "コードポイント指定でフォントを上書きするリスト。")

(defun get-fontset-font-alist ()
  "`init-fontset'がフォントセットを設定する際に指定する、文字セットとフォントファミリーのalistを返す。"
  `((unicode                  . ,fs:font-unicode)
    (korean-ksc5601           . ,fs:font-korean)
    (chinese-cns11643-1       . ,fs:font-chinese)
    (chinese-cns11643-2       . ,fs:font-chinese)
    (chinese-cns11643-3       . ,fs:font-chinese)
    (chinese-cns11643-4       . ,fs:font-chinese)
    (chinese-cns11643-5       . ,fs:font-chinese)
    (chinese-cns11643-6       . ,fs:font-chinese)
    (chinese-cns11643-7       . ,fs:font-chinese)
    (chinese-cns11643-15      . ,fs:font-chinese)
    (chinese-gbk              . ,fs:font-chinese)
    (chinese-gb2312           . ,fs:font-chinese)
    (big5                     . ,fs:font-taiwan)
    (big5-hkscs               . ,fs:font-taiwan)
    (katakana-jisx0201        . ,fs:font-japanese)
    (japanese-jisx0208        . ,fs:font-japanese)
    (japanese-jisx0212        . ,fs:font-japanese)
    (japanese-jisx0213-2      . ,fs:font-japanese)
    (japanese-jisx0213.2004-1 . ,fs:font-japanese)
    (cp932                    . ,fs:font-japanese)
    (latin-iso8859-1          . ,fs:font-base)
    (latin-iso8859-2          . ,fs:font-base)
    (latin-iso8859-3          . ,fs:font-base)
    (latin-iso8859-4          . ,fs:font-base)
    (latin-iso8859-9          . ,fs:font-base)
    (latin-iso8859-10         . ,fs:font-base)
    (latin-iso8859-13         . ,fs:font-base)
    (latin-iso8859-14         . ,fs:font-base)
    (latin-iso8859-15         . ,fs:font-base)
    (latin-iso8859-16         . ,fs:font-base)
    (cyrillic-iso8859-5       . ,fs:font-cyrillic)
    (arabic-iso8859-6         . ,fs:font-arabic)
    (greek-iso8859-7          . ,fs:font-greek)
    (hebrew-iso8859-8         . ,fs:font-hebrew)
    (thai-tis620              . ,fs:font-thai)
    (viscii                   . ,fs:font-viet)
    (vscii                    . ,fs:font-viet)
    (vscii-2                  . ,fs:font-viet)
    (eaw-ovr-symbol           . ,fs:font-eaw-ovr-symbol)
    (eaw-ovr-cyril            . ,fs:font-eaw-ovr-cyril)
    (eaw-ovr-greek            . ,fs:font-eaw-ovr-greek)
    (fw-ovr-kana              . ,fs:font-fw-ovr-kana)
    (fw-ovr-hangul            . ,fs:font-fw-ovr-hangul)
    ))

;; 初期化処理

(defun init-fontset (&optional size frame)
  "指定したポイントサイズで、フォントセット \"default\" を初期化する。
SIZE省略時は `default-font-size` を用いる。
FRAME省略時は全てのフレームを対象とする。"
  (interactive (list (read-number "Font size: " default-font-size)
                     (selected-frame)))
  (let* ((sz (if (and (numberp size) (> size 0)) size default-font-size))
         ;; 指定されたサイズをポイントサイズとして扱うため実数化する
         (pt (* sz 1.0))
         (height (round (* sz 10)))
         )
    ;; default faceのプロパティでフォントを設定することで、新規フレームに対応
    ;; (default-frame-alistを用いても、フレーム生成時にascii-fontのみのフォント
    ;;  セットが動的に生成されてしまうため)
    (set-face-attribute 'default frame :family fs:font-base :height height)

    ;; デフォルトフォントセットを上書き
    ;; (フォントセットを作成してset-frame-fontを行うと、ascii-fontのみのフォント
    ;;  セットが動的に生成されてしまうため)
    (mapc
     (lambda (entry)
       (let* ((target (car entry))
              (family (cdr entry))
              (f (lambda (fml add)
                   (let ((spec (font-spec :family fml :size pt))
                         (ovr (assoc target fontset-override-char-alist)))
                     (if ovr
                         (mapc
                          (lambda (ch) (set-fontset-font nil ch spec frame add))
                          (cdr ovr))
                       (set-fontset-font nil target spec frame add))
                    )))
             )
         (cond
          ((not family)
           nil)
          ((listp family)
           (mapc (lambda (fml) (funcall f fml 'append)) family))
          (t
           (funcall f family nil)))
         ))
     (get-fontset-font-alist))
    nil))

;;;

(provide 'init-fontset)

;; init-fontset.el ends here
