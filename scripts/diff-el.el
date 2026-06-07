;;; diff-el.el --- Show .el file diffs for packages whose pinned revisions changed -*- lexical-binding: t; -*-
;;
;; Usage: emacs -Q --batch --script scripts/diff-el.el [BASE]
;;
;; BASE defaults to HEAD. Run after `just update` + `just lock`, before committing.
;;
;; GitHub/GitLab: fetched via the compare API (no local clone needed).
;; Other git hosts: bare-cloned into a temp directory, cleaned up on exit.
;;
;; Security: every field read from lock/flake.lock is validated before use in
;; URLs, file paths, or process arguments to prevent data-driven injection.

(require 'json)
(require 'url)
(require 'subr-x)

;;; ---------- Input validation ----------

(defun diff-el--safe-name-p (s)
  "Non-nil when S is a plausible owner/repo component with no shell metacharacters."
  (and (stringp s)
       (< 0 (length s) 200)
       ;; Allow alphanumeric, hyphens, underscores, dots, and a single slash
       ;; (for GitLab subgroups). No leading/trailing dots, no '..'.
       (string-match-p "\\`[A-Za-z0-9_.-]+\\(?:/[A-Za-z0-9_.-]+\\)*\\'" s)
       (not (string-search ".." s))))

(defun diff-el--sha-p (s)
  "Non-nil when S looks like a full or abbreviated git SHA (7–40 hex chars)."
  (and (stringp s)
       (string-match-p "\\`[0-9a-f]\\{7,40\\}\\'" s)))

(defun diff-el--https-url-p (s)
  "Non-nil when S is an https:// URL of reasonable length."
  (and (stringp s)
       (string-prefix-p "https://" s)
       (< (length s) 512)))

;;; ---------- Lock-file parsing (mirrors review-lock.el) ----------

(defconst diff-el--lock-file "lock/flake.lock")

(defun diff-el--parse-json (s)
  (json-parse-string s :object-type 'alist :array-type 'list))

(defun diff-el--locked-nodes (lock)
  "Return alist of (NAME . LOCKED-ALIST) for every locked node in LOCK."
  (let (acc)
    (pcase-dolist (`(,name . ,node) (alist-get 'nodes lock))
      (when-let ((locked (alist-get 'locked node)))
        (push (cons name locked) acc)))
    (nreverse acc)))

(defun diff-el--read-working-lock ()
  (diff-el--parse-json
   (with-temp-buffer
     (insert-file-contents diff-el--lock-file)
     (buffer-string))))

(defun diff-el--read-lock-at (ref)
  (with-temp-buffer
    (unless (eq 0 (call-process "git" nil t nil
                                "show" (format "%s:%s" ref diff-el--lock-file)))
      (error "Cannot read %s at %S" diff-el--lock-file ref))
    (diff-el--parse-json (buffer-string))))

;;; ---------- GitHub compare API ----------

(defun diff-el--github-el-diffs (owner repo old new)
  "Return alist of (FILENAME . PATCH) for .el files changed between OLD and NEW.
Validates all arguments before constructing the URL."
  (unless (and (diff-el--safe-name-p owner) (diff-el--safe-name-p repo)
               (diff-el--sha-p old) (diff-el--sha-p new))
    (error "Rejected unsafe values — owner=%S repo=%S old=%S new=%S"
           owner repo old new))
  (let* ((url (format "https://api.github.com/repos/%s/%s/compare/%s...%s"
                      owner repo old new))
         (url-request-extra-headers
          '(("Accept"     . "application/vnd.github.v3+json")
            ("User-Agent" . "emacs-diff-el/0.1"))))
    (with-current-buffer (url-retrieve-synchronously url t t 30)
      (goto-char (point-min))
      (unless (re-search-forward "^HTTP/.* 200" (line-end-position) t)
        (error "GitHub API non-200 for %s/%s (rate-limited?)" owner repo))
      (re-search-forward "\r?\n\r?\n" nil t)
      (let* ((data  (diff-el--parse-json (buffer-substring (point) (point-max))))
             (files (alist-get 'files data))
             acc)
        (dolist (f files (nreverse acc))
          (let ((name  (alist-get 'filename f))
                (patch (alist-get 'patch    f)))
            (when (and (stringp name) (string-suffix-p ".el" name)
                       (stringp patch))
              (push (cons name patch) acc))))))))

;;; ---------- GitLab compare API ----------

(defun diff-el--gitlab-el-diffs (owner repo old new)
  "Return alist of (FILENAME . PATCH) for .el files changed between OLD and NEW."
  (unless (and (diff-el--safe-name-p owner) (diff-el--safe-name-p repo)
               (diff-el--sha-p old) (diff-el--sha-p new))
    (error "Rejected unsafe values — owner=%S repo=%S old=%S new=%S"
           owner repo old new))
  (let* ((project (url-hexify-string (concat owner "/" repo)))
         (url (format
               "https://gitlab.com/api/v4/projects/%s/repository/compare?from=%s&to=%s"
               project old new))
         (url-request-extra-headers '(("User-Agent" . "emacs-diff-el/0.1"))))
    (with-current-buffer (url-retrieve-synchronously url t t 30)
      (goto-char (point-min))
      (re-search-forward "\r?\n\r?\n" nil t)
      (let* ((data  (diff-el--parse-json (buffer-substring (point) (point-max))))
             (diffs (alist-get 'diffs data))
             acc)
        (dolist (d diffs (nreverse acc))
          (let ((name  (alist-get 'new_path d))
                (patch (alist-get 'diff     d)))
            (when (and (stringp name) (string-suffix-p ".el" name)
                       (stringp patch))
              (push (cons name patch) acc))))))))

;;; ---------- Bare-clone fallback ----------

(defvar diff-el--workdir nil)

(defun diff-el--workdir ()
  (or diff-el--workdir
      (setq diff-el--workdir (make-temp-file "diff-el-" t))))

(defun diff-el--cleanup ()
  (when (and diff-el--workdir (file-directory-p diff-el--workdir))
    (delete-directory diff-el--workdir t)
    (setq diff-el--workdir nil)))

(defun diff-el--git-el-diffs (repo-url old new)
  "Bare-clone REPO-URL and return the .el diff between OLD and NEW as a string.
Only https:// URLs are accepted."
  (unless (diff-el--https-url-p repo-url)
    (error "Only https:// URLs are accepted; got: %S" repo-url))
  (unless (and (diff-el--sha-p old) (diff-el--sha-p new))
    (error "Unsafe SHAs: %S %S" old new))
  (let ((dir (expand-file-name (make-temp-name "clone-") (diff-el--workdir))))
    ;; call-process keeps args separate — no shell interpolation
    (unless (eq 0 (call-process "git" nil nil nil
                                "clone" "--bare" "--quiet" repo-url dir))
      (error "git clone failed for %s" repo-url))
    (with-temp-buffer
      (call-process "git" nil t nil "-C" dir "diff" old new "--" "*.el")
      (buffer-string))))

;;; ---------- Main ----------

(defun diff-el--run (base)
  (let* ((old-nodes (diff-el--locked-nodes (diff-el--read-lock-at base)))
         (new-nodes (diff-el--locked-nodes (diff-el--read-working-lock)))
         changed)
    (pcase-dolist (`(,name . ,new-loc) new-nodes)
      (let* ((old-loc (alist-get name old-nodes))
             (old-rev (and old-loc (alist-get 'rev old-loc)))
             (new-rev (alist-get 'rev new-loc)))
        (when (and old-rev new-rev (not (equal old-rev new-rev)))
          (push (list name old-loc new-loc old-rev new-rev) changed))))
    (setq changed (nreverse changed))
    (if (null changed)
        (princ (format "No package revision changes vs %s.\n" base))
      (princ (format "# .el diffs — %d packages changed vs %s\n" (length changed) base))
      (pcase-dolist (`(,name ,_old-loc ,new-loc ,old-rev ,new-rev) changed)
        (let ((s-old (substring old-rev 0 (min 9 (length old-rev))))
              (s-new (substring new-rev 0 (min 9 (length new-rev)))))
          (princ (format "\n## %s  (%s -> %s)\n" name s-old s-new)))
        (let* ((type  (alist-get 'type  new-loc))
               (owner (alist-get 'owner new-loc))
               (repo  (alist-get 'repo  new-loc))
               (url   (alist-get 'url   new-loc))
               (pairs
                (condition-case err
                    (pcase type
                      ("github"
                       (diff-el--github-el-diffs owner repo old-rev new-rev))
                      ("gitlab"
                       (diff-el--gitlab-el-diffs owner repo old-rev new-rev))
                      (_
                       (if (diff-el--https-url-p url)
                           (let ((d (diff-el--git-el-diffs url old-rev new-rev)))
                             (when (> (length d) 0) (list (cons "(all .el)" d))))
                         (princ (format "  [skipped: unsupported type %S]\n" type))
                         nil)))
                  (error
                   (princ (format "  [error: %s]\n" (error-message-string err)))
                   nil))))
          (if (null pairs)
              (princ "  (no .el file changes)\n")
            (dolist (p pairs)
              (princ (format "\n### %s\n" (car p)))
              (princ (cdr p))
              (princ "\n"))))))))

(add-hook 'kill-emacs-hook #'diff-el--cleanup)
(diff-el--run (or (car command-line-args-left) "HEAD"))
(diff-el--cleanup)

;;; diff-el.el ends here
