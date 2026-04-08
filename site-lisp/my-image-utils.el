;;; my-image-utils.el -*- lexical-binding: t; -*-

;; https://qiita.com/hibitomo/items/7e955ba5d951398f0cc1

(defcustom paste-image-script-path "$HOME/wsl_bin/paste_image.ps1"
  "Path of the powershell script for pasting image.")

(defun save-clipboard-image-as-png--windows (filename)
  "Save clipboard image as a png file named FILENAME."
  (call-process "powershell.exe" nil nil nil
                "powershell.exe -ExecutionPolicy RemoteSigned"
                " -File \"" paste-image-script-path "\""
                " -FileName " filename))

(defun save-clipboard-image-as-png--others (filename cmd)
  "Save clipboard image as a png file named FILENAME."
  (if (executable-find cmd)
      (shell-command (concat cmd " " filename))
    (message "%s not found" cmd)))

;;;###autoload
(defun save-clipboard-image-as-png (filename)
  "Save clipboard image as a png file named FILENAME."
  (interactive
   (list (read-file-name "Save file name: "
                         (concat (format-time-string "%Y%m%dT%H%M%S") ".png"))))
  (message "Try to create File %s..." filename)
  (cond
   ((or (> (length (getenv "WSL_DISTRO_NAME")) 0)
        (eq system-type 'windows-nt))
    (save-clipboard-image-as-png--windows filename))
   ((eq system-type 'darwin)
    (save-clipboard-image-as-png--others filename "pngpaste"))
   ((eq system-type 'gnu/linux)
    (save-clipboard-image-as-png--others filename "xclip"))
   (t
    (message "system-type %s is not supported now" system-type))))

;;;###autoload
(defun insert-clipboard-image-as-markdown-or-org-style ()
  "Generate png file from a clipboard image and insert a link to current buffer."
  (interactive)
  (let ((fn (concat "./" (format-time-string "%Y%m%dT%H%M%S") ".png")))
    (save-clipboard-image-as-png fn)
    (if (file-exists-p fn)
        (if (eq major-mode 'org-mode)
            (insert (concat "[[file:" fn "]]"))
          (insert (concat "![](" fn ")"))))))

(provide 'my-image-utils)
