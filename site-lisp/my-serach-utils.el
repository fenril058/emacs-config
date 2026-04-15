;;; my-search-utils.el -*- lexical-binding: t; -*-

;;;###autoload
(defun consult-ripgrep-single-file ()
  "Call `consult-ripgrep' for the current buffer (a single file).

The idea is originally from <https://tam5917.hatenablog.com/entry/2022/02/11/153756>"
  (interactive)
  (unless buffer-file-name
    (user-error "This buffer is not visiting a file"))
  (let ((consult-project-function (lambda (_) nil))
        (consult-ripgrep-args
         (concat "rg "
                 "-uu "
                 "--null "
                 "--line-buffered "
                 "--color=never "
                 "--line-number "
                 "--smart-case "
                 "--no-heading "
                 "--max-columns=1000 "
                 "--max-columns-preview "
                 "--with-filename "
                 (shell-quote-argument buffer-file-name))))
    (consult-ripgrep)))

(provide 'my-search-utils)
