;;; review-lock.el --- Summarize what `just update` changed in the lock -*- lexical-binding: t; -*-

;; Compare two versions of lock/flake.lock and, for every package whose pinned
;; revision moved, print old->new revs together with an upstream "compare" URL
;; so the actual incoming commits can be eyeballed before committing.
;;
;; Usage (see the `review` recipe in justfile):
;;     emacs -Q --batch --script scripts/review-lock.el [BASE]
;;
;; BASE is a git ref (default: HEAD). The "new" side is always the working-tree
;; copy of lock/flake.lock, i.e. the result of the most recent `just update'.

;;; Code:

(require 'json)
(require 'subr-x)

(defconst review-lock-file "lock/flake.lock"
  "Lock file to inspect, relative to the repository root.")

(defun review-lock--parse (string)
  "Parse JSON STRING into an alist with symbol keys."
  (json-parse-string string :object-type 'alist :array-type 'list))

(defun review-lock--read-working ()
  "Parse the working-tree copy of the lock file."
  (review-lock--parse
   (with-temp-buffer
     (insert-file-contents review-lock-file)
     (buffer-string))))

(defun review-lock--read-ref (ref)
  "Parse the lock file as it exists at git REF."
  (with-temp-buffer
    (let ((status (call-process "git" nil t nil
                                "show" (format "%s:%s" ref review-lock-file))))
      (unless (eq status 0)
        (error "Cannot read %s at %S:\n%s"
               review-lock-file ref (buffer-string)))
      (review-lock--parse (buffer-string)))))

(defun review-lock--locked-nodes (lock)
  "Return an alist of (NAME . LOCKED-ALIST) for every locked node in LOCK."
  (let (result)
    (pcase-dolist (`(,name . ,node) (alist-get 'nodes lock))
      (when-let ((locked (alist-get 'locked node)))
        (push (cons name locked) result)))
    (nreverse result)))

(defun review-lock--short (rev)
  "Abbreviate REV to a short hash."
  (if (and rev (>= (length rev) 9)) (substring rev 0 9) (or rev "?")))

(defun review-lock--compare-url (loc old new)
  "Build an upstream compare URL for LOC moving from OLD to NEW rev."
  (let ((type (alist-get 'type loc)))
    (pcase type
      ("github"
       (format "https://github.com/%s/%s/compare/%s...%s"
               (alist-get 'owner loc) (alist-get 'repo loc) old new))
      ("gitlab"
       (format "https://gitlab.com/%s/%s/-/compare/%s...%s"
               (alist-get 'owner loc) (alist-get 'repo loc) old new))
      ("sourcehut"
       (format "https://git.sr.ht/~%s/%s/log"
               (alist-get 'owner loc) (alist-get 'repo loc)))
      ("git"
       (let ((url (string-remove-suffix ".git" (or (alist-get 'url loc) ""))))
         (cond
          ((string-search "github.com" url)
           (format "%s/compare/%s...%s" url old new))
          ((string-search "gitlab.com" url)
           (format "%s/-/compare/%s...%s" url old new))
          (t (format "%s  (%s -> %s)" url
                     (review-lock--short old) (review-lock--short new))))))
      (_ (format "(%s) %s -> %s" type
                 (review-lock--short old) (review-lock--short new))))))

(defun review-lock--run (base)
  "Print the package revision changes between BASE and the working tree."
  (let* ((old (review-lock--locked-nodes (review-lock--read-ref base)))
         (new (review-lock--locked-nodes (review-lock--read-working)))
         (names (seq-uniq (append (mapcar #'car old) (mapcar #'car new))))
         changed added removed)
    (dolist (name (sort names (lambda (a b) (string< (symbol-name a)
                                                      (symbol-name b)))))
      (let ((o (alist-get name old))
            (n (alist-get name new)))
        (cond
         ((and o n)
          (unless (equal (alist-get 'rev o) (alist-get 'rev n))
            (push (list name o n) changed)))
         (n (push (cons name n) added))
         (o (push (cons name o) removed)))))
    (setq changed (nreverse changed)
          added (nreverse added)
          removed (nreverse removed))
    (if (not (or changed added removed))
        (princ (format "No package revisions changed vs %s.\n" base))
      (when changed
        (princ (format "# Changed packages (%d) vs %s\n\n" (length changed) base))
        (pcase-dolist (`(,name ,o ,n) changed)
          (princ (format "%s: %s -> %s\n"
                         name
                         (review-lock--short (alist-get 'rev o))
                         (review-lock--short (alist-get 'rev n))))
          (princ (format "    %s\n\n"
                         (review-lock--compare-url
                          n (alist-get 'rev o) (alist-get 'rev n))))))
      (when added
        (princ (format "# Added (%d)\n" (length added)))
        (pcase-dolist (`(,name . ,n) added)
          (princ (format "  + %s @ %s  [%s]\n"
                         name (review-lock--short (alist-get 'rev n))
                         (alist-get 'type n))))
        (princ "\n"))
      (when removed
        (princ (format "# Removed (%d)\n" (length removed)))
        (pcase-dolist (`(,name . ,_o) removed)
          (princ (format "  - %s\n" name)))
        (princ "\n"))
      (princ (format "Totals: %d changed, %d added, %d removed.\n"
                     (length changed) (length added) (length removed))))))

(review-lock--run (or (car command-line-args-left) "HEAD"))

;;; review-lock.el ends here
