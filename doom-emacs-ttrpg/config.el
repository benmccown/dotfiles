;; (package-initialize)
;; (org-babel-load-file "~/.dotfiles/doom-emacs-ttrpg/config.org")

(setq user-full-name "Ben McCown"
      user-mail-address "bmccown93@gmail.com")

(add-to-list 'load-path "~/.dotfiles/doom-emacs-ttrpg/emacs-rpgdm/")
(require 'rpgdm)

(setq doom-theme 'doom-molokai)
(setq display-line-numbers-type t)

(with-eval-after-load 'doom-themes
  (doom-themes-org-config))

 (use-package! mixed-pitch
   :hook
   ;; If you want it in all text modes:
   (text-mode . mixed-pitch-mode)
   :config
   (setq mixed-pitch-set-height t)
   (set-face-attribute 'variable-pitch nil :height 1.2)
)

;; (setq doom-font (font-spec :family "JetBrains Mono" :size 14 :height 1.0)
;;      doom-variable-pitch-font (font-spec :family "Inconsolata" :height 1.2))

(use-package! evil-easymotion
  :after evil
  :ensure t
  :config
  (evilem-default-keybindings "g SPC")
)

(after! org-roam
  (setq org-roam-directory "~/org/ttrpg")
  )

(after! org-roam
  (setq org-roam-capture-templates
      '(("p" "place" plain ":PROPERTIES:\n:ID: %(org-id-new)\n:END:\n\n%?"
         :if-new (file+olp "places.org"
                            ("${title}"))
         :immediate-finish t
         :unnarrowed t)
        ("n" "npc" plain ":PROPERTIES:\n:ID: %(org-id-new)\n:END:\n\nName: %^{Name}%?"
         :if-new
         (file+olp "npcs.org" ("${title}"))
         :immediate-finish t
         :unnarrowed t)
        ("r" "reference" plain "%?"
         :if-new
         (file+head "reference/${slug}.org" "#+title: ${title}\n")
         :immediate-finish t
         :unnarrowed t)
        ("a" "article" plain "%?"
         :if-new
         (file+head "articles/${slug}.org" "#+title: ${title}\n#+filetags: :article:\n")
         :immediate-finish t
         :unnarrowed t)))
  )

(after! org-roam
  (cl-defmethod org-roam-node-type ((node org-roam-node))
    "Return the TYPE of NODE."
    (condition-case nil
        (file-name-base (org-roam-node-file node))
      (error "")))
  (setq org-roam-node-display-template
      (concat "${type:15} ${title:*} " (propertize "${tags:10}" 'face 'org-tag)))
  )

(after! org
  (setq org-directory "~/org")
  (setq org-agenda-files (directory-files-recursively "~/org" "\\.org$"))
)

(after! org

  (setq org-log-into-drawer "LOGBOOK")

  (setq org-capture-templates
        '(
        ("b" "Backlog Item" entry (file org-default-inbox-file)
           "* TODO [#5] %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n:LOGBOOK:\n:END:\n" :empty-lines-before 1 :empty-lines-after 1)
        ("s" "Scheduled Todo Item" entry (file org-default-inbox-file)
           "* TODO %(prio) %?\nSCHEDULED: %^t\n:PROPERTIES:\n:CREATED: %U\n:END:\n:LOGBOOK:\n:END:\n" :empty-lines-before 1 :empty-lines-after 1)
        ("t" "SIM Ticket or On Call Task" entry (file "sim.org")
           "* TODO %(prio) %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n:LOGBOOK:\n:END:\n" :empty-lines-before 1 :empty-lines-after 1)
        ("n" "Notes Slipbox Entry" entry  (file "braindump.org")
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
        '((sequence "TODO(t)" "FOLLOWUP_ITEM(f@/!)" "IN_PROGRESS(g!/!)" "UNDER_REVIEW(r@)" "WAITING(w@)" "BLOCKED(b@)" "|" "DONE(d!)" "OBE(e@)" "DELEGATED(p@)" "DROPPED(x@)")))
  (setq org-todo-keywords-for-agenda
        '((sequence "TODO(t)" "FOLLOWUP_ITEM(f@/!)" "IN_PROGRESS(g!/!)" "UNDER_REVIEW(r@)" "WAITING(w@)" "BLOCKED(b@)" "|" "DONE(d!)" "OBE(e@)" "DELEGATED(p@)" "DROPPED(x@)")))

;; fontify code in code blocks
(setq org-src-fontify-natively t)

(setq org-hide-emphasis-markers t)
  (font-lock-add-keywords 'org-mode
                          '(("^ *\\([-]\\) "
                             (0 (prog1 () (compose-region (match-beginning 1) (match-end 1) "•"))))))
;; (let* ((variable-tuple
;;           (cond ((x-list-fonts "Fira Mono")         '(:font "Fira Mono"))
;;                 ((x-list-fonts "Source Sans Pro") '(:font "Source Sans Pro"))
;;                 ((x-list-fonts "Lucida Grande")   '(:font "Lucida Grande"))
;;                 ((x-list-fonts "Verdana")         '(:font "Verdana"))
;;                 ((x-family-fonts "Sans Serif")    '(:family "Sans Serif"))
;;                 (nil (warn "Cannot find a Sans Serif Font.  Install Source Sans Pro."))))
;;          (base-font-color     (face-foreground 'default nil 'default))
;;          (headline           `(:inherit default :weight bold :foreground ,base-font-color)))

;;     (custom-theme-set-faces
;;      'user
;;      `(org-level-8 ((t (,@headline ,@variable-tuple))))
;;      `(org-level-7 ((t (,@headline ,@variable-tuple))))
;;      `(org-level-6 ((t (,@headline ,@variable-tuple))))
;;      `(org-level-5 ((t (,@headline ,@variable-tuple))))
;;      `(org-level-4 ((t (,@headline ,@variable-tuple))))
;;      `(org-level-3 ((t (,@headline ,@variable-tuple))))
;;      `(org-level-2 ((t (,@headline ,@variable-tuple :height 1.1))))
;;      `(org-level-1 ((t (,@headline ,@variable-tuple :height 1.2))))
;;      `(org-document-title ((t (,@headline ,@variable-tuple :height 2.0 :underline nil))))))
  ;; (custom-theme-set-faces
  ;;  'user
  ;;  '(variable-pitch ((t (:family "Fira Mono" :height 180 :weight thin))))
  ;;  '(fixed-pitch ((t ( :family "Iosevka" :height 160)))))
;; (add-hook 'org-mode-hook 'variable-pitch-mode)
(custom-theme-set-faces
   'user
;;    '(org-block ((t (:inherit fixed-pitch :foreground "#f7eeeb" :background "#433143"))))
;;    '(org-code ((t (:inherit (shadow fixed-pitch)))))
;;    '(org-document-info ((t (:foreground "dark orange"))))
;;    '(org-document-info-keyword ((t (:inherit (shadow fixed-pitch)))))
;;    '(org-indent ((t (:inherit (org-hide fixed-pitch)))))
;;    '(org-link ((t (:foreground "royal blue" :underline t))))
;;    '(org-meta-line ((t (:inherit (font-lock-comment-face fixed-pitch)))))
;;    '(org-property-value ((t (:inherit fixed-pitch))) t)
;;    '(org-special-keyword ((t (:inherit (font-lock-comment-face fixed-pitch)))))
;;    '(org-table ((t (:inherit fixed-pitch :foreground "#83a598"))))
;;    '(org-tag ((t (:inherit (shadow fixed-pitch) :weight bold :height 0.8))))
;;    '(org-verbatim ((t (:inherit (shadow fixed-pitch)))))
   )

)

(use-package org-bullets
    :config
    (add-hook 'org-mode-hook (lambda () (org-bullets-mode 1))))

(after! avy
  (setq avy-keys (number-sequence ?a ?z))
  (setq avy-style 'at)
  )

;; (map! :after evil-org-mode
;;       :map evil-org-mode-map
;;       :localleader
;;       (:prefix-map ("z" . "custom")
;;        :desc "Toggle hide drawer" "a" #'org-hide-drawer-toggle)
;;       )

(setq org-agenda-custom-commands
      '(("c" . "My Custom Agendas")
        ("cu" "Unscheduled TODO"
         ((todo ""
                ((org-agenda-overriding-header "\nUnscheduled TODO")
                 (org-agenda-skip-function '(org-agenda-skip-entry-if 'scheduled)))))
         nil
         nil)))
