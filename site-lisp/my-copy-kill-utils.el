;;; my-copy-kill-utils.el  -*- lexical-binding: t; -*-

;;;###autoload
(defun copy-whole-line (&optional arg)
  "Copy current line.
With prefix ARG, Copy that many lines starting from the current line.
If ARG is negative, kill backward.  Also kill the preceding newline.
This is meant to make \\[repeat] work well with negative arguments.
If ARG is zero, kill current line but exclude the trailing newline.

Just replace `kill-region' as `copy-region-as-kill' in the
function `kill-whole-line'.

This function was originaly suggested by akisute3 and publish at
their blog `http://d.hatena.ne.jp/akisute3/20120412/1334237294'."
  (interactive "p")
  (or arg (setq arg 1))
  (if (and (> arg 0)
           (eobp)
           (save-excursion (forward-visible-line 0) (eobp)))
      (signal 'end-of-buffer nil))
  (if (and (< arg 0)
           (bobp)
           (save-excursion (end-of-visible-line) (bobp)))
      (signal 'beginning-of-buffer nil))
  (unless (eq last-command 'copy-region-as-kill)
    (kill-new "")
    (setq last-command 'copy-region-as-kill))
  (cond
   ((zerop arg)
    (save-excursion
      (copy-region-as-kill (point)
                           (progn (forward-visible-line 0) (point)))
      (copy-region-as-kill (point)
                           (progn (end-of-visible-line) (point)))))
   ((< arg 0)
    (save-excursion
      (copy-region-as-kill (point)
                           (progn (end-of-visible-line) (point)))
      (copy-region-as-kill (point)
                           (progn (forward-visible-line (1+ arg))
                                  (unless (bobp) (backward-char))
                                  (point)))))
   (t
    (save-excursion
      (copy-region-as-kill (point)
                           (progn (forward-visible-line 0) (point)))
      (copy-region-as-kill (point)
                           (progn (forward-visible-line arg) (point))))))
  (message (substring (car kill-ring-yank-pointer) 0 -1)))

;;;###autoload
(defun kill-matching-lines (regexp &optional rstart rend interactive)
  "Kill lines containing match for `REGEXP'.

Second and third arg `RSTART' and `REND' specify the region to operate on.
Lines partially contained in this region are deleted if and only if
they contain a match entirely contained in it.

Interactively, in Transient Mark mode when the mark is active, operate
on the contents of the region.  Otherwise, operate from point to the
end of (the accessible portion of) the buffer.  When calling this function
from Lisp, you can pretend that it was called interactively by passing
a non-nil `INTERACTIVE' argument.

The two pragrph above is the copy form `flush-lines'.
See `flush-lines' or `keep-lines' for behavior of this command.

If the buffer is read-only, Emacs will beep and refrain from deleting
the line, but put the line in the kill ring anyway.  This means that
you can use this command to copy text from a read-only buffer.
\(If the variable `kill-read-only-ok' is non-nil, then this won't
even beep.)

This was originally published at
`http://www.emacswiki.org/emacs-en/KillMatchingLines'"
  (interactive
   (keep-lines-read-args "Kill lines containing match for regexp"))
  (let ((buffer-file-name nil)) ;; HACK for `clone-buffer'
    (with-current-buffer (clone-buffer nil nil)
      (let ((inhibit-read-only t))
        (keep-lines regexp rstart rend interactive)
        (kill-region (or rstart (line-beginning-position))
                     (or rend (point-max))))
      (kill-buffer)))
  (unless (and buffer-read-only kill-read-only-ok)
    ;; Delete lines or make the "Buffer is read-only" error.
    (flush-lines regexp rstart rend interactive)))

(provide 'my-copy-kill-utils)
