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
  (let ((slug (unless slug
                ;; 何も入力がなければ14桁の16進文字列をslugとして生成
                (substring
                 (md5 (format "%s%s%s"
                              (random)
                              (current-time)
                              (user-uid)))
                 0 14))))
    (shell-command (format "cd %s && zenn new:article --slug %s" my-zenn-dir slug))
    (find-file (format "%sarticles/%s.md" my-zenn-dir slug))
    (goto-char (point-max))))

;;;###autoload
(transient-define-suffix my-zenn-search ()
  :key "s"
  :description "題名検索"
  (interactive)
  (consult-ripgrep my-zenn-dir "^title: "))

;;;###autoload
(transient-define-suffix my-zenn-dired ()
  :key "d"
  :description "Open by dired"
  (interactive)
  (dired my-zenn-dir))

;;;###autoload
(transient-define-suffix my-zenn-current-open ()
  :key "o"
  :description "zenn.devで開く"
  (interactive)
  (when buffer-file-name
    (let* ((dir (file-name-directory buffer-file-name))
           (stem (file-name-sans-extension
                  (file-name-nondirectory buffer-file-name)))
           (url (format "https://zenn.dev/ril/articles/%s" stem))
           (open-cmd (if is-wsl "wslstart" "open")))
      (if (string= dir my-zenn-dir)
          (shell-command (format "%s %s" open-cmd url))
        (message "Not in zenn-content directory.")))))

;;;###autoload
(transient-define-suffix my-zenn-current-preview ()
  :key "p"
  :description "Preview"
  (interactive)
  (when buffer-file-name
    (let* ((dir (file-name-directory buffer-file-name))
           (stem (file-name-sans-extension
                  (file-name-nondirectory buffer-file-name)))
           (url (format "http://localhost:8001/articles/%s" stem))
           (open-cmd (if is-wsl "wslstart" "open")))
      (my-zenn-preview-start)
      (if (string= dir my-zenn-dir)
          (shell-command (format "%s %s" open-cmd url))
        (message "Not in zenn-content directory.")))))

;;;###autoload
(transient-define-suffix my-zenn-preview-start ()
  :key "1"
  :description "プレビュー起動"
  (interactive)
  (when (not (process-status "zenn"))
    (start-process-shell-command "zenn" "*Zenn*"
                                 (format "direnv exec %s zenn preview -p 8001" my-zenn-dir))))

(transient-define-suffix my-zenn-preview-stop ()
  :key "0"
  :description "プレビュー停止"
  (interactive)
  (when (process-status "zenn")
    (delete-process "zenn")))

(transient-define-suffix my-zenn-upload ()
  :key "u"
  :description "git save and push"
  (interactive)
  (async-shell-command
   (format "cd %s && git add -A; git save; git push" my-zenn-dir)))

(transient-define-suffix my-zenn-install ()
  :key "i"
  :description "パッケージ更新"
  (interactive)
  (async-shell-command (format "cd %s && just update" my-zenn-dir)))

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
    (my-zenn-upload)
    (my-zenn-current-open)
    ]
   ["Other"
    (my-zenn-preview-start)
    (my-zenn-preview-stop)
    (my-zenn-install)
    ]])

(provide 'my-zenn-utils)
;;; my-zenn-utils.el ends here
