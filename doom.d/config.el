;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets.
(setq user-full-name "Jeffery Utter"
      user-mail-address "jeff@jeffutter.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom. Here
;; are the three important ones:
;;
;; + `doom-font'
;; + `doom-variable-pitch-font'
;; + `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;;
;; They all accept either a font-spec, font string ("Input Mono-12"), or xlfd
;; font string. You generally only need these two:
(setq doom-font (font-spec :family "Source Code Pro" :size 12 :weight 'semi-light)
      doom-variable-pitch-font (font-spec :family "Source Code Pro") ; inherits `doom-font''s :size
      doom-unicode-font (font-spec :family "Source Code Pro" :size 12)
      doom-big-font (font-spec :family "Source Code Pro" :size 19))

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-nord)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type 'relative)

;; Here are some additional functions/macros that could help you configure Doom:
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
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

(add-hook! elixir-mode
  (flycheck-mode)
  (rainbow-delimiters-mode))

(after! elixir-mode
  (set-ligatures! 'elixir-mode))

(after! elixir-mode
  (set-ligatures! 'elixir-mode
    ;; Functional
    ;; :def "def"
    ;; :lambda "fn"
    :pipe "|>"
    ;; :src_block "do"
    ;; :src_block_end "end"
    ;; Flow
    :not "!"
    ;; :in "in"
    ;; :not-in "not in"
    :and "and"
    :or "or"
    ;; :for "for"
    :return "return"))
    ;; :yield "use"))

(after! sh-mode
  (set-ligatures! 'sh-mode))

(plist-put! +ligatures-extra-symbols
            :pipe "▷")

(use-package! flycheck-mix
  :after elixir-mode
  :config
  (add-hook 'flycheck-mode-hook #'flycheck-mix-setup))

(use-package! flycheck-credo
  :after elixir-mode
  :config
  (setq flycheck-elixir-credo-strict t)
  (add-hook 'flycheck-mode-hook #'flycheck-credo-setup))

(use-package! erlang
  :mode "\\.erl$"
  :config
  (erlang-mode))

(use-package lsp-mode
  :defer
  :commands lsp
  :diminish lsp-mode
  :hook
  (elixir-mode . lsp)
  (sqls . lsp)
  :init
  (setq lsp-clients-elixir-server-command "elixir-ls")
  )
  ;; :init
  ;; (add-to-list 'exec-path "~/elixir-ls/release/"))

(setq-default lsp-file-watch-ignored ())
(add-to-list 'lsp-file-watch-ignored ".elixir_ls")
(add-to-list 'lsp-file-watch-ignored "deps")
(add-to-list 'lsp-file-watch-ignored "_build")
(add-to-list 'lsp-file-watch-ignored "assets/node_modules")

(add-to-list 'initial-frame-alist '(fullscreen . maximized))

(setq lsp-treemacs-sync-mode 1)

(map! :map evil-window-map
      "SPC" #'rotate-layout
      ;; Navigation
      "<left>"     #'evil-window-left
      "<down>"     #'evil-window-down
      "<up>"       #'evil-window-up
      "<right>"    #'evil-window-right
      ;; Swapping windows
      "C-<left>"       #'+evil/window-move-left
      "C-<down>"       #'+evil/window-move-down
      "C-<up>"         #'+evil/window-move-up
      "C-<right>"      #'+evil/window-move-right)
(map! :leader :desc "Toggle neotree" :prefix "f" "t" #'+treemacs/toggle)
(map! :leader :desc "Find file in project" :prefix "p" "f" #'+ivy/projectile-find-file)
(map! :leader :desc "Show file in project tree" :prefix "p" "F" #'treemacs-find-file)

(map! :leader
      (:prefix-map ("l" . "layout")
       (:prefix ("w" . "workspaces")
        :desc "Display tab bar"           "TAB" #'+workspace/display
        :desc "Switch workspace"          "."   #'+workspace/switch-to
        :desc "Switch to last workspace"  "`"   #'+workspace/other
        ;; :desc "New workspace"             "n"   #'+workspace/new
        ;; :desc "Load workspace from file"  "l"   #'+workspace/load
        ;; :desc "Save workspace to file"    "s"   #'+workspace/save
        :desc "Delete session"            "x"   #'+workspace/kill-session
        :desc "Delete this workspace"     "d"   #'+workspace/delete
        :desc "Rename workspace"          "r"   #'+workspace/rename
        :desc "Restore last session"      "R"   #'+workspace/restore-last-session
        :desc "Next workspace"            "]"   #'+workspace/switch-right
        :desc "Previous workspace"        "["   #'+workspace/switch-left
        :desc "Switch to 1st workspace"   "1"   #'+workspace/switch-to-0
        :desc "Switch to 2nd workspace"   "2"   #'+workspace/switch-to-1
        :desc "Switch to 3rd workspace"   "3"   #'+workspace/switch-to-2
        :desc "Switch to 4th workspace"   "4"   #'+workspace/switch-to-3
        :desc "Switch to 5th workspace"   "5"   #'+workspace/switch-to-4
        :desc "Switch to 6th workspace"   "6"   #'+workspace/switch-to-5
        :desc "Switch to 7th workspace"   "7"   #'+workspace/switch-to-6
        :desc "Switch to 8th workspace"   "8"   #'+workspace/switch-to-7
        :desc "Switch to 9th workspace"   "9"   #'+workspace/switch-to-8
        :desc "Switch to final workspace" "0"   #'+workspace/switch-to-final)))
