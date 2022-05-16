;; (package-initialize)
;; (org-babel-load-file "~/.dotfiles/doom-emacs/config.org")

(setq user-full-name "Ben McCown"
      user-mail-address "mccownbm@amazon.com")

(setq doom-theme 'doom-monokai-pro)
(setq display-line-numbers-type t)

(when (display-graphic-p)
  (custom-theme-set-faces! 'doom-monokai-pro
    '(line-number :foreground "#615b56")
    )
  )

(setq diary-file "~/Documents/doom-org/diary")

(after! org
  (setq org-directory "~/Documents/doom-org")
  (setq org-agenda-files (directory-files-recursively "~/Documents/doom-org" "\\.org$"))
  (setq org-default-inbox-file "~/Documents/doom-org/todo.org")
)

(use-package! evil-easymotion
  :after evil
  :ensure t
  :config
  (evilem-default-keybindings "g SPC")
)

(after! org-roam
  (setq org-roam-directory "~/Documents/doom-org/notes")
  )

(after! org-roam
  (setq org-roam-capture-templates
      '(("m" "main" plain
         "%?"
         :if-new (file+head "main/${slug}.org"
                            "#+title: ${title}\n")
         :immediate-finish t
         :unnarrowed t)
        ("r" "reference" plain "%?"
         :if-new
         (file+head "reference/${title}.org" "#+title: ${title}\n")
         :immediate-finish t
         :unnarrowed t)
        ("a" "article" plain "%?"
         :if-new
         (file+head "articles/${title}.org" "#+title: ${title}\n#+filetags: :article:\n")
         :immediate-finish t
         :unnarrowed t)))
  )

(after! org-roam
  (cl-defmethod org-roam-node-type ((node org-roam-node))
    "Return the TYPE of NODE."
    (condition-case nil
        (file-name-nondirectory
         (directory-file-name
          (file-name-directory
           (file-relative-name (org-roam-node-file node) org-roam-directory))))
      (error "")))
  (setq org-roam-node-display-template
      (concat "${type:15} ${title:*} " (propertize "${tags:10}" 'face 'org-tag)))
  )

(after! org

  (setq org-log-into-drawer "LOGBOOK")

  (setq org-capture-templates
        '(
        ("a" "AppFlow project item" entry (file+headline "~/Documents/doom-org/appflow-replacement.org" "AppFlow Epic")
           "* TODO %(prio) %?\nSCHEDULED: %^t\n:PROPERTIES:\n:CREATED: %U\n:END:\n:LOGBOOK:\n:END:\n" :empty-lines-before 1 :empty-lines-after 1)
        ("b" "Backlog item" entry (file org-default-inbox-file)
           "* TODO [#5] %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n:LOGBOOK:\n:END:\n" :empty-lines-before 1 :empty-lines-after 1)
        ("s" "Scheduled todo item" entry (file org-default-inbox-file)
           "* TODO %(prio) %?\nSCHEDULED: %^t\n:PROPERTIES:\n:CREATED: %U\n:END:\n:LOGBOOK:\n:END:\n" :empty-lines-before 1 :empty-lines-after 1)
        ("n" "Notes slipbox" entry  (file "braindump/inbox.org")
         "* %?\n")
        )
        )

  (setq org-log-done 'time)
  (setq org-hide-emphasis-markers t)
  (add-hook 'org-mode-hook 'visual-line-mode)

  (setq org-priority-highest 1)
  (setq org-priority-lowest 5)
  (setq org-priority-default 3)

  (defun prio ()
  (format "[#%d]" org-priority-default))

  (setq org-todo-keywords
        '((sequence "TODO(t)" "FOLLOWUP_ITEM(f@/!)" "IN_PROGRESS(g!/!)" "OPEN_CR(c@)" "UNDER_REVIEW(r@)" "BLOCKED(b@)" "|" "DONE(d!)" "OBE(e@)" "DELEGATED(p@)" "DROPPED(x@)")))
  (setq org-todo-keywords-for-agenda
        '((sequence "TODO(t)" "FOLLOWUP_ITEM(f@/!)" "IN_PROGRESS(g!/!)" "OPEN_CR(c@)" "UNDER_REVIEW(r@)" "BLOCKED(b@)" "|" "DONE(d!)" "OBE(e@)" "DELEGATED(p@)" "DROPPED(x@)")))

)

;; (map! :after evil-org-mode
;;       :map evil-org-mode-map
;;       :localleader
;;       (:prefix-map ("z" . "custom")
;;        :desc "Toggle hide drawer" "a" #'org-hide-drawer-toggle)
;;       )

(after! evil-org
(push '("cu" "Unscheduled TODO"
         ((todo ""
                ((org-agenda-overriding-header "\nUnscheduled TODO")
                 (org-agenda-skip-function '(org-agenda-skip-entry-if 'timestamp)))))
         nil
         nil) org-agenda-custom-commands)
)
