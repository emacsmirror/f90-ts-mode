;;; f90-ts-nav.el --- Navigation tree for f90-ts-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2025-2026 Martin Stein

;; Author: Martin Stein <mscfd@gmx.net>
;; Maintainer: Martin Stein <mscfd@gmx.net>
;; URL: https://github.com/mscfd/emacs-f90-ts-mode
;; Keywords: languages, treesitter, fortran
;; Version: 0.4.0-snapshot
;; Package-Requires: ((emacs "29.1"))

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; Experimental navigation buffer based on an induced sparse tree.
;; This was useful during early development, but not be worth keeping,
;; once outline and fold tools are available?

;;; Code:

(require 'cl-lib)
(require 'treesit)

;; hl-line is used for the navigation buffer
(require 'hl-line)

;; defface and defcustom stuff
(require 'f90-ts-custom)

;; provide workarounds and missing functions for Emacs 29
(require 'f90-ts-workaround)

(require 'f90-ts-mode)


;;;-----------------------------------------------------------------------------

(defgroup f90-ts-nav nil
  "Navigation options used by `f90-ts-mode'."
  :prefix "f90-ts-"
  :group  'f90-ts)


;;;-----------------------------------------------------------------------------

(defface f90-ts-nav-procedure-face
  '((t :inherit font-lock-function-name-face :weight bold))
  "Face for subroutine, function, and interface entries in navigation buffer."
  :group 'f90-ts-nav)


(defface f90-ts-nav-type-face
  '((t :inherit font-lock-type-face :weight bold))
  "Face for type entries in navigation buffer."
  :group 'f90-ts-nav)


(defface f90-ts-nav-module-face
  '((t :inherit font-lock-function-name-face :weight bold))
  "Face for module, submodule, program entries in navigation buffer."
  :group 'f90-ts-nav)


(defface f90-ts-nav-variable-face
  '((t :inherit default))
  "Face for variable entries in navigation buffer."
  :group 'f90-ts-nav)


(defcustom f90-ts-nav-buffer-auto-sync t
  "If non-nil the point in the nav buffer follows point in the source buffer."
  :type 'boolean
  :safe  #'booleanp
  :group 'f90-ts-nav)


(defcustom f90-ts-nav-buffer-idle-delay 1.0
  "Seconds of idle time before the nav buffer is automatically refreshed."
  :type 'number
  :safe (lambda (x) (and (numberp x) (> x 0)))
  :group 'f90-ts-nav)


(defcustom f90-ts-nav-buffer-width 40
  "Width of navigation buffer."
  :type 'integer
  :safe (lambda (x) (and (integerp x) (> x 0)))
  :group 'f90-ts-nav)


(defcustom f90-ts-menu-show-navigate t
  "Show navigate submenu in fortran menu if non-nil.
For large source files, the menu might not be useful and reduce performance."
  :type  'boolean
  :safe  #'booleanp
  :group 'f90-ts-nav)


;;;-----------------------------------------------------------------------------

(defconst f90-ts--nav-faces
  '(("program"                  :face f90-ts-nav-module-face)
    ("module"                   :face f90-ts-nav-module-face)
    ("submodule"                :face f90-ts-nav-module-face)
    ("subroutine"               :face f90-ts-nav-procedure-face)
    ("function"                 :face f90-ts-nav-procedure-face)
    ("module_procedure"         :face f90-ts-nav-procedure-face)
    ("derived_type_definition"  :face f90-ts-nav-type-face)
    ("interface"                :face f90-ts-nav-procedure-face)
    ("variable_declaration"     :face f90-ts-nav-variable-face))
  "Face lookup by type key.
This complements `f90-ts--nav-queries'.")


(defun f90-ts--nav-entry-label (key name)
  "Return the display label string for KEY and NAME.
KEY is a symbol from `f90-ts--nav-queries'.  NAME is the identifier or name
of the entry.
The base label is looked up via :label in the query plist.  If NAME is
non-nil and non-empty it is appended as \"LABEL: NAME\"."
  (let* ((plist (alist-get key f90-ts--nav-queries))
         (label-base (plist-get plist :label)))
    (if (and name (not (string-empty-p name)))
        (format "%s: %s" label-base name)
      label-base)))


(defun f90-ts--nav-entry-face (key)
  "Return the face for KEY stored in `f90-ts--nav-faces'.
If no :face property is present, return `f90-ts-nav-variable-face' as default."
  (or (plist-get (alist-get key f90-ts--nav-faces) :face)
      'f90-ts-nav-variable-face))

;;;-----------------------------------------------------------------------------
;;; Navigation tree builder (for use with fortran easy-menu and navigation buffer)
;;; (this mirrors imenu, but it is recursively constructed)

(defvar-local f90-ts--nav-tree-cache-root nil
  "The treesit root node at the time of the last navigation tree build.
Used to verify via `treesit-node-eq' whether the cache is still valid.")


(defvar-local f90-ts--nav-tree-cache nil
  "The last generated sparse navigation tree.")


(defconst f90-ts--nav-tree-query-compiled
  (let ((query-string
         (mapconcat
          (lambda (entry)
            (let ((query (plist-get (cdr entry) :query)))
              ;; wrap each original nav query with @struct on the outer form
              ;; Example:
              ;;   (subroutine (...) @name_subroutine)
              ;; becomes:
              ;;   ((subroutine (...) @name_subroutine) @struct)
              (concat "(" query " @struct)")))
          f90-ts--nav-queries
          "\n")))
    (treesit-query-compile 'fortran query-string))
  "Pre-compiled Tree-sitter query for menu generation with struct captures.")


(defun f90-ts--nav-tree-combine-captures (captures)
  "Pair consecutive (struct name struct name ...) in CAPTURES.
Return a list of triples (name-type struct-node name-node) where name-type
is capture symbol of name and nodes are captured node of struct and name.

In general the captures have exactly one name for a struct.  But in some cases,
it might be possible that there is zero, one or more name captures in the list.
Return a triple for each (struct name_i) pair with name_i being one of the name
nodes after struct."
  (let ((groups (mapcar #'nreverse
                        (nreverse (cl-reduce
                                   (lambda (acc cap)
                                     (if (eq (car cap) 'struct)
                                         (push (list cap) acc) ; build new struct sublist
                                       (setcar acc (cons cap (car acc)))
                                       acc))
                                   captures
                                   :initial-value nil)))))

    (cl-mapcan (lambda (group)
                 (let ((struct-node (cdar group))
                       (names (cdr group)))
                   (cl-loop for (cap-sym . name-node) in names
                            collect (list cap-sym struct-node name-node))))
               groups)))


(defun f90-ts--nav-tree-node-hash-fn (node)
  "Hash function for NODE using its start position."
  (treesit-node-start node))


(define-hash-table-test 'f90-ts--nav-tree-node-hash-test
  #'treesit-node-eq
  #'f90-ts--nav-tree-node-hash-fn)


(defun f90-ts--nav-tree-node-table (root)
  "Capture all menu nodes under ROOT in one pass using name-struct pairing.
Return a hash table mapping each struct node to a list of (KEY NAME POS)
triples, where KEY is a type name from `f90-ts--nav-queries'."
  (let* ((captures (treesit-query-capture root f90-ts--nav-tree-query-compiled))
         (entities (f90-ts--nav-tree-combine-captures captures))
         (table (make-hash-table :test 'f90-ts--nav-tree-node-hash-test)))
    (cl-loop
     for (cap-sym struct-node name-node) in entities
     for key = (alist-get cap-sym f90-ts--nav-capture-key-alist)
     do (progn
          (cl-assert key nil "key is nil for capture-symbol = %s, struct = %s, name = %s"
                     cap-sym struct-node name-node)
          (cl-pushnew
           (list key
                 (treesit-node-text name-node t)
                 (treesit-node-start name-node))
           (gethash struct-node table)
           :test #'equal)))
    (maphash (lambda (k v) (puthash k (nreverse v) table)) table)
    table))


(defun f90-ts--nav-tree-predicate (node-table)
  "Return a predicate that accepts nodes present in NODE-TABLE."
  (lambda (node)
    (gethash node node-table)))


(defun f90-ts--nav-tree-process-fn (node-table)
  "Return a PROCESS-FN for `treesit-induce-sparse-node' for navigate menu.
The returned process function replaces a raw node with its entry list
from NODE-TABLE."
  (lambda (node)
    (gethash node node-table)))


(defun f90-ts--nav-tree-build ()
  "Build the sparse navigation tree for the current buffer.
If the cached tree is still valid, return this.
Otherwise build the tree and cache it along with its root node in
`f90-ts--nav-tree-cache' and `f90-ts--nav-tree-cache-root'.

A sparse node in the tree is a pair (ENTRIES . CHILDREN),
where ENTRIES is a list of triples (KEY NAME POS) as produced by
`f90-ts--nav-tree-node-table'.  CHILDREN is a list of sparse nodes
which are children of the sparse node.
If a sparse node has children, then ENTRIES should contain at most one triple.
For example, the root node usually is not interesting itself but has a list of
children, so ENTRIES=nil but CHILDREN is non-empty."
  (let ((root (treesit-buffer-root-node)))
    (if (and f90-ts--nav-tree-cache-root
             f90-ts--nav-tree-cache
             (treesit-node-eq root f90-ts--nav-tree-cache-root)
             (not (treesit-node-check f90-ts--nav-tree-cache-root 'outdated)))
        f90-ts--nav-tree-cache
      (let* ((node-table  (f90-ts--nav-tree-node-table root))
             (sparse-tree (treesit-induce-sparse-tree
                           root
                           (f90-ts--nav-tree-predicate node-table)
                           (f90-ts--nav-tree-process-fn node-table))))
        (setq f90-ts--nav-tree-cache-root root)
        (setq f90-ts--nav-tree-cache      sparse-tree)
        sparse-tree))))


;;;-----------------------------------------------------------------------------
;;; Easy-menu renderer from navigation tree

(defun f90-ts--nav-menu-entry (label marker)
  "Return a clickable easy-menu vector for LABEL jumping to MARKER."
  (vector label
          (lambda ()
            (interactive)
            (switch-to-buffer (marker-buffer marker))
            (goto-char marker)
            (push-mark))
          t))


(defun f90-ts--nav-menu-from-leaf (entry)
  "Build a `f90-ts--nav-menu-entry' from ENTRY=(KEY NAME POS)."
  (let* ((key    (nth 0 entry))
         (name   (nth 1 entry))
         (pos    (nth 2 entry))
         (label  (f90-ts--nav-entry-label key name))
         (marker (set-marker (make-marker) pos)))
    (f90-ts--nav-menu-entry label marker)))


(defun f90-ts--nav-menu-from-branch (entries children)
  "Build two `f90-ts--nav-menu-entry' items from a sparse node and its CHILDREN.
ENTRIES contains exactly one triple for a non-leaf structure."
  (let* ((first  (car entries))
         (key    (nth 0 first))
         (name   (nth 1 first))
         (pos    (nth 2 first))
         (label  (f90-ts--nav-entry-label key name))
         (marker (set-marker (make-marker) pos)))
    (list
     (f90-ts--nav-menu-entry label marker)
     (cons "[+]"
           (cl-mapcan #'f90-ts--nav-menu-from-sparse-tree children)))))


(defun f90-ts--nav-menu-from-sparse-tree (sparse-node)
  "Recursively convert SPARSE-NODE to easy-menu format.
SPARSE-NODE is a pair (ENTRIES . CHILDREN), where ENTRIES is produced by
`f90-ts--nav-tree-node-table' and CHILDREN are children of SPARSE-NODE,
and itself SPARSE-NODES."
  (let* ((entries  (car sparse-node))
         (children (cdr sparse-node)))
    (cond
     ;; root sentinel (root of a sparse tree, which usually is a forest
     ;; rather than a tree), just walk the forest
     ((null entries)
      (cl-mapcan #'f90-ts--nav-menu-from-sparse-tree children))

     ;; leaf node (either something like a variable declaration or
     ;; some structure without sub-nodes like an empty subroutine body).
     ((null children)
      (mapcar #'f90-ts--nav-menu-from-leaf entries))

     ;; a branch, which is a structure contains other interesting items
     ;; (like a subroutine with variable declarations inside it)
     (t
      (f90-ts--nav-menu-from-branch entries children)))))


(defun f90-ts--nav-menu-tree (_current-menu)
  "Return the easy-menu structure for the current buffer."
  (let* ((sparse-tree (f90-ts--nav-tree-build))
         (items       (f90-ts--nav-menu-from-sparse-tree sparse-tree)))
    (cons (f90-ts--nav-menu-entry "Top of buffer" (point-min-marker))
          (or items '(["(empty)" ignore t])))))


;;;-----------------------------------------------------------------------------
;;; Navigation buffer: based on navigation tree

;; TODO:
;; * open a file: nav buffer not switched
;; * mouse actions
;; * show/hide variables
;; * use shortcuts (mod, submod, prog, subr, fun, var, type ifc)
;; * move point (e.g. by helm-projectile-grep and other actions) does not always sync the buffer

(defvar f90-ts--nav-buffer-name "*F90-TS Navigate*"
  "Buffer name for the f90-ts navigation buffer.")


(defvar-local f90-ts--nav-buffer-source nil
  "The Fortran source buffer this nav panel was spawned from.")


(defvar-keymap f90-ts-nav-mode-map
  :doc "Keymap for `f90-ts-nav-mode'."
  "RET" #'f90-ts-nav-buffer-jump
  "SPC" #'f90-ts-nav-buffer-preview
  "n"   #'next-line
  "p"   #'previous-line
  "g"   #'f90-ts-nav-buffer-refresh
  "q"   #'f90-ts-nav-buffer-quit
  "C-g" #'f90-ts-nav-buffer-quit)


;;;-----------------------------------------------------------------------------
;;; Navigation buffer: map sparse tree to navigation buffer tree

(cl-defstruct f90-ts-nav-buffer-node
  "A node in the navigation buffer tree.
KIND is the type string (\"subroutine\", \"module\", …), which serves as a key..
LABEL is the display string.  MARKER points into the source buffer.
CHILDREN is a (possibly empty) list of child nodes."
  kind label marker face children)


(defun f90-ts--nav-buffer-node-from-entry (entry &optional children)
  "Build a `f90-ts-nav-buffer-node' from a (KEY NAME POS) ENTRY and CHILDREN."
  (let* ((key    (nth 0 entry))
         (name   (nth 1 entry))
         (pos    (nth 2 entry))
         (label  (f90-ts--nav-entry-label key name))
         (face   (f90-ts--nav-entry-face key))
         (marker (set-marker (make-marker) pos)))
    (make-f90-ts-nav-buffer-node :kind     key
                                 :label    label
                                 :marker   marker
                                 :face     face
                                 :children (or children '()))))


(defun f90-ts--nav-buffer-from-sparse-tree (sparse-node)
  "Convert SPARSE-NODE into a list of nav tree nodes.
SPARSE-NODE is from `f90-ts--nav-tree-build' and originates in
`f90-ts--nav-tree-node-table'.  It is a pair (ENTRIES . CHILDREN),
where each ENTRY in the list of ENTRIES has the form (KEY NAME POS).
CHILDREN are further sparse nodes of the same shape.

Return a flat list of `f90-ts-nav-buffer-node' structs."
  (let* ((entries  (car sparse-node))
         (children (cdr sparse-node)))
    (cond
     ;; root sentinel: no entries, just walk the forest
     ((null entries)
      (cl-mapcan #'f90-ts--nav-buffer-from-sparse-tree children))

     ;; leaf node: one nav tree node per entry, no children
     ((null children)
      (mapcar #'f90-ts--nav-buffer-node-from-entry entries))

     ;; branch: build the parent node(s) with converted children
     (t
      (let ((child-nodes (cl-mapcan #'f90-ts--nav-buffer-from-sparse-tree children)))
        ;; there should only be exactly one entry for a non-leaf node,
        ;; be defensive: only the first gets the children
        (cons (f90-ts--nav-buffer-node-from-entry (car entries) child-nodes)
              (mapcar #'f90-ts--nav-buffer-node-from-entry (cdr entries))))))))


;;;-----------------------------------------------------------------------------
;;; Navigation buffer: rendering, interaction

(defvar-local f90-ts--nav-buffer-idle-timer nil
  "Idle timer for automatic nav buffer refresh after source edits.")


(defvar-local f90-ts--nav-buffer-last-sync-pos nil
  "Last value of point when nav buffer was synced.
This is used to avoid excessive syncing.")


(defun f90-ts--nav-buffer-render-nodes (nodes depth)
  "Insert NODES at DEPTH into the nav buffer and recurse into children."
  (cl-loop for node in nodes
           for indent = (make-string (* depth 2) ?\s)
           for face   = (f90-ts-nav-buffer-node-face node)
           for text   = (concat indent
                                (propertize (f90-ts-nav-buffer-node-label node)
                                            'face face))
           do (progn
                (insert text)
                (put-text-property (line-beginning-position) (line-end-position)
                                   'f90-ts-nav-marker
                                   (f90-ts-nav-buffer-node-marker node))
                (put-text-property (line-beginning-position) (line-end-position)
                                   'f90-ts-nav-kind
                                   (f90-ts-nav-buffer-node-kind node))
                (insert "\n")
                (f90-ts--nav-buffer-render-nodes
                 (f90-ts-nav-buffer-node-children node) (1+ depth)))))


(defun f90-ts--nav-buffer-render (tree-nodes)
  "Render TREE-NODES into the current navigation buffer."
  (let ((inhibit-read-only t))
    (erase-buffer)
    (f90-ts--nav-buffer-render-nodes tree-nodes 0)
    (goto-char (point-min))))


(defun f90-ts--nav-buffer-marker-at-point ()
  "Return the marker stored on the current line, or nil."
  (get-text-property (line-beginning-position) 'f90-ts-nav-marker))


(defun f90-ts-nav-buffer-jump ()
  "Jump to the entry on the current line and close the nav buffer."
  (interactive)
  (when-let* ((marker (f90-ts--nav-buffer-marker-at-point)))
    (unless (buffer-live-p (marker-buffer marker))
      (user-error "Source buffer no longer live"))
    (pop-to-buffer (marker-buffer marker))
    (goto-char marker)
    (recenter)))


(defun f90-ts-nav-buffer-preview ()
  "Preview the entry at point without leaving the nav buffer."
  (interactive)
  (when-let* ((marker (f90-ts--nav-buffer-marker-at-point)))
    (unless (buffer-live-p (marker-buffer marker))
      (user-error "Source buffer no longer live"))
    (with-selected-window (display-buffer (marker-buffer marker)
                                          '(display-buffer-reuse-window))
      (goto-char marker)
      (recenter)
      (pulse-momentary-highlight-one-line (point)))))


(defun f90-ts--nav-buffer-schedule-refresh ()
  "Schedule a nav buffer refresh.
It is scheduled after `f90-ts-nav-buffer-idle-delay' seconds of the source
buffer being idle."
  (when f90-ts--nav-buffer-idle-timer
    (cancel-timer f90-ts--nav-buffer-idle-timer))
  (setq f90-ts--nav-buffer-idle-timer
        (run-with-idle-timer f90-ts-nav-buffer-idle-delay nil
                             #'f90-ts-nav-buffer-refresh-from-timer
                             (current-buffer))))


(defun f90-ts-nav-buffer-refresh-from-timer (src-buf)
  "Refresh the nav buffer for SRC-BUF if it is still live."
  (when (buffer-live-p src-buf)
    (with-current-buffer src-buf
      (setq f90-ts--nav-tree-cache-root nil)
      (f90-ts-nav-buffer-open))))


(defun f90-ts--nav-buffer-after-change (&rest _)
  "Schedule a nav buffer refresh after a source buffer change."
  (f90-ts--nav-buffer-schedule-refresh))


(defun f90-ts--nav-buffer-associated-line (pos)
  "Return the nav buffer line number of the entry associated with POS.
POS is a buffer position in the source buffer.
Must be called with the nav buffer as current buffer, as it reads
`f90-ts--nav-buffer-source' to resolve line numbers in the source buffer.
Return nil if no suitable entry is found.

For non-variable entries the associated entry is the closest one whose
marker position is <= POS.  For variable entries the marker must be on
the same source line as POS; among those, the entry is selected if POS
is >= the marker position, except for the first variable on the line
which also captures positions before it on that line."
  (let ((assoc-line nil)
        (assoc-mline nil)
        (line (with-current-buffer f90-ts--nav-buffer-source
                (line-number-at-pos pos)))
        (done nil))
    (save-excursion
      (goto-char (point-min))
      (while (and (not (eobp)) (not done))
        (let* ((marker (get-text-property (line-beginning-position) 'f90-ts-nav-marker))
               (kind   (get-text-property (line-beginning-position) 'f90-ts-nav-kind))
               (nav-line (line-number-at-pos))
               (mpos   (and marker
                            (with-current-buffer f90-ts--nav-buffer-source
                              (marker-position marker))))
               (mline  (and mpos
                            (with-current-buffer f90-ts--nav-buffer-source
                              (line-number-at-pos mpos)))))
          (cl-assert marker nil "nav buffer line %s has no marker" nav-line)
          (if (and (> mline line))
              (setq done t)
            (when (or (not (string= kind "variable_declaration"))
                      (and (= mline line) ; only consider variable declarations if on the same line
                           (or (not assoc-line) ; nothing found so far
                               (< assoc-mline mline) ; accept even if pos is before marker pos
                               (<= mpos pos) ; find last variable with marker before point
                               )))
              (setq assoc-line  nav-line
                    assoc-mline mline)))
          (unless done
            (forward-line 1))))
      (or assoc-line
          ;; if assoc-line is nil but there are markers, point is before first marker
          ;; return line number of that first marker entry
          (and (goto-char (point-min))
               (get-text-property (point) 'f90-ts-nav-marker)
               (line-number-at-pos))))))


(defun f90-ts--nav-buffer-sync-now (src-buf pos)
  "Actually perform the nav buffer sync for SRC-BUF at POS."
  (when (buffer-live-p src-buf)
    (let ((nav-buf (get-buffer f90-ts--nav-buffer-name)))
      (when (and nav-buf
                 (buffer-live-p nav-buf)
                 (get-buffer-window nav-buf))
        (with-current-buffer nav-buf
          (when-let* ((assoc-line (f90-ts--nav-buffer-associated-line pos)))
            (goto-char (point-min))
            (forward-line (1- assoc-line))
            (when-let* ((nav-win (get-buffer-window nav-buf)))
              (set-window-point nav-win (point))
              (with-selected-window nav-win
                (recenter)
                (hl-line-highlight)))))))))


(defun f90-ts--nav-buffer-sync ()
  "Schedule a nav buffer sync via idle timer."
  (when f90-ts-nav-buffer-auto-sync
    (when f90-ts--nav-buffer-idle-timer
      (cancel-timer f90-ts--nav-buffer-idle-timer))
    (setq f90-ts--nav-buffer-idle-timer
          (run-with-idle-timer f90-ts-nav-buffer-idle-delay
                               nil #'f90-ts--nav-buffer-sync-now
                               (current-buffer) (point)))))


(defun f90-ts--nav-buffer-follow-source (_frame)
  "Re-render the nav buffer when focus is moved to a different f90-ts buffer."
  (let ((nav-buf (get-buffer f90-ts--nav-buffer-name)))
    (when (and nav-buf
               (buffer-live-p nav-buf)
               (derived-mode-p 'f90-ts-mode)
               (not (eq (current-buffer)
                        (buffer-local-value 'f90-ts--nav-buffer-source
                                            nav-buf))))
      (f90-ts-nav-buffer-open))))


(defun f90-ts--nav-buffer-add-hooks ()
  "Install the hooks for sync and idle refresh timer.
This is done for the current f90-ts source buffer."
  (add-hook 'post-command-hook #'f90-ts--nav-buffer-sync nil t)
  (add-hook 'after-change-functions
            #'f90-ts--nav-buffer-after-change nil t))


(defun f90-ts-nav-buffer-refresh ()
  "Rebuild the nav buffer from the source buffer."
  (interactive)
  (let ((src (or f90-ts--nav-buffer-source
                 (user-error "Not linked to a F90-TS source buffer"))))
    (unless (buffer-live-p src)
      (user-error "Linked source buffer no longer live"))
    (with-current-buffer src
      ;; invalidate the shared cache
      (setq f90-ts--nav-tree-cache-root nil)
      (f90-ts-nav-buffer-open))))


(define-derived-mode f90-ts-nav-mode special-mode "F90-TS-Nav"
  "Major mode for the F90 navigation side-panel."
  :keymap f90-ts-nav-mode-map
  (setq truncate-lines t)
  (hl-line-mode 1))


;;;###autoload
(defun f90-ts-nav-buffer-open ()
  "Open (or refresh) the F90 navigation side-panel for the current buffer."
  (interactive)

  (when (not (derived-mode-p 'f90-ts-mode))
    (user-error "Not a F90-TS source buffer, navigation buffer not available"))

  (let* ((src-buf (current-buffer))
         (sparse (f90-ts--nav-tree-build))
         (tree-nodes (f90-ts--nav-buffer-from-sparse-tree sparse))
         (nav-buf (get-buffer-create f90-ts--nav-buffer-name)))
    (with-current-buffer nav-buf
      ;; only on first creation, otherwise defvar-local variables are deleted
      (unless (derived-mode-p 'f90-ts-nav-mode)
        (f90-ts-nav-mode))
      (setq f90-ts--nav-buffer-source src-buf)
      (f90-ts--nav-buffer-render tree-nodes))
    (let ((win (display-buffer
                nav-buf
                '(display-buffer-in-side-window
                  (side . left)))))
      (when (window-live-p win)
        (window-resize win
                       (- f90-ts-nav-buffer-width
                          (window-total-width win))
                       t)))
    (with-selected-window (get-buffer-window nav-buf)
      (hl-line-highlight))
    (f90-ts--nav-buffer-add-hooks)
    ;; add hook for automatic nav buffer switching
    (add-hook 'window-buffer-change-functions
              #'f90-ts--nav-buffer-follow-source)))


;;;###autoload
(defun f90-ts-nav-buffer-focus ()
  "Focus the navigation side buffer, opening it first if necessary."
  (interactive)
  (unless (get-buffer f90-ts--nav-buffer-name)
    (f90-ts-nav-buffer-open))
  (when-let* ((nav-win (get-buffer-window f90-ts--nav-buffer-name)))
    (select-window nav-win)))


(defun f90-ts-nav-buffer-quit ()
  "Quit the nav buffer."
  (interactive)
  (remove-hook 'window-buffer-change-functions
               #'f90-ts--nav-buffer-follow-source)
  (quit-window))


(easy-menu-define f90-ts-nav-mode-menu f90-ts-nav-mode-map
  "Menu for the F90 navigation side buffer."
  '("F90-TS-Nav"
    ["Jump to entry"    f90-ts-nav-buffer-jump    :active t]
    ["Preview entry"    f90-ts-nav-buffer-preview :active t]
    "---"
    ["Refresh"          f90-ts-nav-buffer-refresh :active t]
    "---"
    ["Quit"             f90-ts-nav-buffer-quit    :active t]))

;;;-----------------------------------------------------------------------------

(easy-menu-add-item f90-ts-mode-menu nil
  '("Navigation tree"
    :visible f90-ts-menu-show-navigate
    :filter  (lambda (menu) (f90-ts--nav-menu-tree menu))))


;;;-----------------------------------------------------------------------------

(provide 'f90-ts-nav)

;;; f90-ts-nav.el ends here
