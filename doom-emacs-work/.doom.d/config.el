;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!

(package-initialize)
(org-babel-load-file "~/.dotfiles/doom-emacs-work/config.org")

;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "Ben McCown"
;;       user-mail-address "mccownbm@amazon.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-unicode-font' -- for unicode glyphs
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
;; (setq doom-theme 'doom-monokai-pro)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
;; (setq display-line-numbers-type t)
;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
;; (setq org-directory "~/Documents/doom-org")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `after!' block, otherwise Doom's defaults may override your settings. E.g.
;;
;;   (after! PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look up their documentation).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

;; Customizations
;; (menu-bar-mode 1)

;; https://github.com/Hettomei/dotfiles/blob/f475ff6407a10dcdfe123faa11611dd9fffd190c/default/doom.d/config.el#L71
;; (when (display-graphic-p)
;;   (custom-theme-set-faces! 'doom-monokai-pro
;;     '(line-number :foreground "#615b56")
;;     )
;;   )
;;
;;
;; (setq diary-file "~/Documents/doom-org/diary")
;;
;; (after! org
;;   (setq org-priority-highest 1)
;;   (setq org-priority-lowest 5)
;;   (setq org-priority-default 3)
;;   (setq org-default-inbox-file "~/Documents/doom-org/todo.org")
;;   (setq org-log-into-drawer "LOGBOOK")
;;   (defun prio ()
;;   (format "[#%d]" org-priority-default))
;;   (setq org-todo-keywords
;;         '((sequence "TODO(t)" "FOLLOWUP_ITEM(f@/!)" "IN_PROGRESS(g!/!)" "OPEN_CR(c@)" "BLOCKED(b@)" "|" "DONE(d!)" "OBE(e@)" "DELEGATED(p@)" "DROPPED(x@)")))
;;   (setq org-todo-keywords-for-agenda
;;         '((sequence "TODO(t)" "FOLLOWUP_ITEM(f@/!)" "IN_PROGRESS(g!/!)" "OPEN_CR(c@)" "BLOCKED(b@)" "|" "DONE(d!)" "OBE(e@)" "DELEGATED(p@)" "DROPPED(x@)")))
;;   (setq org-capture-templates
;;         '(
;;         ;;("b" "Backlog Item" entry (file+headline org-default-inbox-file "Backlog")
;;         ("a" "AppFlow Project Item" entry (file+headline "~/Documents/doom-org/appflow-replacement.org" "AppFlow Epic")
;;            "* TODO %(prio) %?\nSCHEDULED: %^t\n:PROPERTIES:\n:CREATED: %U\n:END:\n:LOGBOOK:\n:END:\n" :empty-lines-before 1 :empty-lines-after 1)
;;         ("b" "Backlog Item" entry (file org-default-inbox-file)
;;            "* TODO [#5] %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n:LOGBOOK:\n:END:\n" :empty-lines-before 1 :empty-lines-after 1)
;;         ("s" "Scheduled ToDo Item" entry (file org-default-inbox-file)
;;            "* TODO %(prio) %?\nSCHEDULED: %^t\n:PROPERTIES:\n:CREATED: %U\n:END:\n:LOGBOOK:\n:END:\n" :empty-lines-before 1 :empty-lines-after 1)
;;         )
;;         )
;; ;; https://github.com/james-stoup/emacs-org-mode-tutorial#default-settings
;;   (setq org-log-done 'time)
;;   (setq org-hide-emphasis-markers t)
;;   (add-hook 'org-mode-hook 'visual-line-mode)
;; )

;; https://rameezkhan.me/adding-keybindings-to-doom-emacs/
;; https://docs.doomemacs.org/latest/#/manual/concepts/special-keys/leader-localleader-keys
;; https://github.com/hlissner/doom-emacs/issues/2403
;; (map! :after evil-org
;;       :map evil-org-mode-map
;;       :localleader
;;       (:prefix-map ("z" . "custom")
;;        :desc "Toggle hide drawer" "a" #'org-hide-drawer-toggle)
;;       )
;;
;; ;; https://emacs.stackexchange.com/questions/16551/how-do-i-view-all-org-mode-todos-that-are-not-recurring-or-not-scheduled
;;
;; (push '("cu" "Unscheduled TODO" ((todo "" ((org-agenda-overriding-header "\nUnscheduled TODO") (org-agenda-skip-function '(org-agenda-skip-entry-if 'timestamp))))) nil nil) org-agenda-custom-commands)
