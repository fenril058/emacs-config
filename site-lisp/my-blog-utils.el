;;; my-blog-utils.el -*- lexical-binding: t; -*-

(require 'transient)
(require 'consult)

(defvar my-blog-directory "~/Dropbox/SharedWithKT/my_site/source/blog/"
  "Source directory of my blog")

(defvar my-blog-url "https://chisono.web.fc2.com/blog/"
  "URL of my blog")

;;;###autoload
(transient-define-suffix my-blog-new (title)
  :key "n"
  :description "作成"
  (interactive "sWrite article title: ")
  (create-blog-article title))

;;;###autoload
(transient-define-suffix my-blog-search-this-year ()
  :key "s"
  :description "タイトル検索（今年のみ）"
  (interactive)
  (let ((max-mini-window-height 0.5)
        (vertico-count 50))
    (consult-ripgrep (concat my-blog-directory (format-time-string "%Y")) "^#\\+TITLE:")))

;;;###autoload
(transient-define-suffix my-blog-search ()
  :key "S"
  :description "タイトル検索"
  (interactive)
  (let ((max-mini-window-height 0.5)
        (vertico-count 50)
        (vertico-grid-mode t))
    (consult-ripgrep my-blog-directory "^#\\+TITLE:")))

;;;###autoload
(transient-define-suffix my-blog-dired ()
  :key "d"
  :description "Dired"
  (interactive)
  (dired (concat my-blog-directory (format-time-string "%Y"))))

;;;###autoload
(transient-define-suffix my-blog-git-save ()
  :key "u"
  :description "Save & Push"
  (interactive)
  (async-shell-command (format "cd %s && git add -A; git now; git push" my-blog-directory)))

;;;###autoload
(transient-define-suffix my-blog-current-open ()
  :key "o"
  :description "サイトを開く"
  (interactive)
  (let ((open-cmd (if is-wsl "wslstart" "open")))
    (shell-command (format "%s %s" open-cmd my-blog-url))))

;;;###autoload
(transient-define-prefix my-blog-menu ()
  "Blog"
  [["Basic"
    (my-blog-new)
    (my-blog-dired)
    ]
   ["操作"
    (my-blog-git-save)
    (my-blog-current-open)
    ]
   ["Search"
    (my-blog-search-this-year)
    (my-blog-search)
    ]])

;;;###autoload
(defun create-blog-article (title)
  "Blog記事を生成する。"
  (interactive "sWrite article title: ")
  (let ((ct (current-time)))
    (find-file (concat my-blog-directory
                       (format-time-string "%Y/" ct)
                       (format-time-string "%Y%m%dT%H%M%S" ct)
                       ".org"))
    (insert (concat "#+TITLE:"
                    title
                    "
#+DATE: "
                    (format-time-string "[%Y-%m-%d %a %H:%M]" ct)
                    "
#+LANGUAGE: ja
#+OPTIONS: \\n:nil ^:{}
#+TAGS: 07thExpansion(0) aikido(a)
#+TAGS: book movie papers
#+TAGS: economy law politics philosophy
#+TAGS: science physics(p) sleep
#+TAGS: emacs(e) css llm
#+TAGS: misc(m) diary(d) news(n)
#+LINK: github https://github.com/
#+LINK: twitter https://twitter.com/

* {{{title}}} {{{date}}}
"
                    ))
    (org-mode-restart)))

;;;###autoload
(defun replace-markdown-links-to-org ()
  "Replace Markdown links [text](url) with Org-mode links [[url][text]].
If region is active, operate on the region; otherwise, on the whole buffer.
If the current mode is org-mode, do not touch links inside src blocks."
  (interactive)
  (save-excursion
    (save-restriction
      (when (region-active-p)
        (narrow-to-region (region-beginning) (region-end)))
      (goto-char (point-min))
      ;; Markdown: [text](url)
      ;; text may contain one-level nested brackets like: [[TITAN-956] ...]
      (while (re-search-forward
              "\\[\\(\\(?:[^][]\\|\\[[^]]*\\]\\)*\\)\\](\\([^)\n]*\\))"
              nil t)
        (let ((text (match-string 1))
              (url  (match-string 2)))
          (unless (and (eq major-mode 'org-mode) (org-in-src-block-p))
            (replace-match (format "[[%s][%s]]" url text) t t)))))))

;;;###autoload
(defun format-elfeed-header-for-blog ()
  "Format elfeed's header for my blog."
  (interactive)
  (save-excursion
    (save-restriction
      (when (region-active-p)
        (narrow-to-region (region-beginning) (region-end)))
      (goto-char (point-min))
      (while (re-search-forward "^\\(Author\\|Date\\|Feed\\|Link\\): " nil t)
        (let ((header (match-string 1)))
          (replace-match (format "- %s: " header))))
      (goto-char (point-min))
      (while (re-search-forward "^\\(Title\\): " nil t)
        (let ((header (match-string 1)))
          (replace-match (format "*** %s: " header))))
      )))

(provide 'my-blog-utils)
;;; my-blog-utils.el ends here
