;;; test-markdown-org-links.el --- ERT tests for markdown->org link conversion -*- lexical-binding: t; -*-

(require 'ert)
(require 'org)     ;; org-mode, org-in-src-block-p
(require 'cl-lib)

;; --- Function under test -----------------------------------------------------
;; Markdown: [text](url)  ->  Org: [[url][text]]
;; text allows one-level nested bracket pairs like: "[[EX-956] Add init]"
;; URL is parsed naively up to ')' (common Markdown limitation).
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
      (while (re-search-forward
              ;; 1: text  2: url
              "\\[\\(\\(?:[^][]\\|\\[[^]]*\\]\\)*\\)\\](\\([^)\n]*\\))"
              nil t)
        (let ((text (match-string 1))
              (url  (match-string 2)))
          (unless (and (eq major-mode 'org-mode) (org-in-src-block-p))
            (replace-match (format "[[%s][%s]]" url text) t t)))))))

;; --- Test helpers ------------------------------------------------------------

(defmacro mdorg--with-buffer (mode content &rest body)
  "Create temp buffer, insert CONTENT, set MODE, run BODY, return buffer string."
  (declare (indent 2))
  `(with-temp-buffer
     (insert ,content)
     (goto-char (point-min))
     (,mode)
     (when (eq major-mode 'org-mode)
       (org-element-cache-reset)
       (font-lock-ensure))
     ,@body
     (buffer-string)))

(defun mdorg--activate-region (beg end)
  "Activate region from BEG to END (buffer positions)."
  (goto-char beg)
  (push-mark end t t)
  (activate-mark))

;; --- Tests -------------------------------------------------------------------

(ert-deftest replace-markdown-links-to-org/simple ()
  "Basic conversion."
  (should
   (string=
    (mdorg--with-buffer fundamental-mode
      "see [hello](https://example.com/hello) end"
      (replace-markdown-links-to-org))
    "see [[https://example.com/hello][hello]] end")))

(ert-deftest replace-markdown-links-to-org/text-contains-brackets ()
  "Link text containing [...] should be converted (one-level nested brackets).
The outer [...] are Markdown syntax and are removed; inner [...] remain as text."
  (should
   (string=
    (mdorg--with-buffer fundamental-mode
      "x [[EX-956] Add init](https://example.com/browse/EX-956) y"
      (replace-markdown-links-to-org))
    "x [[https://example.com/browse/EX-956][[EX-956] Add init]] y")))

(ert-deftest replace-markdown-links-to-org/multiple-links ()
  "Multiple links in one buffer are all converted."
  (should
   (string=
    (mdorg--with-buffer fundamental-mode
      "[a](https://example.com/a) and [b](https://example.com/b)"
      (replace-markdown-links-to-org))
    "[[https://example.com/a][a]] and [[https://example.com/b][b]]")))

(ert-deftest replace-markdown-links-to-org/region-only ()
  "When region is active, only region is converted."
  (should
   (string=
    (mdorg--with-buffer fundamental-mode
      "[x](https://example.com/x) B [y](https://example.com/y) C"
      ;; Select only the first link and trailing space before 'B'
      (mdorg--activate-region
       (point-min)
       (save-excursion (goto-char (point-min))
                       (search-forward " B")
                       (point)))
      (replace-markdown-links-to-org))
    "[[https://example.com/x][x]] B [y](https://example.com/y) C")))

(ert-deftest replace-markdown-links-to-org/skip-src-block-in-org-mode ()
  "Do not replace links inside src blocks in org-mode."
  (should
   (string=
    (mdorg--with-buffer org-mode
      (concat
       "Outside [ok](https://example.com/out)\n"
       "#+begin_src emacs-lisp\n"
       "Inside [ng](https://example.com/in)\n"
       "#+end_src\n")
      (replace-markdown-links-to-org))
    (concat
     "Outside [[https://example.com/out][ok]]\n"
     "#+begin_src emacs-lisp\n"
     "Inside [ng](https://example.com/in)\n"
     "#+end_src\n"))))

(ert-deftest replace-markdown-links-to-org/not-skip-in-non-org-mode ()
  "In non-org-mode, org src blocks are irrelevant; replacement should happen."
  (should
   (string=
    (mdorg--with-buffer fundamental-mode
      (concat
       "Outside [ok](https://example.com/out)\n"
       "#+begin_src emacs-lisp\n"
       "Inside [yes](https://example.com/in)\n"
       "#+end_src\n")
      (replace-markdown-links-to-org))
    (concat
     "Outside [[https://example.com/out][ok]]\n"
     "#+begin_src emacs-lisp\n"
     "Inside [[https://example.com/in][yes]]\n"
     "#+end_src\n"))))

(ert-deftest replace-markdown-links-to-org/no-links-no-change ()
  "If no markdown link exists, buffer should remain unchanged."
  (let ((s "no links here [ but not a link ] (nope)"))
    (should
     (string=
      (mdorg--with-buffer fundamental-mode s
        (replace-markdown-links-to-org))
      s))))

;; (ert t)
;;; test-markdown-org-links.el ends here
