;;; my-blog-utils.el -*- lexical-binding: t; -*-

(defcustom my-blog-directory "~/Dropbox/SharedWithKT/my_site/source/blog/"
  "Source directory of my blog")

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
