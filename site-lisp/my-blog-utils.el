;;; -*- lexical-binding: t; -*-

;;;### autoload
(defvar my-blog-directory "~/Dropbox/SharedWithKT/my_site/source/blog/"
  "Source directory of my blog")

;;;### autoload
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

;;;### autoload
(defun replace-markdown-links-to-org ()
  "Replace Markdown links with Org-mode links.
If region active, do in the active region, else do in the entire buffer.
Only if the current mode is org-mode and the link is not in src block,
this function repalce the link."
  (interactive)
  (save-excursion
    (save-restriction
      (when (region-active-p)
        (narrow-to-region (region-beginning) (region-end)))
      (goto-char (point-min))
      (while (re-search-forward "\\[\\([^]]+\\)\\](\\([^)]*\\))" nil t)
        (let ((text (match-string 1))
              (url (match-string 2)))
          (unless (when (eq major-mode 'org-mode) (org-in-src-block-p))
            (replace-match (format "[[%s][%s]]" url text))))))))

;;;### autoload
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
