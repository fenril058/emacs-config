;;; Font   -*- lexical-binding: t; -*-

;;;###autoload
(defun check-font-here ()
  "カーソルの位置のフォントを確認する."
  (interactive)
  (princ (font-xlfd-name (font-at (point)))))

;;;###autoload
(defun print-all-available-font-familes ()
  "使用可能なfont-familyをすべて表示する."
  (interactive)
  (let ((buf (get-buffer-create "*Font Familes*"))
        (cbuf (current-buffer)))
    (with-current-buffer buf
      (delete-region (point-min) (point-max))
      ;; (print (font-family-list) buf)
      (dolist (x (font-family-list))
        (progn  (print x buf)
                (delete-region (- (point-max) 1) (point-max)))))
    (pop-to-buffer buf)
    (delete-region (point-min) (+ (point-min) 1))
    ;; (goto-char (point-max))
    (switch-to-buffer-other-window cbuf)))

;;;###autoload
(defun print-all-available-fontsets ()
  "使用可能なfont-setをすべて表示する."
  (interactive)
  (let ((buf (get-buffer-create "*Fontsets"))
        (cbuf (current-buffer)))
    (with-current-buffer buf
      (delete-region (point-min) (point-max))
      ;; (print (font-family-list) buf)
      (dolist (x (x-list-fonts "*"))
        (progn  (print x buf)
                (delete-region (- (point-max) 1) (point-max)))))
    (pop-to-buffer buf)
    (delete-region (point-min) (+ (point-min) 1))
    ;; (goto-char (point-max))
    (switch-to-buffer-other-window cbuf)))

(provide 'my-font-utils)
