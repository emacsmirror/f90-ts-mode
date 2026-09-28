;;; f90-ts-mode.el --- Tree-sitter based Fortran 90 mode -*- lexical-binding: t; -*-

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

;; f90-ts-mode is a major mode for editing Fortran 90/2003 (and newer) source
;; files, based on Emacs's built-in tree-sitter support (requires Emacs 29+)
;;
;; Changelog:
;; [09-2026]
;;   - `f90-ts-mode.el' decomposed into several smaller packages.  Experimental
;;     `f90-ts-nav' (tree in fortran menu and tree view in side panel) has been
;;     made optional and requires a separate use-package to load it,
;;     see `README.md'.
;;   - `f90-ts-indent-delete-trailing-whitespace' added to automatically delete
;;     trailing whitespace after indentation operation.
;;   - Font locking of interface name in deferred procedure declaration fixed.
;;   - Trimming of trailing whitespace characters in thing-end-of-X navigation
;;     added.
;;   - Support for Emacs 29 + tree-sitter 0.20.x added (tested with 29.1, 29.3
;;     and tree-sitter 0.20.8).
;;   - Fontification of error nodes fixed if line limitting is enabled.
;;   - Some issues in comment-region operations fixed (preserve indentation,
;;     preserve trailing whitespace where possible, keep existing alignment
;;     with keep options, do not operate outside of region boundaries, add
;;     missing function `f90-ts-indent-region').
;;   - Indentation after uncommenting lines in comment-region operation on
;;     commented lines of code containing leading ampersand or statement label
;;     fixed.
;;   - Missing option `keep-or-continued-line' added to
;;     `f90-ts--indent-options-alist' for indentation selection options.
;;   - Syntax highlighting, indentation and break/join/fill for string literals
;;     improved.  This requires a proposed (but not yet merged) tree-sitter
;;     language grammar extension.  See README.md for more details.
;;   - Testing with Emacs 31.1 and tree-sitter 0.26 added.
;;
;; [08-2026]
;;   - `f90-ts-shift-line-break' as combined break/join function added.
;;   - Defcustom `f90-ts-font-lock-error` replaced by
;;     `f90-ts-font-lock-error-show'.  Errors are now always fontified by
;;     `f90-ts-font-lock-error-face'.  The new defcustom
;;     `f90-ts-font-lock-error-show' can be used to turn ERROR node
;;     highlighting on and off, or the number of lines to be highlighted for
;;     each ERROR node.
;;   - Jump-to-rightmost-position (within fill-column) to the interactive fill
;;     operation added.
;;   - Mark region operations fixed: always consider trimmed region of nodes.
;;     Some nodes like a whole "subroutine..end subroutine" block contains a
;;     trailing newline, which should not be considered.  Not consequently
;;     trimming all spans broke some mark region operations.
;;   - About, README and MANUAL entries in the fortran and transient popup menu
;;     to view information about the mode added.
;;   - Additional font-locking for error regions added.  This can be customized
;;     by `f90-ts-font-lock-error' and `f90-ts-font-lock-error-face'.
;;   - Smart end completion of coarray "change team ... end team" blocks fixed.
;;     It was wrongly assumed that the end statement is "end change team".
;;
;; [07-2026]
;;   - Inherit attribute of some font lock faces fixed.
;;   - Alignment of unary expressions with leading minus or plus improved.
;;
;; Features:
;;   - Almost all statements up to F2023
;;   - Syntax highlighting, including syntactically incorrect code
;;   - Indentation of lines, regions, multiline statements and structure blocks
;;   - Alignment for multiline statements with rotation and other options
;;   - Smart end completion
;;   - Configurable leading ampersand and statement label positions
;;   - Breaking and joining of continued lines
;;   - Fill and rebalance operations for lines or regions (with rightmost
;;     breakpoint selection or interactive break and join session)
;;   - Region selection based on tree-sitter nodes
;;   - (Un)commenting regions with configurable prefixes and indentation rules
;;   - Special comments like doc strings and separators
;;     (syntax highlighting and indentation options)
;;   - Keyword highlighting in comments (like TODO, Remark etc.)
;;   - OpenMP and preprocessor directives
;;   - Coarray keywords and statements
;;   - Imenu and a Fortran menu in the menu bar
;;   - Navigation (defun, things, Xref, side panel tree)
;;
;; Features can be found by the fortran menu or a transient popup bound
;; to the key C-c C-f.
;;
;; Installation requires the tree-sitter Fortran grammar, which can be found at
;;   https://github.com/stadelmanma/tree-sitter-fortran
;;
;; Basic setup with use-package:
;;
;;   (use-package f90-ts-mode
;;     :mode ("\\.f90\\'" . f90-ts-mode))
;;
;; See the README and MANUAL at https://github.com/mscfd/emacs-f90-ts-mode
;; for full documentation on options, keybindings, etc.
;;
;; Bugs and features:
;;   https://github.com/mscfd/emacs-f90-ts-mode/issues
;;
;; Notes:
;; - Emacs 31 supports 0.26, and the mode runs in both configurations.
;; - Emacs 30.x must be linked against tree-sitter 0.25.x at runtime.
;; - Emacs 29 support has been tested with treesitter 0.20.8.
;; For details see MANUAL at https://github.com/mscfd/emacs-f90-ts-mode

;;; Code:

(require 'cl-lib)
(require 'treesit)
(require 'xref)
(require 'transient)

;; for loading online README and MANUAL
(require 'url)

;; defface and defcustom stuff
(require 'f90-ts-custom)

;; provide workarounds and missing functions for Emacs 29
(require 'f90-ts-workaround)

;; auxiliary stuff
(require 'f90-ts-auxiliary)

;; font locking rules
(require 'f90-ts-font-lock)

;; indentation rules and functions
(require 'f90-ts-indent)


;;;-----------------------------------------------------------------------------

(defconst f90-ts-mode-version "0.4.0-snapshot"
  "Version of `f90-ts-mode'.")


(defconst f90-ts--github-url
  "https://github.com/mscfd/emacs-f90-ts-mode")


(defconst f90-ts--about-text
  "f90-ts-mode is a major mode for editing Fortran 90/2003 (and newer)
source files, based on Emacs's built-in tree-sitter support
(requires Emacs 29+).

Changelog:

[09-2026]
- `f90-ts-mode.el' decomposed into several smaller packages. Experimental
  `f90-ts-nav' (tree in fortran menu and tree view in side panel) has been
  made optional and requires a separate use-package to load it,
  see `README.md'.
- `f90-ts-indent-delete-trailing-whitespace' added to automatically delete
  trailing whitespace after indentation operation.
- Font locking of interface name in deferred procedure declaration fixed.
- Handling of trailing whitespace characters in thing-end-of-X navigation added.
- Support for Emacs 29 + tree-sitter 0.20.x added (tested with 29.1, 29.3 and
  tree-sitter 0.20.8).
- Fontification of error nodes fixed if line limitting is enabled.
- Some issues in comment-region operations fixed (preserve indentation,
  preserve trailing whitespace where possible, keep existing alignment
  with keep options, do not operate outside of region boundaries, add
  missing function `f90-ts-indent-region').
- Indentation after uncommenting lines in comment-region operation on
  commented lines of code containing leading ampersand or statement label fixed.
- Missing option `keep-or-continued-line' added to
  `f90-ts--indent-options-alist' for indentation selection options.
- Improve syntax highlighting, indentation and break/join/fill for string
  literals.  This requires a proposed (but not yet merged) tree-sitter
  language grammar extension.  See README.md for more details.
- Testing with emacs 31.1 and tree-sitter 0.26 added.

[08-2026]
- `f90-ts-shift-line-break' as combined break/join function added.
- Defcustom `f90-ts-font-lock-error' replaced by `f90-ts-font-lock-error-show'.
  Errors are now always fontified by f90-ts-font-lock-error-face.
  The new defcustom `f90-ts-font-lock-error-show' can be used to turn ERROR
  node highlighting on and off, or the number of lines to be highlighted for
  each ERROR node.
- Jump-to-rightmost-position (within fill-column) to the interactive
  fill operation added.
- Mark region operations fixed: always consider trimmed region
  of nodes. Some nodes like a whole \"subroutine..end subroutine\"
  block contains a trailing newline, which should not be
  considered. Not consequently trimming all spans broke some mark
  region operations.
- About, README and MANUAL entries in the fortran and transient
  popup menu to view information about the mode added.
- Additional font-locking for error regions added.  This can be
  customized by `f90-ts-font-lock-error' and
  `f90-ts-font-lock-error-face'.
- Smart end completion of coarray \"change team ... end team\"
  blocks fixed.  It was wrongly assumed that the end statement is
  \"end change team\".

[07-2026]
- Inherit attribute of some font-lock faces fixed.
- Alignment of unary expressions with leading minus or plus improved.
")


;;;-----------------------------------------------------------------------------
;;; syntax table

(defvar f90-ts-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; --- symbols and words ---
    ;; '_' is a symbol constituent in Fortran
    (modify-syntax-entry ?_ "_" table)

    ;; --- string delimiters ---
    (modify-syntax-entry ?\" "\"" table)
    (modify-syntax-entry ?\' "\"" table)

    ;; --- comments ---
    ;; '!' starts a comment. '<' means start, 'b' means it's a
    ;; "Style B" comment (standard for line-based comments).
    (modify-syntax-entry ?! "< b" table)
    ;; newline ends the comment. '>' means end.
    (modify-syntax-entry ?\n "> b" table)

    ;; delimiters, newline, continuation
    (modify-syntax-entry ?\r " "  table) ; return is whitespace
    (modify-syntax-entry ?&  "."  table) ; continuation line
    (modify-syntax-entry ?%  "."  table) ; component reference

    ;; --- Arithmetic/Logic Punctuation ---
    (modify-syntax-entry ?+ "." table)
    (modify-syntax-entry ?- "." table)
    (modify-syntax-entry ?* "." table)
    (modify-syntax-entry ?/ "." table)
    (modify-syntax-entry ?= "." table)
    (modify-syntax-entry ?< "." table)
    (modify-syntax-entry ?> "." table)
    (modify-syntax-entry ?. "." table)  ; this is difficult, as dot in ".and." for example
                                        ; should belong to the symbol class and not punctuation,
                                        ; but having this as symbol would interfer with for example
                                        ; "this_flag.and.other_flag", appearing as one big symbol,
                                        ; likewise it could be difficult with floating point numbers?

    table)
  "Syntax table for `f90-ts-mode'.")


;;;-----------------------------------------------------------------------------
;;; keymap

(defvar-keymap f90-ts-mode-map
  :doc "Keymap for `f90-ts-mode'."
  ;; TAB commands
  "C-<tab>"           #'f90-ts-indent-and-complete-stmt
  "<backtab>"         #'f90-ts-indent-for-tab-command-2 ; S-<tab>
  "C-S-<iso-lefttab>" #'f90-ts-indent-for-tab-command-3 ; Linux
  "C-<backtab>"       #'f90-ts-indent-for-tab-command-3 ; Windows?

  ;; other keybindings inspired by f90-mode
  "C-<return>" #'f90-ts-break-line
  "C-c ;"      #'f90-ts-comment-region-default
  "C-c '"      #'f90-ts-comment-region-custom

  ;; C-c C-f prefix for the transient menu
  "C-c C-f" #'f90-ts-transient)


;;;-----------------------------------------------------------------------------
;;; transient

(transient-define-infix f90-ts-transient--indent-list-line ()
  "Transient infix for indent-line alignment variant."
  :class    'transient-lisp-variable
  :variable 'f90-ts-indent-list-line
  :prompt   "Indent list line method: "
  :reader   (lambda (prompt initial _history)
              (let* ((choice (completing-read
                               prompt
                               f90-ts--indent-options-alist
                               nil t nil nil
                               (car (rassq initial f90-ts--indent-options-alist)))))
                (cdr (assoc choice f90-ts--indent-options-alist)))))


(transient-define-infix f90-ts-transient--fill-column ()
  "Transient infix for fill column override."
  :class    'transient-lisp-variable
  :variable 'fill-column
  :prompt   "Fill column: "
  :reader   (lambda (prompt initial _history)
               (read-number prompt initial)))


(transient-define-suffix f90-ts-transient--fill-select-breakpoint-by ()
  "Toggle breakpoint selection between `rightmost' and `interactive'."
  :transient t
  :description (lambda ()
                 (concat "Fill column select by: "
                         (propertize (symbol-name f90-ts-fill-select-breakpoint-by)
                                     'face 'transient-value)))
  (interactive)
  (setq f90-ts-fill-select-breakpoint-by
        (if (eq f90-ts-fill-select-breakpoint-by 'interactive)
            'rightmost
          'interactive)))


(transient-define-prefix f90-ts-transient ()
  "F90 Tree-sitter Mode."
  ;; Modify
  [["Indentation, break & join"
    ("L"     "Indent list line:"          f90-ts-transient--indent-list-line)
    ("TAB"   "Indent & comlete line"      f90-ts-indent-and-complete-line)
    ("s"     "Indent & complete stmt"     f90-ts-indent-and-complete-stmt)
    ("I"     "Indent & complete region"   f90-ts-indent-and-complete-region)
    ("C-TAB" "Indent line"                f90-ts-indent-line)
    ("C-I"   "Indent region"              f90-ts-indent-region)
    ("b"     "Break line"                 f90-ts-break-line)
    ("j"     "Join with previous line"    f90-ts-join-line-prev)
    ("J"     "Join with next line"        f90-ts-join-line-next)
    ("C-s"   "Shift line break"           f90-ts-shift-line-break)]
   ["Mark and (un)comment region"
    ("r"   "Enlarge"                    f90-ts-mark-region-enlarge)
    ("0"   "Shrink to first child"      f90-ts-mark-region-shrink-child-first)
    ("9"   "Shrink to last child"       f90-ts-mark-region-shrink-child-last)
    ("{"   "First sibling"              f90-ts-mark-region-first-sibling)
    ("["   "Previous sibling"           f90-ts-mark-region-prev-sibling)
    ("]"   "Next sibling"               f90-ts-mark-region-next-sibling)
    ("}"   "Last sibling"               f90-ts-mark-region-last-sibling)
    ("X"   "Exchange point and mark"    exchange-point-and-mark)
    ("c"   "Comment region (default)"   f90-ts-comment-region-default)
    ("C"   "Comment region (custom)"    f90-ts-comment-region-custom)]
   ["Fill/Rebalance"
    ("C-f" "Fill column:"               f90-ts-transient--fill-column)
    ("C-b"                              f90-ts-transient--fill-select-breakpoint-by) ; text is in description slot
    ("f"   "Fill region/buffer"         f90-ts-fill-region)
    ("M-f" "Fill at line"               f90-ts-fill-at-line)
    ("M-j" "Fill with prev line"        f90-ts-fill-prev-line)
    ("M-J" "Fill with next line"        f90-ts-fill-next-line)]]

  ;; Navigate
  [["Procedure"
    ("a"   "Beginning"                  f90-ts-thing-beginning-of-procedure)
    ("e"   "End"                        f90-ts-thing-end-of-procedure)
    ("p"   "Previous"                   f90-ts-thing-prev-procedure)
    ("n"   "Next"                       f90-ts-thing-next-procedure)]
   ["Derived Type"
    ("M-a" "Beginning"                  f90-ts-thing-beginning-of-type)
    ("M-e" "End"                        f90-ts-thing-end-of-type)
    ("M-p" "Previous"                   f90-ts-thing-prev-type)
    ("M-n" "Next"                       f90-ts-thing-next-type)]
  ["Interface"
    ("C-M-a" "Beginning"                f90-ts-thing-beginning-of-interface)
    ("C-M-e" "End"                      f90-ts-thing-end-of-interface)
    ("C-M-p" "Previous"                 f90-ts-thing-prev-interface)
    ("C-M-n" "Next"                     f90-ts-thing-next-interface)]]

  [["Xref"
    ("."   "Find definition"            xref-find-definitions)
    (","   "Find references"            xref-find-references)
    ("/"   "Find apropos"               xref-find-apropos)
    ("<"   "Go back"                    xref-go-back)
    (">"   "Go forward"                 xref-go-forward)]
   ["Side panel (alpha!)"
    :if (lambda () (featurep 'f90-ts-nav))
    ("B"   "Open nav buffer"            f90-ts-nav-buffer-open)
    ("F"   "Focus nav buffer"           f90-ts-nav-buffer-focus)]
   ["About & Doc"
    ("C-h a" "About"                    f90-ts-mode-about)
    ("C-h r" "README"                   f90-ts--browse-readme)
    ("C-h m" "MANUAL"                   f90-ts--browse-manual)]])


;;;-----------------------------------------------------------------------------
;;; Xref backend

(defconst f90-ts--xref-def-query
  "(program (program_statement (name) @def))
   (module (module_statement (name) @def))
   (submodule (submodule_statement (name) @def))
   (subroutine (subroutine_statement name: (name) @def))
   (function (function_statement name: (name) @def))
   (module_procedure_statement name: (name) @def)
   (interface_statement (name) @def)
   (interface_statement (operator (operator_name) @def))
   (interface_statement (assignment \"=\" @def))
   (derived_type_definition (derived_type_statement (type_name) @def))
   (preproc_def name: (identifier) @def)
   (preproc_function_def name: (identifier) @def)"
  "Query for xref for finding definitions of symbol captured as @def.

Each clause matches a syntactic construct that introduces a named
entity (e.g. subroutine, function, module, derived type, or macro)
and binds the relevant node to the capture name @def.

The resulting captures are consumed by
`f90-ts--xref-find-definitions' to locate definition positions.")

(defconst f90-ts--xref-ref-query
  "[(identifier)
    (name)
    (type_name)
    (type_member)
    (method_name)
    (operator_name)
    (user_defined_operator)
    (procedure_interface)
   ] @ref"
  "Query for xref for finding references of symbols captured by @ref.

The query is very general and might find incorrect references.  There is
also no consideration for the scope of a symbol.")

(defun f90-ts--xref-find-definitions (identifier)
  "Find all definitions of IDENTIFIER in the current buffer.

IDENTIFIER is a string representing the symbol to search for.
The search is case-insensitive, reflecting Fortran's
case-insensitive semantics.

This function:
1. Executes `f90-ts--xref-def-query' against the current buffer's tree-sitter
   syntax tree.
2. Filters captured nodes whose text matches IDENTIFIER.
3. Converts matching nodes into xref-item objects.

Return a list of xref-item instances suitable for consumption by
`xref-backend-definitions'."
  (let* ((id-lowcase (downcase identifier))
         (scope (treesit-buffer-root-node))
         (id-nodes (treesit-query-capture scope
                                          f90-ts--xref-def-query
                                          nil nil t)))
    (cl-loop for node in id-nodes
             when (string= (downcase (treesit-node-text node t)) id-lowcase)
             collect (f90-ts--xref-make-item node))))


(defun f90-ts--xref-find-references (identifier)
  "Find all references to IDENTIFIER in the current buffer.

IDENTIFIER is a string naming the symbol to search for.
The search is case-insensitive.

This function performs a broad tree-sitter query that captures all
identifier nodes, then filters them by textual equality with
IDENTIFIER.

Note that this approach is purely syntactic and does not account
for scope, shadowing, or semantic resolution.

Return a list of xref-item instances suitable for
`xref-backend-references'."
  (let* ((id-lowcase (downcase identifier))
         (scope (treesit-buffer-root-node))
         (id-nodes (treesit-query-capture scope
                                          f90-ts--xref-ref-query
                                          nil nil t)))
    (cl-loop for node in id-nodes
             when (string= (downcase (treesit-node-text node t)) id-lowcase)
             collect (f90-ts--xref-make-item node))))


(defun f90-ts--xref-make-item (node)
  "Construct an xref-item from a tree-sitter NODE.

NODE is expected to represent an identifier or definition site.
The function extracts:

- A human-readable display string consisting of the full line containing NODE.
- A buffer location corresponding to the start of NODE.

The resulting xref-item can be used by xref commands to display and navigate
search results."
  (let ((start (treesit-node-start node)))
    (xref-make
     (save-excursion
       (goto-char start)
       (string-trim (buffer-substring-no-properties
                     (line-beginning-position)
                     (line-end-position))))
     (xref-make-buffer-location (current-buffer) start))))


(cl-defmethod xref-backend-identifier-at-point ((_backend (eql f90-ts)))
  "Return the identifier at point for the f90-ts backend.

This method is invoked by xref to determine the default symbol
under the cursor when performing operations like
`xref-find-definitions'.

It uses `thing-at-point' with the symbol type and returns the
result as a string, or nil if no symbol is found."
  (thing-at-point 'symbol t))


(cl-defmethod xref-backend-identifier-completion-table ((_backend (eql f90-ts)))
  "Return a completion table of identifiers in the current buffer.

This method provides candidates for identifier completion in xref commands.
It collects all identifier nodes from the tree-sitter syntax tree and returns
their textual representations.
Currently only named nodes with type \"identifier\" are captured.

Duplicates are not explicitly removed, so callers may wish to handle
deduplication if necessary."
  (let ((id-nodes (treesit-query-capture
                   (treesit-buffer-root-node)
                   '((identifier) @id)
                   nil nil t)))
    (cl-loop for node in id-nodes
             collect (treesit-node-text node t))))


(cl-defmethod xref-backend-definitions ((_backend (eql f90-ts)) identifier)
  "Return definition locations for IDENTIFIER using the f90-ts backend.

Uses `f90-ts--xref-find-definitions', which performs a buffer-local search for
matching definition nodes."
  (f90-ts--xref-find-definitions identifier))


(cl-defmethod xref-backend-references ((_backend (eql f90-ts)) identifier)
  "Return reference locations for IDENTIFIER using the f90-ts backend.

Uses `f90-ts--xref-find-references', which performs a syntactic search over
identifier nodes in the current buffer."
  (f90-ts--xref-find-references identifier))


(cl-defmethod xref-backend-apropos ((_backend (eql f90-ts)) pattern)
  "Return all identifiers matching regexp PATTERN in the current buffer.

This implementation performs a tree-sitter query over all identifier
nodes and returns those whose textual representation matches PATTERN.

The match is case-insensitive, following Fortran conventions."
  (let ((case-fold-search t))
    (cl-loop for node
             in (treesit-query-capture (treesit-buffer-root-node)
                                       '((identifier) @id)
                                       nil nil t)
             for text = (buffer-substring-no-properties
                         (treesit-node-start node)
                         (treesit-node-end node))
             when (string-match-p pattern text)
             collect (f90-ts--xref-make-item node))))


(defun f90-ts-xref-backend ()
  "Return the symbol identifying the f90-ts xref backend.
Return f90-ts backend unless a higher-level backend is active.

This function is intended to be added to
`xref-backend-functions'.  When invoked by xref's backend
discovery mechanism, it signals that the current buffer should
use the f90-ts backend by returning the symbol f90-ts.

Because this function is typically installed buffer-locally, it
activates the backend only for buffers using `f90-ts-mode'."
  (cond
   ;; prefer LSP and eglot if active
   ((bound-and-true-p lsp-mode) nil)
   ((bound-and-true-p eglot--managed-mode) nil)

   ;; prefer etags if TAGS table exists
   ((and tags-file-name (file-exists-p tags-file-name)) nil)

   ;; otherwise use the backend provided here
   (t 'f90-ts)))


;;;-----------------------------------------------------------------------------
;;; Break lines and add continuation symbol

(defconst f90-ts--join-line-prev-valid-actions
  '(empty-line
    beg-of-buffer
    remove-blank-lines-between
    join-continued-lines
    join-continued-string
    join-comments-same-prefix-trimmed
    join-comments-same-prefix-with-blanks
    append-comment-after-amp
    append-comment-after-stmt)
  "All valid action symbols returned by `f90-ts--join-line-prev-aux'.")


(defconst f90-ts--join-line-next-valid-actions
  '(empty-line
    end-of-buffer
    remove-blank-lines-between
    join-continued-lines
    join-continued-string
    join-comments-same-prefix-trimmed
    join-comments-same-prefix-with-blanks
    append-comment-after-amp
    append-comment-after-stmt)
  "All valid action symbols returned by `f90-ts--join-line-next-aux'.")


(defun f90-ts--break-line-insert-amp-at-end ()
  "If not yet present, insert ampersand at end of line."
  (or (eq (char-before) ?&)
      (insert " &")))


;; Portions of the following code are adapted from `f90.el',
;; which is part of GNU Emacs.
(defun f90-ts-break-line ()
  "Break line at point, insert continuation marker where necessary and indent."
  (interactive "*")
  (cond
   ((f90-ts--bol-to-point-blank-p)
    ;; this results in an empty line, no ampersand
    (delete-horizontal-space)
    (insert "\n"))

   ((f90-ts--in-openmp-p (point))
    ;; looks like a comment, but starting with special "!$" sequence,
    ;; breaking openmp lines requires a continuation symbol
    (let* ((node (treesit-node-at (point)))
           (prefix (f90-ts--comment-prefix node 'with-blanks)))
      (delete-horizontal-space)
      (f90-ts--break-line-insert-amp-at-end)
      (insert "\n" prefix)))

   ((f90-ts--in-comment-p (point))
    (cl-assert (not (f90-ts--in-openmp-p (point))) nil "unexpectedly within openmp comment")
    (let* ((node (treesit-node-at (point)))
           (prefix (f90-ts--comment-prefix node 'with-blanks)))
      (delete-horizontal-space)
      (insert "\n" prefix)))

   ;; comments can be within continued strings, so comments must be checked
   ;; before the in-string predicate (in fac in-comment-p and in-string-p can both be true
   ((f90-ts--in-string-p (point))
    (cl-assert (not (f90-ts--in-comment-p (point))) nil "unexpectedly within comment")
    (if (not (f90-ts--string-literal-decomposed-p))
        ;; old style continued string (this does not handle all cases properly
        (insert "&\n&")
      ;; first determine where point is within string
      (let ((node (treesit-node-on (1- (point)) (point))))
        (if (or (f90-ts--node-type-p node '("string_literal_part"
                                            "\""
                                            "\\"))
                (and (f90-ts--node-type-p node "&")
                     (string= (treesit-node-text node) "&") ; exclude virtual ampersand
                     (= (treesit-node-start node)
                        (f90-ts--pos-first-nonspace (point)))))
            (insert "&\n&")
          ;; point is after a continuation symbol &, delete horizontal space and
          ;; just add an empty line with a leading ampersand
          (delete-horizontal-space)
          (newline 1)
          (insert "&&")
          (backward-char)))))

   (t
    (delete-horizontal-space)
    ;; note that a leading ampersand (depend on f90-ts-leading-ampersand)
    ;; is inserted by the indentation function, and thus does not need to
    ;; be added here
    (f90-ts--break-line-insert-amp-at-end)
    (newline 1)))
  ;; finally indent the new line after insertion of the newline
  (indent-according-to-mode))


(defun f90-ts--join-line-empty-prev ()
  "For point on an empty line, remove all blank lines before point.
After the operation point is after the last character on the non-blank line."
  (cl-assert (f90-ts--point-on-empty-line-p)
             nil "join-line-empty-prev requires point to be on an empty line")
  (let* ((prev (save-excursion
                 (skip-chars-backward " \t\n")
                 (point)))
         (end (line-end-position)))
    (delete-region prev end)))


(defun f90-ts--join-line-empty-next ()
  "For point on an empty line, remove all blank lines after point.
Move point to first character on the line after it was originally placed."
  (cl-assert (f90-ts--point-on-empty-line-p)
             nil "join-line-empty-next requires point to be on an empty line")
  (let* ((next (save-excursion
                 (skip-chars-forward " \t\n")
                 (line-beginning-position)))
         (beg (line-beginning-position)))
    (delete-region beg next)
    (back-to-indentation)))


(defun f90-ts--join-line-string (node pos1 pos2)
  "Join previous line with current line both belonging to a continued string.
Positions POS1 and POS2 are end of previous line and start of current line.

If the grammar variant does not decompose the string_literal, then NODE is
of type string_literal.  For the decomposed variant, NODE is the first
ampersand before POS1 and within the string_literal to be joined."
  (cl-assert (if (f90-ts--string-literal-decomposed-p)
                 (and (f90-ts--node-type-p node '("&" "string_literal_part" "\""))
                      (f90-ts--node-type-p (treesit-node-parent node) "string_literal"))
               (f90-ts--node-type-p node "string_literal"))
             nil "node is not within a string literal")
  (cl-assert (or (not (f90-ts--node-type-p node "&"))
                 (eq (char-before pos1) ?&))
             nil "character before pos1 is not an ampersand")

  (let ((beg (if (eq (char-before pos1) ?&)
                 (1- pos1)
             ;; the continued string is missing the ampersand on the first line,
             ;; we still can safely join, but do not delete blanks after pos1
              (save-excursion
                (goto-char pos1)
                (line-end-position))))
        (end (if (eq (char-after pos2) ?&)
                 (1+ pos2)
               pos2)))
    (delete-region beg end)
    (goto-char beg)))


(defun f90-ts--join-line-action-common (first secnd is-prev)
  "Compute an action pair for joining lines at FIRST and SECND.
The pair (THUNK . ACTION) provides a THUNK to perform the join and an ACTION
symbol describing what is done.

The ACTION symbol is used by the caller to decide whether to execute the thunk,
for example in a `fill-region' loop context.

Argument IS-PREV signals whether the function was called from the
`join-line-prev' or the `join-line-next' function."
  (let ((is-amp-1st     (f90-ts--node-type-p first "&"))
        (is-amp-2nd     (f90-ts--node-type-p secnd "&"))
        (is-comment-1st (f90-ts--node-type-p first "comment"))
        (is-comment-2nd (f90-ts--node-type-p secnd "comment")))
    (cond
     ((and is-amp-1st
           is-amp-2nd)
      (let ((beg (treesit-node-start first))
            (end (treesit-node-end secnd)))
        (cons (lambda ()
                (delete-region beg end)
                (goto-char beg)
                (fixup-whitespace)
                (skip-chars-forward " \t"))
              'join-continued-lines)))

     ((and is-amp-1st
           is-comment-2nd)
      (let ((beg (treesit-node-end first))
            (end (treesit-node-start secnd)))
        (cons (lambda ()
                (delete-region beg end)
                (goto-char beg)
                (insert " "))
              'append-comment-after-amp)))

     ((and is-comment-1st
           is-comment-2nd
           (string= (f90-ts--comment-prefix first 'trimmed)
                    (f90-ts--comment-prefix secnd 'trimmed)))
      (let ((beg (save-excursion
                   (goto-char (treesit-node-end first))
                   (skip-chars-backward " \t")
                   (point)))
            (end (+ (treesit-node-start secnd)
                    (length (f90-ts--comment-prefix secnd 'with-blanks)))))
        (cons (lambda ()
                (delete-region beg end)
                (goto-char beg)
                (insert " "))
              ;; join and fill operation behave differently: do not join in
              ;; fill operation, if indentation is different, so signal whether
              ;; prefixes including blanks or only trimmed
              (if (string= (f90-ts--comment-prefix first 'with-blanks)
                           (f90-ts--comment-prefix secnd 'with-blanks))
                  'join-comments-same-prefix-with-blanks
                'join-comments-same-prefix-trimmed))))

     ((and (null is-comment-1st)
           is-comment-2nd)
      (let ((beg (save-excursion
                   (goto-char (treesit-node-end first))
                   (skip-chars-backward " \t")
                   (point)))
            (end (treesit-node-start secnd)))
        (cons (lambda ()
                (delete-region beg end)
                (goto-char beg)
                (insert " "))
              'append-comment-after-stmt)))

     (t
      (let ((beg (save-excursion
                   (goto-char (treesit-node-end first))
                   (line-beginning-position 2)))
            (end (save-excursion
                   (goto-char (treesit-node-start secnd))
                   (line-beginning-position))))
        (cons (lambda ()
                (delete-region beg end)
                (goto-char beg)
                (if is-prev
                    (skip-chars-forward " \t")
                  (skip-chars-backward " \t\n")))
              'remove-blank-lines-between))))))


(defun f90-ts--join-line-is-cont-str (first secnd)
  "Check whether the join is performed within a continued string literal.
FIRST and SECND are the leaf nodes at the first and second join positions,
which are at end of first and beginning of second line.
The predicate only returns non-nil if FIRST and SECND are ampersand nodes,
without any comments in-between (the non-decomposed grammar variant fails to
parse comments within strings)."
  (if (f90-ts--string-literal-decomposed-p)
      (and (f90-ts--node-type-p first '("&"
                                        ;; these are only posssible within a
                                        ;; malformed continued string without &
                                        "string_literal_part" "\""))
           (f90-ts--node-type-p secnd '("&"
                                        ;; these are only posssible within a
                                        ;; malformed continued string without &
                                        "string_literal_part" "\"" "\\"))
           (f90-ts--node-type-p (treesit-node-parent first) "string_literal"))
    (and (f90-ts--node-type-p first "string_literal")
         (f90-ts--node-type-p secnd "string_literal")
         (treesit-node-eq first secnd))))


(defun f90-ts--join-line-prev-aux ()
  "Join previous line with the current one, if part of a continued statement.
Return a cons (THUNK . ACTION); the caller is responsible for executing
THUNK and for messaging on failure."
  (cond
   ((f90-ts--point-on-empty-line-p)
    (cons (lambda () (f90-ts--join-line-empty-prev))
          'empty-line))

   ((save-excursion
      (back-to-indentation)
      (bobp))
    (cons (lambda () (beginning-of-line))
          'beg-of-buffer))

   (t
    (let* ((pos1 (save-excursion
                   (beginning-of-line)
                   (skip-chars-backward " \t\n")
                   (point)))
           (pos2 (save-excursion
                   (beginning-of-line)
                   (skip-chars-forward " \t\n")
                   (point)))
           (first (f90-ts--node-on-pos pos1 'left))
           (secnd (f90-ts--node-on-pos pos2 'right))
           (is-cont-str (f90-ts--join-line-is-cont-str first secnd)))
      ;;(f90-ts-log-msg :joinprev "pos1: %s, %s" pos1 first)
      ;;(f90-ts-log-msg :joinprev "pos2: %s, %s" pos2 secnd)
      ;;(f90-ts-log-msg :joinprev "is-cont-str: %s" is-cont-str)
      (cl-assert (or first (= pos1 (point-min)))
                 nil "first node is nil with wrong pos1")
      (cl-assert (or (null first)
                     is-cont-str
                     (or (= pos1 (treesit-node-end first))
                         (and (f90-ts--node-type-p first "comment")
                              (string-blank-p (buffer-substring pos1 (treesit-node-end first))))))
                 nil "first node has wrong end position %s" first)
      (cl-assert secnd nil "secnd node is nil")
      (cl-assert (or (= pos2 (treesit-node-start secnd))
                     is-cont-str)
                 nil "secnd node has wrong start position")
      (cond
       (is-cont-str
        (cons (lambda () (f90-ts--join-line-string first pos1 pos2))
              'join-continued-string))

       (first
        (f90-ts--join-line-action-common first secnd t))

       (t
        (cons (lambda ()
                (back-to-indentation)
                (delete-region pos1 (point)))
              'beg-of-buffer)))))))


(defun f90-ts-join-line-prev ()
  "Join previous line with the current one, if part of a continued statement.
This is (partially) a counterpart to `f90-ts-break-line'.
If previous line has comments (at end, next line etc.) joining is not done."
  (interactive)
  (let* ((pair (f90-ts--join-line-prev-aux))
         (process-fn (car pair))
         (action (cdr pair)))
    (cl-assert (member action f90-ts--join-line-prev-valid-actions)
               nil "invalid action from f90-ts--join-line-prev-aux, got %s" action)
    (funcall process-fn)))


(defun f90-ts--join-line-next-aux ()
  "Join current line with the next one, if part of a continued statement.
Return a cons (THUNK . ACTION); the caller is responsible for executing
THUNK and for messaging on failure."
  (cond
   ((f90-ts--point-on-empty-line-p)
    (cons (lambda () (f90-ts--join-line-empty-next))
          'empty-line))

   ((save-excursion
      (end-of-line)
      (eobp))
    (cons (lambda () (end-of-line))
          'end-of-buffer))

   (t
    (let* ((pos1 (save-excursion
                   (end-of-line)
                   (skip-chars-backward " \t\n")
                   (point)))
           (pos2 (save-excursion
                   (end-of-line)
                   (skip-chars-forward " \t\n")
                   (point)))
           (first (f90-ts--node-on-pos pos1 'left))
           (secnd (f90-ts--node-on-pos pos2 'right))
           (is-cont-str (f90-ts--join-line-is-cont-str first secnd)))
      ;;(f90-ts-log-msg :joinnext "pos1: %s, %s" pos1 first)
      ;;(f90-ts-log-msg :joinnext "pos2: %s, %s" pos2 secnd)
      ;;(f90-ts-log-msg :joinnext "is-cont-str: %s" is-cont-str)
      (cl-assert first nil "first node is nil")
      (cl-assert (or (= pos1 (treesit-node-end first))
                     is-cont-str
                     (and (f90-ts--node-type-p first "comment")
                          (string-blank-p (buffer-substring pos1 (treesit-node-end first)))))
                 nil "first node has wrong end position")
      (cl-assert secnd nil "secnd node is nil")
      (cl-assert (or (not (f90-ts--node-type-p secnd "translation_unit"))
                     (= pos2 (point-max)))
                 nil "secnd node is translation_unit with wrong pos2")
      (cl-assert (or (f90-ts--node-type-p secnd "translation_unit")
                     is-cont-str
                     (= pos2 (treesit-node-start secnd)))
                 nil "secnd node has wrong start position")
      (cond
       ((f90-ts--node-type-p secnd "translation_unit")
        (cons (lambda ()
                (end-of-line)
                (delete-region (point) pos2))
              'end-of-buffer))

       (is-cont-str
        (cons (lambda () (f90-ts--join-line-string first pos1 pos2))
              'join-continued-string))

       (t
        (f90-ts--join-line-action-common first secnd nil)))))))


(defun f90-ts-join-line-next ()
  "Join current line with the next one, if part of a continued statement.
This is (partially) a counterpart to `f90-ts-break-line'.
If continued line has comments (at end, next line etc.) joining is not done."
  (interactive)
  (let* ((pair (f90-ts--join-line-next-aux))
         (process-fn (car pair))
         (action (cdr pair)))
    (cl-assert (member action f90-ts--join-line-next-valid-actions)
               nil "invalid action from f90-ts--join-line-next-aux, got %s" action)
    (funcall process-fn)))


(defun f90-ts-shift-line-break ()
  "Shift the break point of current line to point.
It breaks line at point and then joins the trailing part with the next line.
If point is at end of line, then it does not nothing except to move point to
indentation of next line."
  (interactive)
  (if (save-excursion
        (skip-chars-forward " \t")
        (eolp))
      (when (zerop (forward-line 1))
        (back-to-indentation)
        (let ((node (treesit-node-at (point))))
          (when (f90-ts--node-type-p node "comment")
            (f90-ts--comment-forward-prefix node)
            (skip-chars-forward " \t"))))
    (f90-ts-break-line)
    (f90-ts-join-line-next)))


;;;-----------------------------------------------------------------------------
;;; fill operations
;;; the code is inspired and partially copied from the f90-mode.el in emacs core

(defconst f90-ts--join-line-fill-auto-actions
  '(join-continued-lines
    join-continued-string
    join-comments-same-prefix-with-blanks)
  "Set of join actions for non-interactive join during fill operations.
It is a subset of `f90-ts--join-line-next-valid-actions'.")


(defconst f90-ts--join-line-fill-interactive-actions
  '(join-continued-lines
    join-continued-string
    join-comments-same-prefix-trimmed
    join-comments-same-prefix-with-blanks
    append-comment-after-amp
    append-comment-after-stmt)
  "Set of join actions for interactive join during fill operations.
It is a subset of both `f90-ts--join-line-prev-valid-actions'
and `f90-ts--join-line-next-valid-actions' and used for interactive join with
previous and with next line.")


(defvar-local f90-ts--breakpoint-seed-markers nil
  "List of markers recording positions where continuation lines were joined.
It has the format (cons POS-MARKER SEED-MARKERS), where pos-marker stores
current point as preferred initial position, seed-markers are other seeds.
The other seeds are populated by `f90-ts--join-line-fill' during the join
phase and consumed by `f90-ts--find-breakpoint' during the subsequent break
phase to choose initial interactive position in case pos-marker is not
available.  Cleared after each statement is joined and broken up completely.")


(defun f90-ts--breakpoint-seed-markers-reset ()
  "Reset `f90-ts--breakpoint-seed-markers', invalidating all markers."
  (when-let* ((m (car f90-ts--breakpoint-seed-markers)))
    (set-marker m nil))
  (cl-loop for m in (cdr f90-ts--breakpoint-seed-markers)
           do (set-marker m nil))
  (setq f90-ts--breakpoint-seed-markers (cons nil nil)))


(defun f90-ts--seed-markers-pos-marker ()
  "Return the pos-marker from `f90-ts--breakpoint-seed-markers', or nil."
  (car f90-ts--breakpoint-seed-markers))


(defun f90-ts--seed-markers-seeds ()
  "Return the seed marker list from `f90-ts--breakpoint-seed-markers'."
  (cdr f90-ts--breakpoint-seed-markers))


(defun f90-ts--seed-markers-set-pos (pos)
  "Set or update the pos-marker to POS in `f90-ts--breakpoint-seed-markers'."
  (unless f90-ts--breakpoint-seed-markers
    (setq f90-ts--breakpoint-seed-markers (cons nil nil)))
  (if-let* ((m (car f90-ts--breakpoint-seed-markers)))
      (set-marker m pos)
    (setcar f90-ts--breakpoint-seed-markers (set-marker (make-marker) pos))))


(defun f90-ts--seed-markers-push ()
  "Push a seed marker at the current non-whitespace position.
Skip backwards over blanks before recording the position.
Does nothing if a seed marker at that position already exists."
  (save-excursion
    (skip-chars-backward " \t")
    (let ((pos (point)))
      (unless (cl-loop for m in (f90-ts--seed-markers-seeds)
                       when (= (marker-position m) pos) return t)
        (unless f90-ts--breakpoint-seed-markers
          (setq f90-ts--breakpoint-seed-markers (cons nil nil)))
        (push (copy-marker pos) (cdr f90-ts--breakpoint-seed-markers))))))


(defun f90-ts--seed-markers-invalidate-pos ()
  "Invalidate the pos-marker in `f90-ts--breakpoint-seed-markers'."
  (when-let* ((m (car f90-ts--breakpoint-seed-markers)))
    (set-marker m nil)
    (setcar f90-ts--breakpoint-seed-markers nil)))


(defun f90-ts--seed-markers-cleanup-before (pos)
  "Discard seed markers at or before POS, keeping those beyond it."
  (when f90-ts--breakpoint-seed-markers
    (setcdr f90-ts--breakpoint-seed-markers
            (cl-loop
             for m in (f90-ts--seed-markers-seeds)
             if (> (marker-position m) pos)
             collect m
             else do (set-marker m nil)))))


(defun f90-ts--breakpoint-node-within-fill-col-p (node pos fill-col)
  "Return non-nil if POS is within the effective fill column for NODE.
If NODE is a comment, no continuation ampersand is added, so FILL-COL
is compared directly.
If NODE is a string_literal, the continuation ampersand is added without a
blank, hence FILL-COL needs to be reduced by 1.
Otherwise two characters are subtracted to
account for the blank and ampersand appended by the break operation."
  (let ((fill-col-adjusted
         (cond
          ((f90-ts--node-type-p node "comment")
           fill-col)
          ((f90-ts--node-type-p node '("string_literal_part"))
           (- fill-col 1))
          (t
           (- fill-col 2)))))

    (<= (f90-ts--column-number-at-pos pos)
        fill-col-adjusted)))


(defun f90-ts--breakpoint-pos-within-fill-col-p (pos fill-col)
  "Return non-nil if POS is within the effective fill column.
Depending on whether pos is within a statement, within a comment
or within a string, FILL-COL needs to be adjusted.
Like `f90-ts--breakpoint-node-within-fill-col-p', but queries the node at
POS via `treesit-node-at'."
  (f90-ts--breakpoint-node-within-fill-col-p (treesit-node-at pos) pos fill-col))


(defun f90-ts--find-breakpoint-prefer-p (node)
  "Decide whether the end point of NODE is a preferred breakpoint.
If possible, certain positions, like directly left of a comma, opening
parenthesis, before or after \"%\" in component selection should be avoided.
This predicate is ignored in break point selection only if no break point can
be found otherwise."
  (let* ((pos-next (save-excursion
                     (goto-char (treesit-node-end node))
                     (skip-chars-forward " \t\n")
                     (point)))
         (node-next (when pos-next
                      (treesit-node-at pos-next))))
    (not (or
          ;; do not split right before any of these delimiters
          (f90-ts--node-type-p node-next '("," "(" "%"))
          ;; do not split after this delimiter
          (f90-ts--node-type-p node "%")))))


(defun f90-ts--find-breakpoint-in-comment (node fill-col)
  "Find all break positions inside comment NODE at column <= FILL-COL.
Scan the comment text for word boundaries (whitespace preceded by a
non-whitespace character) that fall within the fill budget.  The
comment prefix (matched by `f90-ts-comment-prefix-regexp') is skipped
before searching for break candidates.
Return a sorted list of buffer positions, or nil."
  (cl-assert (f90-ts--node-type-p node "comment")
             nil "\"comment\" node expected")
  (let* ((end (f90-ts--node-end-trimmed node)))
    (save-excursion
      (f90-ts--comment-forward-prefix node)
      (sort
       (cl-loop
        with prefix-end = (point)
        while (re-search-forward "\\S-\\(\\s-+\\)\\S-" end t)
        for pos = (match-beginning 1)
        ;; go back to avoid skipping the last \\S- match, which is
        ;; captured in the next loop as the first \\S-, otherwise we skip
        ;; one letter words like "a"
        do (goto-char (match-end 1))
        when (<= (f90-ts--column-number-at-pos pos) fill-col)
        collect pos
        into positions
        finally return (if (eq f90-ts-fill-select-breakpoint-by 'interactive)
                           (cons end (cons prefix-end positions))
                         positions))
       #'<))))


(defun f90-ts--find-breakpoint-in-string (node beg fill-col &optional prefer)
  "Find all break positions inside string literal NODE at column <= FILL-COL.
Start the search at position BEG.  NODE is the whole string_literal and can
start well before the current line.
Scan the string content for word boundaries (whitespace preceded by a
non-whitespace character) that fall within the fill budget and are on the
current line.  Return a sorted list of buffer positions, or nil.
If PREFER is non-nil, select only some positions (like after a word etc.),
otherwise return all positions."
  (cl-assert (f90-ts--node-type-p node "string_literal")
             nil "\"string_literal\" node expected")
  (save-excursion
    ;; make sure that we stay on the line and within node boundaries
    ;; (string_literal can start before current line, argument beg
    ;; already restrict start to after default indentation column)
    (let* ((start (max beg
                       (save-excursion
                         (back-to-indentation)
                         (skip-chars-forward "&")
                         (point))))
           (end (min (f90-ts--node-end-trimmed node)
                     (progn
                       (goto-char (line-end-position))
                       ;; add one additional character (blank or &, which is matched
                       ;; in re-search-forward below to ensure that position is eligible
                       (move-to-column (min (1+ fill-col) (current-column)))
                       (point)))))
      (if (null prefer)
          ;; take all positions, allow breaking at any point within the string
          (cl-loop for pos from (1+ start) below end
                   when (<= (f90-ts--column-number-at-pos pos) (1- fill-col))
                   collect pos)
        (goto-char start)
        (cl-loop
         ;; at whitespace boundary (\S- followed by \s-), or after punctuation
         ;;do (f90-ts-log-line :brpstr "match" ?\u25C6)
         ;;do (f90-ts-log-line :brpstr "match" ?\x1f48e)
         while (re-search-forward
                "\\S-\\(\\s-\\|[^[:alnum:]]\\)\\|[^[:alnum:]]"
                end t)
         for pos = (if (match-beginning 1)
                       (match-beginning 1)
                     (match-end 0))
         ;; advance by at least one position, do not use pos, as leading characters
         ;; in the match might just be used for assertions
         ;; (make it general so that we can possibly make the regexp a defcustom)
         do (goto-char (1+ (match-beginning 0)))
         when (and (< start pos)
                   (<= (f90-ts--column-number-at-pos pos) (1- fill-col)))
         collect pos
         into positions
         finally return positions)))))


(defun f90-ts--find-breakpoint-collect (sparse-tree)
  "Collect all break-point positions from SPARSE-TREE.
SPARSE-TREE is a cons of a list of position integers and a possibly empty list
of children of the same format as SPARSE-TREE.
It returns a sorted list of buffer positions of prospective breakpoints."
  (let ((collected (cl-labels
                       ((collect (tree)
                          (when (consp tree)
                            (append (car tree)
                                    (seq-mapcat #'collect (cdr tree))))))
                     (collect sparse-tree))))
    (delete-dups
     (sort collected #'<))))


(defun f90-ts--find-breakpoints-for-node (node beg fill-col &optional prefer)
  "Return a list of break positions for NODE after BEG and before FILL-COL.
In general, it returns the (trimmed) end position of the node as a
singleton list, if the column is below (- FILL-COL 2).  Two is subtracted to
account for a blank and the continuation symbol, which will be added by
breaking at this position.  However, for comment nodes and string literals,
there might be several prospective positions within the node.  These are
collected by `f90-ts--find-breakpoint-in-comment' and by
`f90-ts--find-breakpoint-in-string'

If PREFER is non-nil, then break points within string literals is
restricted to preferred positions."
  (cond
   ((f90-ts--node-type-p node "comment")
    (f90-ts--find-breakpoint-in-comment node fill-col))

   ((and (f90-ts--string-literal-decomposed-p)
         (f90-ts--node-type-p node "string_literal_part"))
    (f90-ts--find-breakpoint-in-string (treesit-node-parent node)
                                       beg fill-col
                                       prefer))

   (t
    (let* ((pos (f90-ts--node-end-trimmed node)))
      (when (f90-ts--breakpoint-node-within-fill-col-p node pos fill-col)
        (list pos))))))


(defun f90-ts--find-breakpoint-sparse-tree (root beg end fill-col &optional prefer)
  "Return sparse tree of break points within tree ROOT.
The sparse tree is obtained by filtering relevant nodes and then mapping those
nodes to a list of possible break points.

In most cases, the function filters for leaf nodes whose end position is a
possible break point.  Nodes are selected by their (trimmed) end position.
In particular, the trimmed end of node should be between BEG and END and respect
the fill column FILL-COL.
If PREFER is non-nil, then further reduce selection of nodes and break points
to preferred positions, using `f90-ts--find-breakpoint-prefer-p'.

Comment and string literal nodes require special care, as these nodes can be
broken in the middle."
  ;; first map root to a sparse tree of prospective positions,
  ;; then collect and sort the list
  (treesit-induce-sparse-tree
   root
   (lambda (n)
     (let* ((end-node (f90-ts--node-end-trimmed n)))
       ;; only leaf nodes whose trimmed end falls on the
       ;; current line, the column check is done in the process-fn
       ;; function, as comment and string_literal nodes need special care
       (and (null (treesit-node-children n))
            (<= beg end-node)
            (<= end-node end)
            (not (f90-ts--node-type-p n "&"))
            (or (null prefer) (f90-ts--find-breakpoint-prefer-p n)))))
   (lambda (n) (f90-ts--find-breakpoints-for-node n beg fill-col prefer))))


(defun f90-ts--find-breakpoint-rightmost-idx (positions fill-col)
  "Return index in POSITIONS of the rightmost candidate within FILL-COL.
A candidate satisfies the constraint according to
`f90-ts--breakpoint-pos-within-fill-col-p'.  Return nil if no candidate
in POSITIONS satisfies it."
  (when-let* ((target (cl-loop
                        for p in positions
                        when (f90-ts--breakpoint-pos-within-fill-col-p p fill-col)
                        maximize p)))
    (cl-position target positions)))


(defun f90-ts--find-breakpoint-read-key (idx positions fill-col at-end)
  "Read one key and return (IDX ACTION) for candidate POSITIONS.
ACTION is nil to continue, or a symbol: `confirm', `join', `skip',
`abort', `continue'.  AT-END controls whether SPC is is just a skip
line operation or whether it extends the region by one line.
FILL-COL is used to determine the target position for the \"r\" key,
which jumps to the rightmost candidate at or before FILL-COL."
  (let ((prompt (concat "Select break point: left/right/home/end or C-p/C-n, "
                        "r rightmost, "
                        "BACKSPACE/DEL join, RET confirm"
                        (if at-end
                            ", q skip line, SPC skip and extend region"
                          ", q/SPC skip line")
                        ", C-g abort")))
    (message prompt))
  (let ((key (read-key))
        (num-pos (length positions)))
    (cond
     ((or (eq key 'left)  (eq key ?\C-p)) (list (mod (1- idx) num-pos) nil))
     ((or (eq key 'right) (eq key ?\C-n)) (list (mod (1+ idx) num-pos) nil))
     ((eq key 'home)                      (list 0                      nil))
     ((eq key 'end)                       (list (1- num-pos)           nil))
     ((eq key ?r)
      (list (or (f90-ts--find-breakpoint-rightmost-idx positions fill-col) idx)
            nil))
     ((memq key '(return ?\r ?\n))        (list idx                    'confirm))
     ((eq key ?\d)                        (list idx                    'join-prev))
     ((eq key 'deletechar)                (list idx                    'join-next))
     ((eq key ?q)                         (list idx                    'skip))
     ((eq key ?\C-g)                      (list idx                    'abort))
     ((eq key ?\s)                        (list idx                    (if at-end 'continue 'skip)))
     ;; ignore any other keys, and keep idx
     (t                                   (list idx                    nil)))))


(defun f90-ts--find-breakpoint-initial-pos (positions fill-col)
  "Return initial position for interactive breakpoint selection from POSITIONS.
If the pos-marker in `f90-ts--breakpoint-seed-markers' is valid, return
the closest candidate at or before it.  Otherwise, return the closest
candidate at or before the rightmost seed marker within FILL-COL.
If no seed markers are available, return the rightmost candidate within
FILL-COL."
  (or
   ;; pos-marker: closest candidate at or before it
   (when-let* ((m (f90-ts--seed-markers-pos-marker))
               (ref (marker-position m)))
     (cl-loop
      for p in positions
      when (<= p ref)
      maximize p into best
      finally return best))

   ;; other seed-markers: rightmost marker within fill-col and then
   ;;                     closest candidate at or before it
   (when-let* ((ref (cl-loop
                     for m in (f90-ts--seed-markers-seeds)
                     for mpos = (marker-position m)
                     when (and mpos
                               (f90-ts--breakpoint-pos-within-fill-col-p mpos fill-col))
                     maximize mpos into best
                     finally return best)))
     (cl-loop
      for p in positions
      when (<= p ref)
      maximize p into best
      finally return best))

   ;; fallback: rightmost candidate in positions within fill-col
   (cl-loop
    for p in positions
    when (f90-ts--breakpoint-pos-within-fill-col-p p fill-col)
    maximize p into best
    finally return best)))


(defun f90-ts--find-breakpoint-interactive (positions fill-col allow-continue)
  "Interactively select a break point from POSITIONS.
Moves point to each candidate position as the user navigates with
LEFT/RIGHT or \\[previous-line]/\\[next-line].  Return the selected position
on RET, or nil on \\[keyboard-quit].
Use POSITIONS to determine a candidate closest to FILL-COL but before that.
ALLOW-CONTINUE controls whether SPC is offered to extend the fill region.

Remark: the `read-key' loop in `f90-ts--find-breakpoint-read-key' blocks other
interaction (like scrolling in another buffer with mouse).  This might need
some improvements."
  (when-let* ((initial-pos (or (f90-ts--find-breakpoint-initial-pos positions fill-col)
                               ;; no previous breakpoint available, then look into positions
                               ;; before fill-col
                               (cl-loop for p in positions
                                        when (<= (f90-ts--column-number-at-pos p) fill-col)
                                        maximize p)
                               ;; use smallest position available as fallback
                               (car positions)))
              (idx (cl-position initial-pos positions))
              (orig-point (point))
              (orig-cursor cursor-type))
    (unwind-protect
        (progn
          ;; make cursor bar of roughly one third of character width
          (setq cursor-type (cons 'bar (max 2 (/ (frame-char-width) 3))))
          (goto-char (nth idx positions))
          (cl-loop
           for (new-idx action) = (f90-ts--find-breakpoint-read-key idx positions fill-col
                                                                    allow-continue)
           do (setq idx new-idx)
           until action
           do (goto-char (nth idx positions))
           ;; track current position in pos-marker in seed-markers list
           do (f90-ts--seed-markers-set-pos (point))
           finally return (pcase action
                            ;; return value nil signals that no position is available,
                            ;; do not break this line
                            ('confirm    (nth idx positions))
                            ('join-prev  'join-prev)
                            ('join-next  'join-next)
                            ('skip       nil)
                            ('abort      'abort)
                            ('continue   'continue))))
      (setq cursor-type orig-cursor)
      (goto-char orig-point))))


(defun f90-ts--find-breakpoints-indent ()
  "Estimate the indentation column of the next line after breaking current line.
This estimate is reuqired to make sure a break point is chosen after the
new indentation level, so that breaking the line does not does not make the
layout worse.
The return value is a buffer position on the current line indicating the
guessed indentation column on the next line.  Any break point on the current
is after that buffer position."
  ;; TODO: what kind of estimate do we really need here??
  ;; possible contexts: single line statement, multiline statements,
  ;;           comments, statement with trailing comment, ...
  ;; example: breaking
  ;; x=very_long_unbreakable_variable_name
  ;; could give
  ;; x= &
  ;;      very_long_unbreakable_variable_name
  ;; due to indentation rules, making it worse than before
  (save-excursion
    (back-to-indentation)
    (let ((node (treesit-node-at (point))))
      (+ (point)
         (cond
          ((f90-ts--subsequent-line-of-continued-stmt-p (point))
           1)
          ((f90-ts--node-type-p node "comment")
           0)
          (t
           f90-ts-indent-continued))))))


(defun f90-ts--find-breakpoints-all (fill-col fill-col-select)
  "Collect all candidate break points on the current line.
In general a break point is any end position of a leaf node on the current
line, at column at most FILL-COL-SELECT minus 2 and beyond the estimated
indentation of the continued line.  FILL-COL is the fill column,
which can be ignored in interactive mode, but is still used to preselect
prospective break positions and for some cursor movements in interactive mode.

Return a list of candidate POSITIONS.  There are three cases:
- no preferred positions exist: fall back to all positions, bounded by
  FILL-COL-SELECT;
- in interactive mode, preferred positions exist but none are within
  FILL-COL: merge all positions within FILL-COL with the preferred
  positions (which may lie beyond FILL-COL), so navigating past fill-col
  only offers sensible break points;
- otherwise (preferred positions exist, and either at least one is
  within FILL-COL, or selection mode is not interactive): use the preferred
  positions as-is.

If no positions exist, then it returns nil."
  (let* ((beg (line-beginning-position))
         (end (line-end-position))
         (indent (f90-ts--find-breakpoints-indent))
         (root (treesit-node-on beg end))
         (pos-prefer (f90-ts--find-breakpoint-collect
                      (f90-ts--find-breakpoint-sparse-tree
                       root indent end fill-col-select
                       'prefer)))

         (positions (if (and pos-prefer
                             (f90-ts--breakpoint-pos-within-fill-col-p (car pos-prefer) fill-col))
                        pos-prefer
                      (f90-ts--find-breakpoint-collect
                       (f90-ts--find-breakpoint-sparse-tree
                        root indent end fill-col-select
                        nil)))))

    (if (eq f90-ts-fill-select-breakpoint-by 'interactive)
        (let ((marker-pos (f90-ts--find-breakpoint-initial-pos pos-prefer fill-col)))
          (if (and marker-pos (not (member marker-pos positions)))
              (cl-sort (cons marker-pos positions) #'<)
            positions))
      positions)))


(defun f90-ts--find-breakpoint (fill-col allow-continue)
  "Find a break point on the current line.
A break point is any end position of a leaf node on the current line and at
column at most FILL-COL minus 2.  Return the buffer position to break at,
or nil if no suitable break point exists.

The selection strategy is controlled by `f90-ts-fill-select-breakpoint-by'.

For interactive selection, the rightmost marker in
`f90-ts--breakpoint-seed-markers' that falls among the eligible positions is
used as the initial suggestion.
Interactive mode allows to select and break after FILL-COL.
ALLOW-CONTINUE is passed to `f90-ts--find-breakpoint-interactive' to
control whether SPC is offered to extend the fill region."
  (when (or (> (f90-ts--column-number-at-pos (line-end-position)) fill-col)
            (eq f90-ts-fill-select-breakpoint-by 'interactive))
    (let* ((fill-col-select (if (eq f90-ts-fill-select-breakpoint-by 'interactive)
                                most-positive-fixnum
                              fill-col))
           (positions (f90-ts--find-breakpoints-all fill-col fill-col-select)))
      (when positions
        (pcase f90-ts-fill-select-breakpoint-by
          ('rightmost
           (apply #'max positions))
          ('interactive
           (f90-ts--find-breakpoint-interactive positions
                                                fill-col
                                                allow-continue)))))))


(defun f90-ts--break-line-wrap (fill-col allow-continue)
  "Break the current line once if it exceeds FILL-COL.
Find a breakpoint via `f90-ts--find-breakpoint' according to
`f90-ts-find-breakpoint-select' and call `f90-ts-break-line' with position.
Return non-nil if a break was performed, nil if the line already fits
or no breakpoint can be found.  The function assumes that the line has
no trailing blanks.

ALLOW-CONTINUE controls whether SPC is offered in interactive mode to
extend the fill region; when selected, returns the symbol `continue'.

Join markers in `f90-ts--breakpoint-seed-markers', which are before the
break point, are discarded; those beyond it are kept as candidates for
subsequent interactive break point selection."
  (cl-assert (= (line-end-position)
                (f90-ts--pos-last-nonspace (point)))
             nil "line has trailing blanks at buffer position %s" (point))
  (let ((pos (f90-ts--find-breakpoint fill-col allow-continue)))
    (cond
     ((null pos)          'skip)  ; no break point found or selected
     ((eq pos 'join-prev) 'join-prev)
     ((eq pos 'join-next) 'join-next)
     ((eq pos 'abort)     'abort) ; abort the fill operation
     ((eq pos 'continue)  'continue)
     ((or (= pos (line-end-position))
          (save-excursion
            (goto-char pos)
            (skip-chars-forward " \t")
            (f90-ts--node-type-p (f90-ts--node-on-pos (point) 'right)
                                 "&")))
      ;; do not break if at end of line or at continuation symbol ampersand
      'skip)
     (t ; position value determined by action 'confirm
      (goto-char pos)
      (f90-ts-break-line)
      ;; discard markers at or before the break point,
      ;; keep only those beyond it (still valid candidates)
      (let ((break-pos (point)))
        (f90-ts--seed-markers-invalidate-pos)
        (f90-ts--seed-markers-cleanup-before break-pos))
      'broken))))


(defun f90-ts--join-line-fill-p (join-col end-marker)
  "Return non-nil if current line should be joined with next line for filling.
It checks that the current line is shorter than JOIN-COL, that next line does
not start after END-MARKER and that neither the current nor next line is empty
or an empty comment.  This is done to preserve any comment structure.

Note: most checks whether lines can be joined are done in
`f90-ts--join-line-action-common', which returns an action symbol for deciding
whether a join operations fits the fill case.  This predicate provides a
pre-check to exclude column related cases and some specific corner-case."
  (not
   (or (>= (- (line-end-position)
              (line-beginning-position))
           join-col)
       (>= (save-excursion (forward-line 1) (point))
           end-marker)
       (f90-ts--next-line-empty-p (point))
       (f90-ts--line-empty-comment-p (point))
       (f90-ts--next-line-empty-comment-p (point)))))


(defun f90-ts--join-line-fill (fill-col end-marker &optional requested)
  "Join current line with the next one, as part of a fill operation.
The join operation is performed as long as current line does not exceed
column FILL-COL and the next line does not start after END-MARKER.

In interactive mode, REQUESTED can be non-nil.  In this case, the fill
pre-check `f90-ts--join-line-fill-p' is bypassed and the full set of join
actions is accepted.
If REQUESTED is `join-prev' then `f90-ts-join-line-prev' is invoked.
If REQUESTED is `join-next' then `f90-ts-join-line-next' is invoked.

The function adds the position of the join in `f90-ts--breakpoint-seed-markers'
after each successful join."
  (cl-assert (memq requested '(nil join-prev join-next))
             nil "invalid join action, requested is %s" requested)
  (when (or requested (f90-ts--join-line-fill-p fill-col end-marker))
    (let* ((prev-p (eq requested 'join-prev))
           (pair (if prev-p
                     (f90-ts--join-line-prev-aux)
                   (f90-ts--join-line-next-aux)))
           (process-fn (car pair))
           (action     (cdr pair))
           (valid-actions (if prev-p
                              f90-ts--join-line-prev-valid-actions
                            f90-ts--join-line-next-valid-actions))
           (accepted-actions (if requested
                                 f90-ts--join-line-fill-interactive-actions
                               f90-ts--join-line-fill-auto-actions)))
      (cl-assert (member action valid-actions)
                 nil "invalid join action, got %s" action)
      (when (member action accepted-actions)
        (funcall process-fn)
        (f90-ts--seed-markers-push)
        ;; signal that a join took place
        t))))


(defun f90-ts--fill-region-update-end-overlay (ov end-marker)
  "Update OV to show the END-MARKER with an indicator.
END-MARKER is assumed to be at beginning of line position.
The overlay is placed on the end of the previous line, which is the
last line to be filled."
  (save-excursion
    (goto-char (marker-position end-marker))
    (if (eobp)
        (move-overlay ov (1- (point)) (point))
      (let ((pos (1- (point))))         ; newline character of preceding line
        (move-overlay ov (1- pos) pos)))
    ;; 25C4 is a left pointing filled triangle
    (overlay-put ov 'after-string (propertize " \u25C4" 'face 'warning))))


(defun f90-ts--fill-region-continue (end-marker end-overlay)
  "Advance END-MARKER past empty and empty-comment lines.
Called after a \\='continue action to position END-MARKER at the
first line where a break candidate can exist and interactive session
can resume.
The function updates END-OVERLAY to match the new end marker position."
  ;; assertion also works if at final line at eob with and without
  ;; trailing newline
  (cl-assert (= (marker-position end-marker) (line-beginning-position 2))
             nil "end-marker not at start of next line: marker=%s lbp2=%s"
             (marker-position end-marker) (line-beginning-position 2))
  (unless (= (marker-position end-marker) (point-max))
    (save-excursion
      (goto-char (line-beginning-position 2))
      (while (and (not (eobp))
                  (f90-ts--line-empty-p (point)))
        (forward-line 1))
      ;; either at end of buffer or at first non-empty-like line,
      ;; place marker at start of next line
      (forward-line 1)
      (set-marker end-marker (point)))
    (when end-overlay
      (f90-ts--fill-region-update-end-overlay end-overlay end-marker))))


(defun f90-ts--fill-region-join-step (broke end-marker fill-col)
  "Attempt to join the current line with its continuation.
BROKE is the result of the previous break step; when it is the symbol
`join', the user has requested a standard join with next line and fill
heuristics are bypassed.  END-MARKER is the region end marker and is moved
to the start of the next line if it falls inside the newly joined line, so that
the main loop's while condition does not abort prematurely.  FILL-COL is the
target fill column passed to `f90-ts--join-line-fill'.
Return non-nil if a join was performed or signalled."
  (unless (f90-ts--point-on-empty-line-p)
    (let ((joined (f90-ts--join-line-fill fill-col end-marker
                                          (and (memq broke '(join-prev join-next))
                                               broke))))
      (when joined
        ;; if end-marker landed inside the newly joined line, move it to
        ;; the start of the next line so the while condition steps past cleanly
        (when (< (marker-position end-marker) (line-end-position))
          (set-marker end-marker (line-beginning-position 2))))
      ;; pass on the signal that a join took place (even if
      ;; f90-ts-join-line-next has not joined, but this skips any subsequent
      ;; actions in the main loop like the break step to be performed)
      joined)))


(defun f90-ts--fill-region-break-step (joined fill-col end-marker)
  "Attempt to break the current line if it exceeds the fill column FILL-COL.
JOINED is the result of the join step; if it is non-nil, or the current
line is empty, no break is attempted.  END-MARKER is used to determine
whether the `continue' action should be offered: it is only available
when END-MARKER is exactly at the start of the next line, avoiding
accidental region extension when the boundary is not visible.
Return the result of `f90-ts--break-line-wrap', or nil if skipped."
  (unless (or joined (f90-ts--point-on-empty-line-p))
    (end-of-line)
    (delete-horizontal-space)
    (let ((allow-continue (= (marker-position end-marker)
                             (line-beginning-position 2))))
      (f90-ts--break-line-wrap fill-col allow-continue))))


(defun f90-ts--fill-region-advance ()
  "Advance past the current line and reset the join-marker list.
Called when neither a join nor a break was performed on the current line,
indicating it needed no modification and the loop should move on.
Clears `f90-ts--breakpoint-seed-markers' and moves point to the next line."
  (f90-ts--breakpoint-seed-markers-reset)
  (forward-line 1))


(defun f90-ts--fill-region-aux (beg end fill-col)
  "Fill every line in region BEG..END up to column FILL-COL.
Break overlong lines exceeding FILL-COL and join continued lines or
comments where possible.

For line-based fill operations, an initial break point marker for
interactive mode can be injected via `f90-ts--breakpoint-seed-markers'."
  ;; extend beg/end to canonical line-beginning positions
  (save-excursion
    (goto-char beg)
    (unless (bolp) (setq beg (line-beginning-position))))
  (save-excursion
    (goto-char end)
    (unless (bolp) (setq end (line-beginning-position 2))))

  (when (eq f90-ts-fill-select-breakpoint-by 'interactive)
    (deactivate-mark))

  (save-excursion
    (f90-ts--with-check-modified-region beg end
      (let (end-marker end-overlay)
        (unwind-protect
            (progn
              (setq end-marker (copy-marker end t))
              (when (eq f90-ts-fill-select-breakpoint-by 'interactive)
                (setq end-overlay (make-overlay 1 1))
                (f90-ts--fill-region-update-end-overlay end-overlay end-marker))

              (cl-loop
               ;; note: broke is initialised with nil, it is first accessed
               ;; in the next line, before first evaluated afterwards
               initially (goto-char beg)

               ;; at most one action per loop step: join, break or advance
               for joined = (f90-ts--fill-region-join-step broke end-marker fill-col)
               do (when end-overlay
                    (f90-ts--fill-region-update-end-overlay end-overlay end-marker))

               for broke = (f90-ts--fill-region-break-step joined fill-col end-marker)
               do (when (eq broke 'continue)
                    (f90-ts--fill-region-continue end-marker end-overlay))

               until (eq broke 'abort)
               unless (or joined (memq broke '(broken join-prev join-next)))
               do (f90-ts--fill-region-advance)
               while (or (< (point) end-marker)
                         (memq broke '(join-prev join-next)))))
          ;; clean up overlay and markers
          ;; (end-marker and prior breakpoint markers for join)
          (when end-overlay (delete-overlay end-overlay))
          (f90-ts--breakpoint-seed-markers-reset)
          (set-marker end-marker nil))))))


(defun f90-ts-fill-region ()
  "Fill active region or whole buffer up to `fill-column'."
  (interactive)
  (f90-ts--fill-region-aux
   (if (use-region-p) (region-beginning) (point-min))
   (if (use-region-p) (region-end)       (point-max))
   fill-column))


(defun f90-ts-fill-at-line ()
  "Break and join current line at point according to fill operations.
Joining is done in interactive mode and allows to combine current with
subsequent lines in multiline statements or comment blocks.
In interactive mode, the current point is used as the initial break point
suggestion."
  (interactive)
  (unwind-protect
      (progn
        (when (eq f90-ts-fill-select-breakpoint-by 'interactive)
          (f90-ts--seed-markers-set-pos (point)))
        (f90-ts--fill-region-aux (line-beginning-position)
                                 (line-end-position)
                                 fill-column))
    (f90-ts--breakpoint-seed-markers-reset)))


(defun f90-ts-fill-prev-line ()
  "Fill the current line and the previous line."
  (interactive)
  (let ((beg (save-excursion
               (forward-line -1)
               (line-beginning-position)))
        (end (line-end-position)))
    (f90-ts--fill-region-aux beg end fill-column)))


(defun f90-ts-fill-next-line ()
  "Fill the current line and the next line."
  (interactive)
  (let ((beg (line-beginning-position))
        (end (save-excursion
               (forward-line 1)
               (line-end-position))))
    (f90-ts--fill-region-aux beg end fill-column)))


;;;-----------------------------------------------------------------------------
;;; treesitter based region functions

(defun f90-ts--mark-region-reversed-p (region-order)
  "Return non-nil if region should be marked with point at start.
REGION-ORDER is as provided by `f90-ts-mark-region-order'."
  (pcase region-order
    ('start    t)
    ('end      nil)
    ('preserve (and (use-region-p) (> (mark) (point))))
    (_         nil)))


(defun f90-ts--mark-region (beg end &optional region-order)
  "Mark region BEG..END.
REGION-ORDER controls where point is placed after marking,
see `f90-ts-mark-region-order'."
  (let ((order (f90-ts--mark-region-reversed-p region-order)))
    (push-mark beg t t)
    (goto-char end)
    (when order
      (exchange-point-and-mark))))


(defun f90-ts--mark-region-node (node &optional region-order)
  "Mark the region spanned by NODE, trimmed of leading and trailing whitespace.
If REGION-ORDER is non-nil, then put point at start of region, otherwise point
is at end of region."
  (let ((beg (f90-ts--node-start-trimmed node))
        (end (f90-ts--node-end-trimmed   node)))
    (f90-ts--mark-region beg end region-order)))


(defun f90-ts--mark-region-node-or-extent (node-or-extent &optional region-order)
  "Mark region given by NODE-OR-EXTENT, trimmed of leading and trailing whitespace.
It is either a single NODE or a pair (FIRST . LAST).
If it is a pair, mark the whole region from start of FIRST to end of LAST.

If REGION-ORDER is non-nil, then put point at start of region, otherwise point
is at end of region."
  (if (consp node-or-extent)
      (f90-ts--mark-region (f90-ts--node-start-trimmed (car node-or-extent))
                           (f90-ts--node-end-trimmed   (cdr node-or-extent))
                           region-order)
    (f90-ts--mark-region-node node-or-extent region-order)))


(defun f90-ts--smallest-named-node-containing-region (beg end trim)
  "Return the smallest named node fully containing region from BEG to END.
The node must be strictly larger than the region (BEG END).
If TRIM is non-nil, then use trimmed span of named nodes for comparison
with BEG..END region."
  (when-let* ((node (treesit-node-on beg end))
              (cover (treesit-parent-until
                      node
                      (lambda (n)
                        (let ((nb (if trim
                                      (f90-ts--node-start-trimmed n)
                                    (treesit-node-start n)))
                              (ne (if trim
                                      (f90-ts--node-end-trimmed n)
                                    (treesit-node-end n))))
                          (and (treesit-node-check n 'named)
                               (<= nb beg)
                               (>= ne end)
                               (< (- end beg)
                                  (- ne nb)))))
                      t)))
    (f90-ts--largest-node-same-span cover)))


(defun f90-ts--nodes-same-group-p (node1 node2)
  "Return non-nil if NODE1 and NODE2 belong to the same navigation group.

Currently this predicate groups comment nodes sharing the same comment prefix."
  ;; even if not belonging to any kind of group, a node is at least grouped with itself,
  ;; this avoids any additional branches in other functions
  (or (treesit-node-eq node1 node2)
      (and (f90-ts--node-type-p node1 "comment")
           (f90-ts--node-type-p node2 "comment")
           (string= (f90-ts--comment-prefix node1 'trimmed)
                    (f90-ts--comment-prefix node2 'trimmed)))))


(defun f90-ts--group-block-extent (node)
  "Return (FIRST . LAST) nodes for the group containing NODE."
  (let* ((first (cl-loop
                 for cur = node then next
                 for next = (treesit-node-prev-sibling cur)
                 while (and next (f90-ts--nodes-same-group-p next node))
                 finally return cur))
         (last  (cl-loop
                 for cur = node then next
                 for next = (treesit-node-next-sibling cur)
                 while (and next (f90-ts--nodes-same-group-p next node))
                 finally return cur)))
    (cons first last)))


(defun f90-ts--node-aligned-at-beg (beg end named)
  "Return the largest node starting exactly at BEG and ending before END.
If NAMED is non-nil, consider only named nodes."
  (when-let* ((node (f90-ts--node-on-pos beg 'right named)))
    (treesit-parent-while
     node
     (lambda (n)
       (and (=  beg (f90-ts--node-start-trimmed n))
            (<= (f90-ts--node-end-trimmed n) end))))))


(defun f90-ts--node-aligned-at-end (beg end named)
  "Return the largest node ending exactly at END and starting after BEG.
If NAMED is non-nil, consider only named nodes."
  (when-let* ((node (f90-ts--node-on-pos end 'left named)))
    (treesit-parent-while
     node
     (lambda (n)
       (and (<= beg (f90-ts--node-start-trimmed n))
            (= (f90-ts--node-end-trimmed n) end))))))


(defun f90-ts--group-block-p (node-beg node-end)
  "Check whether NODE-BEG and NODE-END are within a node group.
This is the case if both are siblings (have the same parent),
belong to the same group, and all siblings in between the two
nodes also belong to the same group."
  (and node-beg
       node-end
       (treesit-node-eq (treesit-node-parent node-beg)
                        (treesit-node-parent node-end))
       (f90-ts--nodes-same-group-p node-beg node-end)
       (cl-loop for cur = node-beg then (treesit-node-next-sibling cur t)
                while (and cur (not (treesit-node-eq cur node-end)))
                always (f90-ts--nodes-same-group-p cur node-beg))))


(defun f90-ts--group-block-region-classify (beg end node-beg node-end)
  "Classify BEG..END within a confirmed group from NODE-BEG to NODE-END."
  (let* ((extent (f90-ts--group-block-extent node-beg))
         (node-first (car extent))
         (node-last (cdr extent))
         (first-beg (f90-ts--node-start-trimmed node-first))
         (last-end (f90-ts--node-end-trimmed node-last)))
    (cond
     ((and (treesit-node-eq node-beg node-end)
           (= beg first-beg)
           (= end last-end))
      (list 'single node-beg))
     ((and (= beg first-beg) (= end last-end))
      (list 'block node-first node-last))
     (t
      (list 'partial node-beg node-end)))))


(defun f90-ts--group-block-region (beg end)
  "Classify type of region BEG..END with respect to groups of nodes.

If nodes at BEG and END exists but do not form a group, return them marked
as disparate, as these nodes are still useful for further operations.

Return a list:
  ('single    NODE)  region is exactly one node
  ('block     FN LN) region is exactly the full group from FN to LN
  ('partial   FN LN) region is within group but neither single nor full
  ('disparate FN LN) not a group, region starts and ends with disparate nodes
  nil                node at beg or end could not be determined"
  (let* ((node-beg (or (f90-ts--node-aligned-at-beg beg end 'named)
                       (f90-ts--node-on-pos beg 'left 'named)))
         (node-end (or (f90-ts--node-aligned-at-end beg end 'named)
                       (f90-ts--node-on-pos end 'right 'named))))
    (cond
     ((f90-ts--group-block-p node-beg node-end)
      (f90-ts--group-block-region-classify beg end node-beg node-end))
     ((and node-beg node-end)
      (list 'disparate node-beg node-end))
     (t
      nil))))


(defun f90-ts--group-block-eq (group1 group2)
  "Determine whether two groups GROUP1 and GROUP2 of nodes are equal.
Note that equality of the two first nodes is equivalent to the
equality of the two last nodes.
If at least one group is nil, return value is nil as well."
  (and group1
       group2
       (treesit-node-eq (car group1) (car group2))))


(defun f90-ts-mark-region-enlarge-active ()
  "Expand active region to next larger node."
  (cl-assert (use-region-p)
             nil
             "active region required")

  (let* ((region (f90-ts--region-trimmed))
         (beg (car region))
         (end (cdr region))
         (group (f90-ts--group-block-region beg end)))
    (cl-destructuring-bind (&optional gkind reg-first _) group
      (if (eq gkind 'partial)
          ;; single comment line: expand to full block
          (let* ((extent (f90-ts--group-block-extent reg-first))
                 (ext-first (car extent))
                 (ext-last  (cdr extent)))
            (if (treesit-node-eq ext-first ext-last)
                ;; block is just one line, fall through to tree-sitter ascent
                (if-let* ((node (f90-ts--smallest-named-node-containing-region beg end 'trim)))
                    (f90-ts--mark-region-node node f90-ts-mark-region-order)
                  (message "no tree-sitter node found enlarging current region"))
              (f90-ts--mark-region (f90-ts--node-start-trimmed ext-first)
                                   (f90-ts--node-end-trimmed   ext-last)
                                   f90-ts-mark-region-order)))
        (if-let* ((node (f90-ts--smallest-named-node-containing-region beg end 'trim)))
            (f90-ts--mark-region-node node f90-ts-mark-region-order)
          (message "no tree-sitter node found enlarging current region"))))))


(defun f90-ts-mark-region-enlarge-initial ()
  "Mark region of smallest named node at point.
This operation assumes that no region is active."
  (cl-assert (not (use-region-p))
             nil
             "active region already present")

  (let* ((pos (f90-ts--pos-nonspace (point)))
         (node-at (treesit-node-at pos)))
    (if (f90-ts--node-type-p node-at "comment")
        (f90-ts--mark-region-node node-at f90-ts-mark-region-order)
      (if-let* ((node-on (f90-ts--node-on-pos pos 'right 'named))
                (node    (f90-ts--largest-node-same-span node-on)))
          (f90-ts--mark-region-node node f90-ts-mark-region-order)
        (message "no tree-sitter node found at point")))))


(defun f90-ts-mark-region-enlarge ()
  "Expand region to next larger node.
If no region is active, select the smallest named node at point.
If region is active, expand to the smallest named node that is larger
than current region.
If current node is a comment belonging to a block of comments all
starting with the same comment prefix enlarge to the block of comments.
The comment prefix is matched by `f90-ts-openmp-prefix-regexp' and
`f90-ts-comment-prefix-regexp'."
  (interactive)
  (if (use-region-p)
      (f90-ts-mark-region-enlarge-active)
    (f90-ts-mark-region-enlarge-initial)))


(defun f90-ts--mark-region-shrink-child (comment-selector child-index child-name)
  "Core routine for shrinking region to a child node.
Find smallest node covering region.  Then reduce region to its child determined
by CHILD-INDEX.  If there are further grand-children with the same span, return
the smallest grandchild in the tree.
COMMENT-SELECTOR is `car' or `cdr', selecting from a cons of (first . last)
comment nodes.  CHILD-INDEX is passed to `treesit-node-child' (0 for first
and -1 for last).  CHILD-NAME is a name like \"first\" or \"last\"
which is used for an error message if the child is not found."
  (if (use-region-p)
      (let* ((region (f90-ts--region-trimmed))
             (beg    (car region))
             (end    (cdr region))
             (group  (f90-ts--group-block-region beg end)))
        (cl-destructuring-bind (&optional gkind first last) group
          (if (eq gkind 'block)
              (f90-ts--mark-region-node (funcall comment-selector (cons first last))
                                        f90-ts-mark-region-order)
            (if-let* ((node-on (treesit-node-on beg end))
                      (node    (f90-ts--smallest-node-same-span node-on))
                      (child   (treesit-node-child node child-index t)))
                (f90-ts--mark-region-node child f90-ts-mark-region-order)
              (message "no tree-sitter %S child found for current region" child-name)))))
    (message "no active region")))


(defun f90-ts-mark-region-shrink-child-first ()
  "Core routine for shrinking region to a child node.
Find smallest node covering region.  Then reduce region to its first child.
If there are further grand-children with the same span, return the smallest
grandchild in the tree."
  (interactive)
  (f90-ts--mark-region-shrink-child #'car 0 "no tree-sitter child0 found for current region"))


(defun f90-ts-mark-region-shrink-child-last ()
  "Core routine for shrinking region to a child node.
Find smallest node covering region.  Then reduce region to its last child.
If there are further grand-children with the same span, return the smallest
grandchild in the tree."
  (interactive)
  (f90-ts--mark-region-shrink-child #'cdr -1 "no tree-sitter child9 found for current region"))


(defun f90-ts--group-block-anchor (group direction)
  "Return the anchor node from GROUP classification for DIRECTION.
DIRECTION is `backward' or `forward'.
GROUP is a list as returned by `f90-ts--group-block-region'."
  (cond
   ((member (car group) '(block partial disparate))
    (if (eq direction 'backward)
        (cadr group)
      (caddr group)))
   ((eq (car group) 'single)
    (cadr group))
   (t
    nil)))


(defun f90-ts--relative-or-group (anchor get-relative)
  "Return the relative of ANCHOR via GET-RELATIVE and group handling.
If the relative returned by GET-RELATIVE is in the same group as ANCHOR,
return the relative node itself, and do not extent to their group.
Otherwise return the full group extent of the relative.

Note that each node always forms a \"group\" on its own if it does not
belong to any proper block."
  (when-let* ((relative      (funcall get-relative anchor))
              (group-anchor   (f90-ts--group-block-extent anchor))
              (group-relative (f90-ts--group-block-extent relative)))
    (if (f90-ts--group-block-eq group-anchor group-relative)
        relative
      group-relative)))


(defun f90-ts--mark-region-relative (get-relative direction)
  "Mark relative of node determined by current active region and GET-RELATIVE.
DIRECTION is `backward' or `forward', used to resolve the anchor node when the
region spans a full group block.
For `backward' the first node of the group is used as anchor for GET-RELATIVE.
For `forward' the last node of the group is used as anchor for GET-RELATIVE.

First find smallest node covering currently active region.
If the node spans the current region, then mark its relative determined
by GET-RELATIVE.  GET-RELATIVE may return a node or a cons (FIRST . LAST).
Otherwise mark the region spanned by the node itself (like enlarge-region)."
  (cl-assert (member direction '(backward forward))
             nil "direction is not backward or forward")
  (if (use-region-p)
      (if-let* ((region (f90-ts--region-trimmed))
                (beg (car region))
                (end (cdr region))
                (node-on (treesit-node-on beg end))
                (node (f90-ts--largest-node-same-span node-on))
                (group (f90-ts--group-block-region beg end))
                (anchor (f90-ts--group-block-anchor group direction)))
          (let ((node-mark (or (f90-ts--relative-or-group anchor get-relative)
                               node)))
            (f90-ts--mark-region-node-or-extent node-mark f90-ts-mark-region-order))
        (message "tree-sitter relative not found for current region"))
    (message "no active region")))


(defun f90-ts-mark-region-first-sibling ()
  "Mark first sibling of node determined by current active region.
If the node spans the current region, then mark its first sibling.
Otherwise mark the region spanned by the node itself (like enlarge-region)."
  (interactive)
  (f90-ts--mark-region-relative
   (lambda (node)
     (when-let* ((parent (treesit-node-parent node)))
       (treesit-node-child parent 0 t)))
   'backward))


(defun f90-ts-mark-region-prev-sibling ()
  "Mark prev sibling of node determined by current active region.
If the node spans the current region, then mark its prev sibling.
Otherwise mark the region spanned by the node itself (like enlarge-region)."
  (interactive)
  (f90-ts--mark-region-relative
   (lambda (node)
     (treesit-node-prev-sibling node t))
   'backward))


(defun f90-ts-mark-region-next-sibling ()
  "Mark next sibling of node determined by current active region.
If the node spans the current region, then mark its next sibling.
Otherwise mark the region spanned by the node itself (like enlarge-region)."
  (interactive)
  (f90-ts--mark-region-relative
   (lambda (node)
     (treesit-node-next-sibling node t))
   'forward))


(defun f90-ts-mark-region-last-sibling ()
  "Mark last sibling of node determined by current active region.
If the node spans the current region, then mark its last sibling.
Otherwise mark the region spanned by the node itself (like enlarge-region)."
  (interactive)
  (f90-ts--mark-region-relative
   (lambda (node)
     (when-let* ((parent (treesit-node-parent node)))
       (treesit-node-child parent -1 t)))
   'forward))


;;;-----------------------------------------------------------------------------
;;; Comment region using some prefix

(defun f90-ts--comment-region-ins-del-line (prefix prefix-trimmed uncomment-re)
  "Insert or delete comment PREFIX on the current line.
PREFIX-TRIMMED is the trimmed PREFIX and UNCOMMENT-RE is a regexp to match
the prefix for uncommenting the line if already commented."
  (cond
   ((looking-at uncomment-re)
    (let ((m-beg (match-beginning 1)))
      (if f90-ts-comment-prefix-keep-indent
          ;; preserve current indentation
          (let ((m-end (match-end 1)))
            (delete-region m-beg m-end)
            (goto-char m-beg)
            (insert (make-string (- m-end m-beg) ?\s)))
        ;; remove prefix, including trailing blanks, as best as possible
        (let ((prefix-end (+ m-beg
                             (f90-ts--common-prefix-length prefix m-beg))))
          (delete-region m-beg prefix-end))))
    ;; there is no way (in particular in conjunction with comment prefixes which
    ;; are indented like code [option "indent"]) to preserve original amount of
    ;; trailing blanks, to avoid build up of trailing blanks in comment-uncomment
    ;; cycle, delete blanks on empty lines
    (when (f90-ts--point-on-empty-line-p)
      (delete-region (line-beginning-position) (line-end-position))))

   ((= (line-beginning-position) (line-end-position))
    ;; avoid trailing blanks on empty lines, but preserve trailing blanks
    ;; if present
    (insert prefix-trimmed))

   (t
    (insert prefix))))


(defun f90-ts--comment-region-ins-del (beg end prefix)
  "Insert or delete PREFIX at each line between BEG and END."
  (let* ((prefix-trimmed (string-trim-right prefix))
         (prefix-trimmed-re (regexp-quote prefix-trimmed))
         (uncomment-re (concat "[ \t]*\\(?1:" prefix-trimmed-re "\\)")))
    (goto-char beg)
    (beginning-of-line)
    (cl-loop
     do (f90-ts--comment-region-ins-del-line prefix
                                             prefix-trimmed
                                             uncomment-re)
     while (and (zerop (forward-line 1))
                (< (point) end)))))


(defun f90-ts--comment-region-adjust (beg end prefix)
  "Adjust indentation of code between BEG and END commented by PREFIX.
After pasting PREFIX and indenting the commented region, the commented code
is adjusted to preserve original indentation as far as possible.
This depends on option `f90-ts-comment-prefix-keep-indent'.  It also takes into
account, that different types of prefixes might be indented differently,
depending on `f90-ts-special-comment-rules'."
  (goto-char end)
  ;; if end marker is at end of line, skip that line
  (if (bolp)
      (forward-line -1)
    (beginning-of-line))

  (let* ((prefix-re (regexp-quote prefix))
         (adjust-re (concat "\\(?1:\\(?2:\\s-*\\)" prefix-re "\\)\\(?3:\\s-*\\)"))
         (min-len-after
          ;; determine maximal number of blanks we can delete in each line safely,
          ;; using the same number for each line preserves relative indentation
          (cl-loop
           do (beginning-of-line)
           if (looking-at adjust-re)
           minimize (let* ((cap-group-before (if f90-ts-comment-prefix-keep-indent 1 2))
                           (len-before (length (match-string cap-group-before)))
                           (after (match-string 3)))
                      (min len-before (length after)))
           while (and (> (point) beg)
                      (zerop (forward-line -1))))))

    ;; delete blanks uniformly in a second pass,
    ;; but only if blanks can be removed at all
    (when (and min-len-after
               (> min-len-after 0))
      (goto-char end)
      (if (bolp)
          (forward-line -1)
        (beginning-of-line))
      (cl-loop
       do (when (looking-at adjust-re)
            (delete-region (match-beginning 3)
                           (+ (match-beginning 3) min-len-after)))
       while (and (> (point) beg)
                  (zerop (forward-line -1)))))))


;; The following code was originally adapted from `f90.el' (part of GNU Emacs).
(defun f90-ts-comment-region-with-prefix (beg-region end-region prefix)
  "Comment/uncomment every line in the region using comment PREFIX.
Region is given by BEG-REGION and END-REGION.

Insert comment prefix at every line in the region, taking special comment
rules for indentation of comment prefix into account.

If the prefix is already present, then remove it and uncomment the line.

Note that prefixes are allowed to have trailing blanks.  These are inserted
as well.  However, for uncommenting, the trimmed prefix is used."
  (let (beg-marker end-marker)
    (unwind-protect
        (progn
          (setq beg-marker (copy-marker beg-region))
          (setq end-marker (copy-marker end-region t))
          ;; pass 1 (insert/delete comment prefix)
          (f90-ts--comment-region-ins-del beg-marker end-marker prefix)
          ;; pass 2
          (f90-ts--indent-region-aux beg-marker end-marker)
          ;; pass 3 (adjust indentation within commented part)
          (f90-ts--comment-region-adjust beg-marker end-marker prefix)

          (goto-char end-marker))
      (set-marker beg-marker nil)
      (set-marker end-marker nil))))


(defun f90-ts-comment-region-default (beg-region end-region)
  "Comment/uncomment every line in the region using default !!$ prefix.
Region is given by BEG-REGION and END-REGION."
  (interactive "*r")
  (f90-ts-comment-region-with-prefix beg-region
                                     end-region
                                     f90-ts-comment-region-prefix))


(defun f90-ts-comment-region-custom (beg-region end-region prefix)
  "Comment/uncomment every line in the region using custom PREFIX.
Region is given by BEG-REGION and END-REGION.
If called interactively, prompt for a prefix from
`f90-ts-extra-comment-prefixes' and `f90-ts-comment-region-prefix'."
  (interactive
   (list
    (progn
      (barf-if-buffer-read-only)
      (region-beginning))
    (region-end)
    (completing-read "choose comment prefix: "
                     (append f90-ts-extra-comment-prefixes
                             (list f90-ts-comment-region-prefix))
                     nil t nil nil (car f90-ts-extra-comment-prefixes))))
  (f90-ts-comment-region-with-prefix beg-region
                                     end-region
                                     prefix))


;;;-----------------------------------------------------------------------------
;;; Imenu and navigation: queries and further properties

(defconst f90-ts--nav-queries
  `(("program"
     :label   "program"
     :capture name_program
     :query   "(program (program_statement \"program\" (name) @name_program))")

    ("module"
     :label   "module"
     :capture name_module
     :query   "(module (module_statement \"module\" (name) @name_module))")

    ("submodule"
     :label   "submodule"
     :capture name_submodule
     :query   "(submodule (submodule_statement \"submodule\" (name) @name_submodule))")

    ("subroutine"
     :label   "subroutine"
     :capture name_subroutine
     :query   "(subroutine (subroutine_statement \"subroutine\" name: (name) @name_subroutine))")

    ("function"
     :label   "function"
     :capture name_function
     :query   "(function (function_statement \"function\" name: (name) @name_function))")

    ("module_procedure"
     :label   "module procedure"
     :capture name_module_proc
     :query   "(module_procedure (module_procedure_statement \"module\" \"procedure\" name: (name) @name_module_proc))")

    ("derived_type_definition"
     :label   "derived type"
     :capture name_dt_type
     :query   "(derived_type_definition (derived_type_statement \"type\" (_) * (type_name) @name_dt_type))")

    ("interface"
     :label   "interface"
     :capture name_interface
     :query   ,(concat "(interface (interface_statement (abstract_specifier)?"
                       " \"interface\""
                       " [((name) @name_interface)"
                       "  ((operator) @name_interface)"
                       "  ((assignment) @name_interface)]?"
                       "))"))

    ("variable_declaration"
     :label   "variable"
     :capture name_var_decl
     :query   ,(concat "(variable_declaration"
                       " declarator:"
                       " [((identifier) @name_var_decl)"
                       "  (init_declarator left: (identifier) @name_var_decl)"
                       "  (pointer_init_declarator left: (identifier) @name_var_decl)"
                       "  (sized_declarator (identifier) @name_var_decl)])")
     :leaf t))
  "Query specification and properties for Imenu, nav-buffer and nav-tree menu.
Each entry is a list (KEY PLIST) where KEY is a string returned by the related
Tree-sitter node type, and PLIST may contain:
  :label   Display string used in Imenu and menus.
  :capture Symbol matching the Tree-sitter capture name for the node name.
  :query   Tree-sitter query string capturing the relevant node name.
  :leaf    Non-nil if entries should be treated as leaf nodes (no children).")


(defconst f90-ts--nav-capture-key-alist
  (cl-loop for (key . plist) in f90-ts--nav-queries
           collect (cons (plist-get plist :capture) key))
  "Alist mapping Tree-sitter capture symbols to query-key.
Each entry is (CAPTURE-SYMBOL . KEY) where KEY is the
car of the corresponding entry in `f90-ts--nav-queries'.")


;;;-----------------------------------------------------------------------------
;;; Imenu

(defconst f90-ts--imenu-query-compiled
  (let ((query-string
         (mapconcat
          (lambda (entry)
            (plist-get (cdr entry) :query))
          f90-ts--nav-queries
          "\n")))
    (treesit-query-compile 'fortran query-string))
  "Pre-compiled global query for a one-pass scan to build imenu.")


(defun f90-ts--imenu-spec-for-type (type)
  "Return the plist for TYPE from `f90-ts--nav-queries'."
  (alist-get type f90-ts--nav-queries nil nil #'string=))


(defun f90-ts--imenu-name-pos-fn (node)
  "Return list of (NAME . POSITION) for NODE using its associated imenu query.
This extracts the name by taking the first captured node from the query,
regardless of the capture name symbol used."
  (let* ((type  (treesit-node-type node))
         (spec  (f90-ts--imenu-spec-for-type type))
         (query (plist-get spec :query))
         (caps  (and query (treesit-query-capture node query))))
    (cl-loop for (_ . node) in caps
             collect (cons (treesit-node-text node t)
                           (treesit-node-start node)))))


(defun f90-ts--imenu-group-items (items)
  "Group flat ITEMS list into ((LABEL (NAME . MARKER) ...) ...) for Imenu.
Each element of ITEMS is (LABEL NAME . MARKER)."
  (cl-loop for (label . group) in (seq-group-by #'car items)
           collect (cons label
                         (mapcar (lambda (item)
                                   (cons (cadr item) (caddr item)))
                                 group))))


(defun f90-ts--imenu-captures-to-items (captures)
  "Convert raw CAPTURES from `treesit-query-capture' to a flat list of items.
Items are triples (LABEL NAME MARKER), where LABEL is derived from the
capture symbol via `f90-ts--nav-queries'."
  (cl-loop for (cap-sym . node) in captures
           for key   = (alist-get cap-sym f90-ts--nav-capture-key-alist)
           for label = (and key (plist-get (alist-get key f90-ts--nav-queries) :label))
           when label
           collect (list label
                         (treesit-node-text node t)
                         (set-marker (make-marker)
                                     (treesit-node-start node)))))


(defun f90-ts-simple-imenu ()
  "Return an Imenu index for the current buffer using a single query pass.
Using `treesit-simple-imenu' is far more expensive computationally."
  (let* ((root     (treesit-buffer-root-node))
         (captures (treesit-query-capture root f90-ts--imenu-query-compiled))
         (items    (f90-ts--imenu-captures-to-items captures)))
    (f90-ts--imenu-group-items items)))


;;;-----------------------------------------------------------------------------
;;; Defun and thing

(defun f90-ts--defun-name (node)
  "Return the name of defun NODE, for use in `which-function-mode' etc."
  (caar (f90-ts--imenu-name-pos-fn node)))


(defconst f90-ts--thing-defun-regexp-pred
  (cons
   (concat "^" (regexp-opt '("module"
                             "submodule"
                             "program"
                             "subroutine"
                             "function"
                             "module_procedure"
                             "interface"
                             "derived_type_definition")) "$")
   #'f90-ts--node-named-p)
  "Regexp and predicate for matching node types to determine defun nodes.")


(defconst f90-ts--thing-procedure-regexp-pred
  (cons
   (concat "^" (regexp-opt '("subroutine"
                             "function"
                             "module_procedure")) "$")
   #'f90-ts--node-named-p)
  "Regexp and predicate for matching node types to determine procedure nodes.")


(defconst f90-ts--thing-interface-regexp-pred
  (cons
   "^interface$"
   #'f90-ts--node-named-p)
  "Regexp and predicate for matching node types to determine interface nodes.")


(defconst f90-ts--thing-type-regexp-pred
  (cons
   "^derived_type_definition$"
   #'f90-ts--node-named-p)
  "Regexp and predicate for matching node types to determine derived type nodes.")


(defconst f90-ts--thing-settings
  `((fortran
     (defun     ,f90-ts--thing-defun-regexp-pred)
     (procedure ,f90-ts--thing-procedure-regexp-pred)
     (interface ,f90-ts--thing-interface-regexp-pred)
     (type      ,f90-ts--thing-type-regexp-pred)))
  "List of things with regexp and predicates to identify relevant nodes.")


(defun f90-ts--end-of-thing-trimmed (thing &optional arg tactic)
  "Execute `treesit-end-of-thing' with trimming.
Arguments THING, ARG and TACTIC are the same as for `treesit-end-of-thing'.

Use a trimmed end of node by skipping trailing whitespace
characters."
  ;; to avoid going to end of non-trimmed node, skip whitespace (trailing)
  ;; characters, if skipped whitespace characters are not trailing, then it
  ;; should still make no difference
  (skip-chars-forward " \t\n")
  (f90-ts--end-of-thing thing arg tactic)
  ;; in case of a non-trimmed node with trailing blanks, skip backwards
  (skip-chars-backward " \t\n"))


(defmacro f90-ts--define-thing-commands (thing label)
  "Define next/prev/beginning/end-of navigation commands for THING.
LABEL is used in the generated docstrings."
  (let ((next (intern (format "f90-ts-thing-next-%s" thing)))
        (prev (intern (format "f90-ts-thing-prev-%s" thing)))
        (beg  (intern (format "f90-ts-thing-beginning-of-%s" thing)))
        (end  (intern (format "f90-ts-thing-end-of-%s" thing))))
    `(progn
       (defun ,next () ,(format "Move to next %s." label)
         (interactive)
         (when-let* ((pos (f90-ts--navigate-thing (point) 1 ',thing)))
           (goto-char pos)))
       (defun ,prev () ,(format "Move to previous %s." label)
         (interactive)
         (when-let* ((pos (f90-ts--navigate-thing (point) -1 ',thing)))
           (goto-char pos)))
       (defun ,beg () ,(format "Move to beginning of current %s." label)
         (interactive)
         (f90-ts--beginning-of-thing ',thing))
       (defun ,end () ,(format "Move to end of current %s." label)
         (interactive)
         (f90-ts--end-of-thing-trimmed ',thing)))))


(f90-ts--define-thing-commands procedure "procedure")
(f90-ts--define-thing-commands type "derived type")
(f90-ts--define-thing-commands interface "interface")


;;;-----------------------------------------------------------------------------
;;; about and documentation for menu

(defun f90-ts--snapshot-version-p ()
  "Return non-nil if this is a snapshot version."
  (string-suffix-p "-snapshot" f90-ts-mode-version))


(defun f90-ts--github-raw-url ()
  "Return the github url for raw content."
  (string-replace "github.com" "raw.githubusercontent.com" f90-ts--github-url))


(defun f90-ts--git-ref ()
  "Return the git reference used for online documentation.
For snapshot version use the main branch (which might be out of sync with
current version), otherwise use the tag derived from version.
The tag is version string prefixed by \"v\"."
  (if (f90-ts--snapshot-version-p)
      "main"
    (concat "v" f90-ts-mode-version)))


(defun f90-ts--strip-markdown-links ()
  "Replace Markdown links [text](url) by plain text.
This is done as neither internal nor external links currently work
in `markdown-view-mode'."
  (goto-char (point-min))
  (while (re-search-forward
          "\\[\\([^]]+\\)\\](\\([^)]*\\))"
          nil t)
    (replace-match "\\1" t nil)))


(declare-function url-insert-file-contents "url-handlers"
                  (url &optional visit beg end replace))

(defun f90-ts--browse-doc (doc-name)
  "Open the online document DOC-NAME from the github repository.
If `markdown-view-mode' or github variant `gfm-view-mode' from the
package `markdown-mode' are available, then use these."
  (when (f90-ts--snapshot-version-p)
    (message "Opening %s from the current development branch main." doc-name))

  (let ((md-view-mode (cond
                       ((fboundp 'gfm-view-mode)      'gfm-view-mode)
                       ((fboundp 'markdown-view-mode) 'markdown-view-mode))))
    (if md-view-mode
      (let ((url (format "%s/%s/%s"
                         (f90-ts--github-raw-url)
                         (f90-ts--git-ref)
                         doc-name))
            (buffer-name (format "*f90-ts-mode %s*" doc-name)))
        (with-current-buffer (get-buffer-create buffer-name)
          (require 'url)
          (erase-buffer)
          (url-insert-file-contents url)
          (f90-ts--strip-markdown-links)
          ;; use markdown-mode if available
          (funcall md-view-mode)
          (pop-to-buffer (current-buffer))))
      ;; open browser
      (message "Install markdown-mode to view %s directly in a buffer." doc-name)
      (browse-url
       (format "%s/blob/%s/%s"
               f90-ts--github-url
               (f90-ts--git-ref)
               doc-name)))))


(defun f90-ts--browse-readme ()
  "Open the online document \"README.md\" from the github repository."
  (interactive)
  (f90-ts--browse-doc "README.md"))


(defun f90-ts--browse-manual ()
  "Open the online document \"MANUAL.md\" from the github repository."
  (interactive)
  (f90-ts--browse-doc "MANUAL.md"))


(defun f90-ts-mode-about ()
  "Display information about `f90-ts-mode'."
  (interactive)
  (with-help-window "*About f90-ts-mode*"
    (let ((version-line (format "version: f90-ts-mode %s" f90-ts-mode-version)))
      (princ version-line)
      (princ "\n")
      (princ (make-string (string-width version-line) ?-))
      (princ "\n"))
    (princ f90-ts--about-text)
    (princ "\nRepository:\n")
    (princ f90-ts--github-url)

    (insert "\n\nDocumentation")
    (insert
     (if (f90-ts--snapshot-version-p)
         "  (current development branch: main)\n\n"
       (format "  (release %s)\n\n" f90-ts-mode-version)))

    (insert-text-button
     "Open README from github"
     'follow-link t
     'action (lambda (_)
               (f90-ts--browse-doc "README.md")))
    (insert "\n")

    (insert-text-button
     "Open MANUAL from github"
     'follow-link t
     'action (lambda (_)
               (f90-ts--browse-doc "MANUAL.md")))
    (insert "\n")))


;;;-----------------------------------------------------------------------------
;;; menu definition

(easy-menu-define f90-ts-mode-menu f90-ts-mode-map
  "Menu for `f90-ts-mode'."
  '("Fortran"
    ("Indent"
     ;; `indent-for-tab-command' invokes `f90-ts-indent-and-complete-line',
     ;; but we use `indent-for-tab-command' to have keybinding shown properly
     ["Indent line"                 indent-for-tab-command             :active t]
     ["Indent line (alt 2)"         f90-ts-indent-for-tab-command-2    :active t]
     ["Indent line (alt 3)"         f90-ts-indent-for-tab-command-3    :active t]
     ["Indent & complete statement" f90-ts-indent-and-complete-stmt    :active t]
     ["Indent & complete region"    f90-ts-indent-and-complete-region  :active (region-active-p)]
     "---"
     ["Complete end statements in region" f90-ts-complete-smart-end-region :active t])
    ("Break & Join lines"
     ["Break line"          f90-ts-break-line      :active t]
     ["Join with prev line" f90-ts-join-line-prev  :active t]
     ["Join with next line" f90-ts-join-line-next  :active t])
    ("Comment"
     ["Comment/uncomment region (default prefix)" f90-ts-comment-region-default :active (region-active-p)]
     ["Comment/uncomment region (custom prefix)"  f90-ts-comment-region-custom  :active (region-active-p)])
    ("Mark region"
     ["Enlarge"               f90-ts-mark-region-enlarge            :active t]
     ["Shrink to first child" f90-ts-mark-region-shrink-child-first :active (region-active-p)]
     ["Shrink to last child"  f90-ts-mark-region-shrink-child-last  :active (region-active-p)]
     ["First sibling"         f90-ts-mark-region-first-sibling      :active (region-active-p)]
     ["Previous sibling"      f90-ts-mark-region-prev-sibling       :active (region-active-p)]
     ["Next sibling"          f90-ts-mark-region-next-sibling       :active (region-active-p)]
     ["Last sibling"          f90-ts-mark-region-last-sibling       :active (region-active-p)])
    "---"
    ("Defun & Thing"
     ["Beginning of defun" beginning-of-defun :active t]
     ["End of defun"       end-of-defun       :active t]
     ["Mark defun"         mark-defun         :active t]
     "---"
     ["Narrow to defun"    narrow-to-defun    :active t]
     ["Widen"              widen              :active (buffer-narrowed-p)]
     "---"
     ["Next procedure"          f90-ts-thing-next-procedure          :active t]
     ["Prev procedure"          f90-ts-thing-prev-procedure          :active t]
     ["Beginning of procedure"  f90-ts-thing-beginning-of-procedure  :active t]
     ["End of procedure"        f90-ts-thing-end-of-procedure        :active t]
     "---"
     ["Next type"               f90-ts-thing-next-type               :active t]
     ["Prev type"               f90-ts-thing-prev-type               :active t]
     ["Beginning of type"       f90-ts-thing-beginning-of-type       :active t]
     ["End of type"             f90-ts-thing-end-of-type             :active t]
     "---"
     ["Next interface"          f90-ts-thing-next-interface          :active t]
     ["Prev interface"          f90-ts-thing-prev-interface          :active t]
     ["Beginning of interface"  f90-ts-thing-beginning-of-interface  :active t]
     ["End of interface"        f90-ts-thing-end-of-interface        :active t])
    ("Xref"
     ["Find definition"  xref-find-definitions :active t]
     ["Find references"  xref-find-references  :active t]
     ["Find apropos"     xref-find-apropos     :active t]
     "---"
     ["Go back"          xref-go-back          :active t]
     ["Go forward"       xref-go-forward       :active t])
    "---"
    ["Open navigation side buffer" f90-ts-nav-buffer-open   :visible (featurep 'f90-ts-nav) :active t]
    ["Focus navigation side buffer" f90-ts-nav-buffer-focus :visible (featurep 'f90-ts-nav) :active t]
    "---"
    ["Customize f90-ts"  (customize-group 'f90-ts) :active t]
    ["About f90-ts-mode" f90-ts-mode-about t]
    ["README (GitHub)"   f90-ts--browse-readme t]
    ["MANUAL (GitHub)"   f90-ts--browse-manual t]))


;;;-----------------------------------------------------------------------------

;;;###autoload
(define-derived-mode f90-ts-mode prog-mode "F90[TS]"
  "Major mode for editing Fortran 90+ files, using tree-sitter library."
  :group 'f90-ts
  :syntax-table f90-ts-mode-syntax-table

  ;; check if treesit has a ready parser for 'fortran
  (unless (treesit-available-p)
    (error "Tree-sitter support is not available"))

  ;; create parser or report error
  (if (treesit-ready-p 'fortran)
      (treesit-parser-create 'fortran)
    (error
     (concat "Tree-sitter parser for 'fortran not ready. "
             "Run `M-x treesit-install-language-grammar RET fortran RET' "
             "or ensure treesit-language-source-alist points to a built grammar.")))

  ;; set font-lock feature list
  (setq-local treesit-font-lock-feature-list
              '((comment preproc error)                          ; level 1
                (builtin keyword string type)                    ; level 2
                (constant number escape-sequence)                ; level 3
                (function variable operator bracket delimiter))) ; level 4

  ;; use the pre-defined font-lock rules variable
  (setq-local treesit-font-lock-settings (f90-ts-font-lock-rules))

  ;; use the pre-defined indentation rules variable
  (setq-local treesit-simple-indent-rules (f90-ts-indent-rules))

  ;; set Imenu
  (setq-local imenu-create-index-function #'f90-ts-simple-imenu)

  ;; set Defun stuff
  (setq-local treesit-defun-type-regexp f90-ts--thing-defun-regexp-pred)
  (setq-local treesit-defun-name-function #'f90-ts--defun-name)
  (setq-local treesit-defun-tactic 'nested)  ; or 'top-level?
  (setq-local treesit-thing-settings f90-ts--thing-settings)

  ;; this setup function must be called after setting variables above
  (treesit-major-mode-setup)

  ;; set indentation functions (both add smart end completion before
  ;; indentation, so no hook available); this must be done after
  ;; calling treesit-major-mode-setup
  (setq-local indent-line-function #'f90-ts-indent-and-complete-line)
  (setq-local indent-region-function #'f90-ts-indent-and-complete-region)

  (add-hook 'xref-backend-functions #'f90-ts-xref-backend nil t)

  ;;(setq-local treesit--font-lock-verbose t)
  ;;(setq-local treesit--indent-verbose t)

  ;; provide mode name
  (setq-local mode-name "F90-TS"))


;;;-----------------------------------------------------------------------------

(provide 'f90-ts-mode)

;;; f90-ts-mode.el ends here
