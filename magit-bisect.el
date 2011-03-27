(defvar magit--bisect-info nil)
(make-variable-buffer-local 'magit--bisect-info)
(put 'magit--bisect-info 'permanent-local t)

(defun magit--bisecting-p (&optional required-status)
  "Return t if a bisect session is running"
  (and (file-exists-p (concat (magit-get-top-dir default-directory)
                          ".git/BISECT_LOG"))
       (or (not required-status)
           (eq (plist-get (magit--bisect-info) :status)
               required-status))))

(defun magit--bisect-info ()
  (with-current-buffer (magit-find-status-buffer)
    (or (if (local-variable-p 'magit--bisect-info) magit--bisect-info)
        (list :status (if (magit--bisecting-p) 'running 'not-running)))))

(defun magit--bisect-cmd (&rest args)
  "Run `git bisect ...' and update the status buffer"
  (with-current-buffer (magit-find-status-buffer)
    (let* ((output (apply 'magit-git-lines (append '("bisect") args)))
           (cmd (car args))
           (first-line (car output)))
      (save-match-data
        (setq magit--bisect-info
              (cond ((string= cmd "reset")
                     (list :status 'not-running))
                    ;; Bisecting: 78 revisions left to test after this (roughly 6 steps)
                    ((string-match "^Bisecting:\\s-+\\([0-9]+\\).+roughly\\s-+\\([0-9]+\\)" first-line)
                     (list :status 'running
                           :revs (match-string 1 first-line)
                           :steps (match-string 2 first-line)))
                    ;; e2596955d9253a80aec9071c18079705597fa102 is the first bad commit
                    ((string-match "^\\([a-f0-9]+\\)\\s-.*first bad commit" first-line)
                     (list :status 'finished
                           :bad (match-string 1 first-line)))
                    (t
                     (list :status 'error)))))))
  (magit-refresh))

(defun magit--bisect-info-for-status (branch)
  "Return bisect info suitable for display in the status buffer"
  (let* ((info (magit--bisect-info))
         (status (plist-get info :status)))
    (cond ((eq status 'not-running)
           (or branch "(detached)"))
          ((eq status 'running)
           (format "(bisecting; %s revisions & %s steps left)"
                   (or (plist-get info :revs) "unknown number of")
                   (or (plist-get info :steps) "unknown number of")))
          ((eq status 'finished)
           (format "(bisected: first bad revision is %s)" (plist-get info :bad)))
          (t
           "(bisecting; unknown error occured)"))))

(defun magit-bisect-start ()
  "Start a bisect session"
  (interactive)
  (if (magit--bisecting-p)
      (error "Already bisecting"))
  (let ((bad (magit-read-rev "Start bisect with known bad revision" "HEAD"))
        (good (magit-read-rev "Good revision" (magit-default-rev))))
    (magit--bisect-cmd "start" bad good)))

(defun magit-bisect-reset ()
  "Quit a bisect session"
  (interactive)
  (unless (magit--bisecting-p)
    (error "Not bisecting"))
  (magit--bisect-cmd "reset"))

(defun magit-bisect-good ()
  "Tell git that the current revision is good during a bisect session"
  (interactive)
  (unless (magit--bisecting-p 'running)
    (error "Not bisecting"))
  (magit--bisect-cmd "good"))

(defun magit-bisect-bad ()
  "Tell git that the current revision is bad during a bisect session"
  (interactive)
  (unless (magit--bisecting-p 'running)
    (error "Not bisecting"))
  (magit--bisect-cmd "bad"))

(defun magit-bisect-skip (&optional pfx)
  "Tell git to skip the current revision during a bisect session.
With prefix let the user enter the revisions to skip."
  (interactive "P")
  (unless (magit--bisecting-p 'running)
    (error "Not bisecting"))
  (let ((args '("skip")))
    (if pfx
        (setq args (append args
                           (split (magit-completing-read "Revision(s) to skip: " nil)
                                  " "))))
    (apply 'magit--bisect-cmd args)))

(defun magit-bisect-log ()
  "Show the bisect log"
  (interactive)
  (unless (magit--bisecting-p)
    (error "Not bisecting"))
  (magit-run-git "bisect" "log")
  (magit-display-process))

(defun magit-bisect-visualize ()
  "Show the remaining suspects with gitk"
  (interactive)
  (unless (magit--bisecting-p)
    (error "Not bisecting"))
  (magit-run-git "bisect" "visualize")
  (unless (getenv "DISPLAY")
    (magit-display-process)))

(provide 'magit-bisect)
