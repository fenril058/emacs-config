;;; my-zenn-utils.el -*- lexical-binding: t; -*-

;; The concept is from <https://zenn.dev/megeton/articles/66b3769294b04b>

(require 'transient)
(require 'consult)

;; https://github.com/fenril058/zenn-content
(defvar my-zenn-dir "~/ghq/github.com/fenril058/zenn-content/"
  "zenn-content directory")

;;;###autoload
(transient-define-suffix my-zenn-article-new (slug)
  :key "n"
  :description "新規記事"
  (interactive "sWrite Slug: ")
  (let ((slug (if (string-match "\\w+" slug)
                  slug
                ;; 空白以外何も入力がなければ14桁の16進文字列をslugとして生成
                (substring
                 (md5 (format "%s%s%s"
                              (random)
                              (current-time)
                              (user-uid)))
                 0 14))))

    (let ((default-directory my-zenn-dir)
          (output-buffer "*Zenn Output*")
          exit-status)
      (with-temp-buffer
        (setq exit-status
              ;;  第3引数を `'(t t)` にすることで、標準出力と標準エラー出力を両方回収する
              (call-process "direnv" nil '(t t) nil "exec" "." "zenn" "new:article" "--slug" slug))
        (ansi-color-filter-region (point-min) (point-max))
        (let ((output (buffer-string))
              (line-count (count-lines (point-min) (point-max))))
          (cond
           ;; コマンドが失敗した場合
           ((not (eq exit-status 0))
            (let ((buf (get-buffer-create output-buffer)))
              (with-current-buffer buf
                (let ((inhibit-read-only t))
                  (erase-buffer)
                  (insert (format "Command failed with status %s\n" exit-status))
                  (insert "---------------------------------------\n")
                  (insert output)))
              (display-buffer buf)
              (error "Failed to create Zenn article. Check %s for details." output-buffer)))
           ;;  正常終了したが、出力が2行以上の場合
           ((> line-count 1)
            (let ((buf (get-buffer-create output-buffer)))
              (with-current-buffer buf
                (let ((inhibit-read-only t))
                  (erase-buffer)
                  (insert output)))
              (display-buffer buf)))
           ;; 正常終了かつ出力が1行以内場合
           (t
            (message "%s" (string-trim output)))))))
    (find-file (format "%sarticles/%s.md" my-zenn-dir slug))
    (goto-char (point-max))))

;;;###autoload
(transient-define-suffix my-zenn-search ()
  :key "s"
  :description "題名検索"
  (interactive)
  (let ((max-mini-window-height 0.5)
        (vertico-count 50))
    (consult-ripgrep my-zenn-dir "^title: ")))

;;;###autoload
(transient-define-suffix my-zenn-dired ()
  :key "d"
  :description "Open by dired"
  (interactive)
  (dired my-zenn-dir))

;;;###autoload
(transient-define-suffix my-zenn-current-open ()
  :key "o"
  :description (lambda ()
                 (let ((dir (and buffer-file-name (file-name-directory buffer-file-name)))
                       (zenn-dir (expand-file-name my-zenn-dir)))
                   (if (and dir (string-prefix-p zenn-dir dir))
                       "View on zenn.dev"
                     ;; ディレクトリ外ならプロパティで色を変えて警告（警告用に transient-warning を使用）
                     (propertize "View on zenn.dev (Not in Zenn dir)" 'face 'warning))))
  (interactive)
  (if (and buffer-file-name
           (string-prefix-p (expand-file-name my-zenn-dir) (file-name-directory buffer-file-name)))
      (let* ((stem (file-name-sans-extension (file-name-nondirectory buffer-file-name)))
             (url (format "https://zenn.dev/ril/articles/%s" stem)))
        (browse-url url))
    (user-error "Not in zenn-content directory.")))

;;;###autoload
(transient-define-suffix my-zenn-current-preview ()
  :key "p"
  :description (lambda ()
                 (let ((dir (and buffer-file-name (file-name-directory buffer-file-name)))
                       (zenn-dir (expand-file-name my-zenn-dir)))
                   (if (and dir (string-prefix-p zenn-dir dir))
                       "Preview"
                     ;; ディレクトリ外ならプロパティで色を変えて警告（警告用に transient-warning を使用）
                     (propertize "Preview (Not in Zenn dir)" 'face 'warning))))
  (interactive)
  (if (and buffer-file-name
           (string-prefix-p (expand-file-name my-zenn-dir) (file-name-directory buffer-file-name)))
      (let* ((stem (file-name-sans-extension (file-name-nondirectory buffer-file-name)))
             (url (format "http://localhost:8001/articles/%s" stem)))
        (browse-url url))
    (user-error "Not in zenn-content directory.")))

;;;###autoload
(transient-define-suffix my-zenn-preview-start ()
  :key "1"
  :description "プレビュー起動"
  (interactive)
  (if (process-status "zenn")
      (message "Zenn Preview already started.")
      (start-process-shell-command "zenn" "*Zenn*"
                                   (format "cd %s && direnv exec . zenn preview -p 8001" my-zenn-dir))
    (message "👀 Preview: http://localhost:8001")))

(transient-define-suffix my-zenn-preview-stop ()
  :key "0"
  :description "プレビュー停止"
  (interactive)
  (if (not (process-status "zenn"))
      (message "Zenn Preview not started.")
    (delete-process "zenn")
    (message "Zenn Preview terminated.")))

;;;###autoload
(transient-define-prefix my-zenn-menu ()
  "Zenn"
  [["Basic"
    (my-zenn-article-new)
    (my-zenn-search)
    (my-zenn-dired)
    ]
   ["Preview"
    (my-zenn-current-preview)
    (my-zenn-current-open)
    ]
   ["Other"
    (my-zenn-preview-start)
    (my-zenn-preview-stop)
    ]])

(provide 'my-zenn-utils)
;;; my-zenn-utils.el ends here
