;;; my-say.el --- Text-to-speech using macOS `say` command -*- lexical-binding: t; -*-

;; Copyright (C) 2025  Your Name

;; Author: Your Name <yamatakau08@gmail.com>
;; Maintainer: Your Name <yamatakau08@gmail.com>
;; Created: 2025-10-31
;; Version: 0.1
;; Keywords: multimedia, macOS, speech, convenience
;; URL: https://github.com/yamatakau08/.emacs.d/tree/master/my-say
;; Package-Requires: ((emacs "26.1"))

;; This file is part of GNU Emacs.

;;; License:
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This package provides simple commands to make Emacs speak text aloud
;; using the macOS `say` command.
;;
;; Example usage:
;;   M-x my-say-word
;;   M-x my-say-line
;;   M-x my-say-region
;;   M-x my-say-buffer
;;   M-x my-say-stop
;;
;; To customize voice and rate:
;;   M-x customize-group RET my-say RET

;;; Code:

(defgroup my-say nil
  "Text-to-speech using `say` or `espeak-ng` command."
  :group 'multimedia
  :prefix "my-say-")

;;;; Customization

(defcustom my-say-command "espeak-ng"
  "The command to execute by `my-say--execute'"
  :type '(choice (string :tag "say")
                 (string :tag "espeak-ng")
                 (string :tag "espeak"))
  :group 'my-say)

(defcustom my-say-voice nil
  "The voice used for speech synthesis.
Default is the system voice configured in macOS.
To list available voices, run the command `say -v ?` in a shell."
  :type 'string
  :group 'my-say)

(defcustom my-say-rate 175
  "Speech rate in words per minute.
This value is passed to the `-r` option of the macOS `say` command.
See `man say` for details and https://multilingual-jonny.com/reading-speed-wpm/ for reading speed references."
  :type 'integer
  :group 'my-say)

(defcustom my-say-asynchronous t
  "If non-nil, speak asynchronously using `start-process`.
If nil, speak synchronously using `shell-command-to-string`.
Asynchronous mode allows Emacs to remain responsive during speech playback."
  :type 'boolean
  :group 'my-say)

;;;; Internal Variables
(defvar my-say--process nil
  "Internal variable holding the current `say` process when running asynchronously.")

;;;;;; Command

;;;###autoload
(defun my-say-word ()
  "Speak the word at point using the macOS `say` command.
If there is no word at point, display a message instead."
  (interactive)
  (let ((word (thing-at-point 'word t)))
    (if word
	    (my-say--execute my-say-voice my-say-rate word)
      (message "No word at point."))))

;;;###autoload
(defun my-say-line ()
  "Speak the current line using the macOS `say` command."
  (interactive)
  (let ((line (thing-at-point 'line t)))
    (my-say--execute my-say-voice my-say-rate line)))

;;;###autoload
(defun my-say-region (beg end)
  "Speak the region between BEG and END using the macOS `say` command.
Newlines are replaced with spaces before speaking."
  (interactive "r")
  (if (use-region-p)
      (let ((region (replace-regexp-in-string "\n" " " (buffer-substring-no-properties beg end))))
	    (my-say--execute my-say-voice my-say-rate region))
    (message "No region selected.")))

;;;###autoload
(defun my-say-buffer ()
  "Speak the entire contents of the current buffer using the macOS `say` command."
  (interactive)
  (let ((buffer (replace-regexp-in-string "\n" " " (buffer-substring-no-properties (point-min) (point-max)))))
    (if buffer
	    (my-say--execute my-say-voice my-say-rate buffer)
      (message "Buffer is empty."))))

;;;###autoload
(defun my-say-stop ()
  "Stop any ongoing speech started by `my-say` (asynchronous mode only)."
  (interactive)
  (when (and my-say--process (process-live-p my-say--process))
    (kill-process my-say--process)
    (message "Speech stopped.")))

;;;; Internal Functions
(defun my-say--execute (voice rate content)
  "Speak CONTENT using the macOS `say` command with VOICE and RATE.
If `my-say-asynchronous` is non-nil, use `start-process` for
non-blocking speech.  Otherwise, execute synchronously via
`shell-command-to-string`."
  (if my-say-asynchronous
      (progn
        (when (process-live-p my-say--process)
          (kill-process my-say--process))
        (setq my-say--process
              (start-process
               "my-say-process" nil
               my-say-command
               ;; (when voice (concat "-v" voice))
               (if (string= my-say-command "say") "-r" "-s") (number-to-string rate)
               content)))
    ;; sync
    (shell-command-to-string
     (mapconcat #'shell-quote-argument
                (list my-say-command
                      ;; (when voice (concat "-v" voice))
                      (if (string= my-say-command "say") "-r" "-s") (number-to-string rate)
                      content)
                " "))))

(provide 'my-say)

;;; my-say.el ends here
