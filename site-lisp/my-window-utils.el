;;; -*- lexical-binding: t; -*-

(defun check-frame-parameters ()
    "現在のframeのtop,left,height,widthを表示する."
    (interactive)
    (let ((param-alist (frame-parameters))
          (params (list 'top 'left 'width 'height))
          (retval))
      (while params
        (push (assq (car params) param-alist) retval)
        (setq params (cdr params)))
      (message "%s" retval)))

(defun split-window-vertically-n (num_wins)
  "Split the current frame vertically into `NUM_WINS'."
  (interactive "p")
  (if (= num_wins 2)
      (split-window-vertically)
    (progn
      (split-window-vertically
       (- (window-height) (/ (window-height) num_wins)))
      (split-window-vertically-n (- num_wins 1)))))

(defun split-window-horizontally-n (num_wins)
  "Split the current frame horizontally into `NUM_WINS'."
  (interactive "p")
  (if (= num_wins 2)
      (split-window-horizontally)
    (progn
      (split-window-horizontally
       (- (window-width) (/ (window-width) num_wins)))
      (split-window-horizontally-n (- num_wins 1)))))

(defun other-window-or-split ()
  "If the current frame has only one window, split horizontaly."
  (interactive)
  (when (one-window-p) (split-window-horizontally))
  (other-window 1))

(defun other-window-or-split-2 ()
  "Split the current window into two or three siede-by-side windows.
If the frame column is less then 270, split into two windows,
else split three.

This kind of function originally suggested by rubikitch
and posted at
`https://rubikitch.hatenadiary.org/entry/20100210/emacs'.
Later, shiayu36 changed a little and publish the function
at `http://shibayu36.hatenablog.com/entry/2012/12/18/161455'"
  (interactive)
  (when (one-window-p)
    (if (>= (window-body-width) 270)
        (split-window-horizontally-n 3)
      (split-window-horizontally)))
  (other-window 1))

;;;###autoload
(defun other-window-or-split-or-close (arg)
  "Split, move or close window depend on the situations.
When the number of windows is one, split it into two side-by-side
windows.  When two or more, select another window in cyclic
ordering of windows.

If ARG is 4, by \\[universal-argument], select another window in
inverse cyclic order.  If ARG is 16, by \\[universal-argument] \\[universal-argument], delete the current window."
  (interactive "p")
  (cl-case arg
    (4  (other-window -1))
    (16 (delete-window))
    (t  (other-window-or-split))))

;;;###autoload
(defun swap-window-positions ()         ; Stephen Gildea
  "*Swap the positions of this window and the next one.

The function was published at
`https://www.emacswiki.org/emacs/TransposeWindows'"
  (interactive)
  (let ((other-window (next-window (selected-window) 'no-minibuf)))
    (let ((other-window-buffer (window-buffer other-window))
          (other-window-hscroll (window-hscroll other-window))
          (other-window-point (window-point other-window))
          (other-window-start (window-start other-window)))
      (set-window-buffer other-window (current-buffer))
      (set-window-hscroll other-window (window-hscroll (selected-window)))
      (set-window-point other-window (point))
      (set-window-start other-window (window-start (selected-window)))
      (set-window-buffer (selected-window) other-window-buffer)
      (set-window-hscroll (selected-window) other-window-hscroll)
      (set-window-point (selected-window) other-window-point)
      (set-window-start (selected-window) other-window-start))
    (select-window other-window)))

(provide 'my-window-utils)
