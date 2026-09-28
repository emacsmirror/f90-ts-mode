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

;; break, join and all fill operations
(require 'f90-ts-break-join-fill)


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
