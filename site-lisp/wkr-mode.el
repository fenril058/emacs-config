;;; wkr-mode.el --- major mode for writing weekly report -*- lexical-binding: t; -*-

;; Copyright (C) 2020-2025  ril

;; Author: ril <fenril.nh@gmail.com>
;; Keywords: outlines, convenience

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Require emacs 29.1 or higher to use `date-to-time'.

;;; Code:

(require 'markdown-mode)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; ### Macro / Utilities

(defun wkr:preview-email ()
  "Shell scriptを実行し, mailを作成する.
Shell scriptの中身はWindowsのpython scriptの呼び出し."
  (interactive)
  (let ((cmd "~/OneDrive/Documents/MyWeeklyReport/outlook.sh")
        (file (buffer-file-name)))
    (shell-command (concat cmd " " file))))

(defun wkr:conver-date (date)
  "Convert DATE which stayle is \"%Y/%m/%d\" to time value."
  (date-to-time (replace-regexp-in-string "/" "-" date)))

(defun wkr:update-top-date ()
  "Rewrite top line of the weekly report.
 From \\'Weekly Report n週目 (yyyy/mm/dd - yyyy/mm/dd)\\' to \\'Weekly
Report n+1週目 (yyyy/mm/dd+7 - yyyy/mm/dd+7)\\' in the buffer."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (let ((report-regex "Weekly Report \\([0-9]+\\)週目 (\\([0-9]+/[0-9]+/[0-9]+\\) - \\([0-9]+/[0-9]+/[0-9]+\\))"))
      (re-search-forward report-regex nil t)
      (let* ((week-number (string-to-number (match-string 1)))
             (start-date (match-string 2))
             (end-date (match-string 3))
             (next-week-number (1+ week-number))
             (start-date-time (wkr:conver-date start-date))
             (end-date-time (wkr:conver-date end-date))
             (next-start-date (format-time-string "%Y/%m/%d" (time-add start-date-time (days-to-time 7))))
             (next-end-date (format-time-string "%Y/%m/%d" (time-add end-date-time (days-to-time 7))))
             (next-report (format "Weekly Report %d週目 (%s - %s)" next-week-number next-start-date next-end-date)))
        (goto-char (point-min))
        (re-search-forward report-regex nil t)
        (replace-match next-report)))))

(defun wkr:update-reported-date ()
  "Update reported date."
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (let ((report-regex "^\\([0-9]+/[0-9]+/[0-9]+\\)"))
      (re-search-forward report-regex nil t)
      (let* ((start-date (match-string 1))
             (start-date-time (wkr:conver-date start-date))
             (next-start-date (format-time-string "%Y/%m/%d" (time-add start-date-time (days-to-time 7)))))
        (goto-char (point-min))
        (re-search-forward report-regex nil t)
        (replace-match next-start-date)))))

(defun wkr:update-weekly-plan ()
  "【次週予定】を【予定】と【実績】にコピーする."
  (interactive)
  (save-excursion
    (wkr:update-top-date)
    (wkr:update-reported-date)
    (goto-char (point-min))
    (let ((begin (re-search-forward "^予定$" (point-max) t))
          (end (progn
                 (re-search-forward "^実績$" (point-max) t)
                 (pos-bol))))
      (when (and begin end) (kill-region begin (- end 1)))
      (setq begin (progn
                    (re-search-backward "^実績$" (point-min) t)
                    (pos-eol))
            end (progn
                  (re-search-forward "^### 実作業時間$" (point-max) t)
                  (pos-bol)))
      (when (and begin end) (kill-region begin (- end 1)))
      (setq begin (re-search-forward "^次週予定$" (point-max) t)
            end (progn
                  (re-search-forward "^<!--+>" (point-max) t)
                  (pos-bol)))
      (when (and begin end)
        (kill-ring-save begin (- end 1))
        (goto-char (point-min))
        (re-search-forward "^予定$" (point-max) t)
        (yank)
        (re-search-forward "^実績$" (point-max) t)
        (yank)
        ))))

(defun wkr:increment-week-numbers-in-string (input-string)
  "Increment all week numbers in the format \\'wkNN\\' within the given INPUT-STRING."
  (let ((start 0))
    (while (string-match "wk\\([0-9]+\\)" input-string start)
      (let* ((week-number (string-to-number (match-string 1 input-string)))
             (next-week-number (1+ week-number))
             (next-week (format "wk%02d" next-week-number)))
        (setq input-string (replace-match next-week t t input-string))
        (setq start (match-end 0))))
    input-string))

(defun wkr:update-weekly ()
  "週番号をincrementしたファイルを新しく作り、内容を更新する."
  (interactive)
  (let* ((old-name (buffer-file-name))
         (new-name (wkr:increment-week-numbers-in-string old-name)))
    (if (eq new-name old-name)
        (message "Something wrong: new and old file name are the same.")
      (write-file new-name)
      (wkr:update-weekly-plan)
      (message "Create New Weekly Report."))))

;;;###autoload
(defun wkr-cleanup ()
  "Formatting weekly report.
- Delete \\r (carriage return)
- Replace full-width spaces with half-width spaces
- Replace tabs with half-width spaces

主に他人のWeeklyreportの体裁を整えるために使う。"
  (interactive)
  (save-excursion
    (goto-char (point-min))
    (while (search-forward "" nil t nil)
      (replace-match ""))
    (goto-char (point-min))
    (while (search-forward "　" nil t nil)
      (replace-match "  "))
    (while (search-forward "	" nil t nil)
      (replace-match "    "))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; ### Major Mode

;;;###autoload
(define-derived-mode wkr-mode
  markdown-mode
  "Wkr"
  "Major mode for writing Weekly Report.
  \\{wkr-mode-map}"
  (setq case-fold-search nil)
  (display-fill-column-indicator-mode 1)
  (define-key wkr-mode-map (kbd "C-c C-u") 'wkr:update-weekly)
  (define-key wkr-mode-map (kbd "C-c C-c") 'wkr:preview-email))

(provide 'wkr-mode)
;;; wkr-mode.el ends here
