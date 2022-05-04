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

(after! org
  (setq org-log-into-drawer "LOGBOOK")

  (setq org-priority-highest 1)
  (setq org-priority-lowest 5)
  (setq org-priority-default 3)

  (defun prio ()
  (format "[#%d]" org-priority-default))

  (setq org-todo-keywords
        '((sequence "TODO(t)" "FOLLOWUP_ITEM(f@/!)" "IN_PROGRESS(g!/!)" "OPEN_CR(c@)" "BLOCKED(b@)" "|" "DONE(d!)" "OBE(e@)" "DELEGATED(p@)" "DROPPED(x@)")))
  (setq org-todo-keywords-for-agenda
        '((sequence "TODO(t)" "FOLLOWUP_ITEM(f@/!)" "IN_PROGRESS(g!/!)" "OPEN_CR(c@)" "BLOCKED(b@)" "|" "DONE(d!)" "OBE(e@)" "DELEGATED(p@)" "DROPPED(x@)")))

  (setq org-capture-templates
        '(
        ("a" "AppFlow Project Item" entry (file+headline "~/Documents/doom-org/appflow-replacement.org" "AppFlow Epic")
           "* TODO %(prio) %?\nSCHEDULED: %^t\n:PROPERTIES:\n:CREATED: %U\n:END:\n:LOGBOOK:\n:END:\n" :empty-lines-before 1 :empty-lines-after 1)
        ("b" "Backlog Item" entry (file org-default-inbox-file)
           "* TODO [#5] %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n:LOGBOOK:\n:END:\n" :empty-lines-before 1 :empty-lines-after 1)
        ("s" "Scheduled ToDo Item" entry (file org-default-inbox-file)
           "* TODO %(prio) %?\nSCHEDULED: %^t\n:PROPERTIES:\n:CREATED: %U\n:END:\n:LOGBOOK:\n:END:\n" :empty-lines-before 1 :empty-lines-after 1)
        )
        )

  (setq org-log-done 'time)
  (setq org-hide-emphasis-markers t)
  (add-hook 'org-mode-hook 'visual-line-mode)

)

(map! :after evil-org
      :map evil-org-mode-map
      :localleader
      (:prefix-map ("z" . "custom")
       :desc "Toggle hide drawer" "a" #'org-hide-drawer-toggle)
      )

(after! evil-org
(push '("cu" "Unscheduled TODO"
         ((todo ""
                ((org-agenda-overriding-header "\nUnscheduled TODO")
                 (org-agenda-skip-function '(org-agenda-skip-entry-if 'timestamp)))))
         nil
         nil) org-agenda-custom-commands)
)
