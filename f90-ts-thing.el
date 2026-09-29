;;; f90-ts-thing.el --- Things for f90-ts-mode -*- lexical-binding: t; -*-

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

;; Provide things definitions and things based navigation for `f90-ts-mode'.
;; This also requires some care to deal with non-trimmed node spans (some
;; block structures include the newline after the \"end\" statement line).

;;; Code:

(require 'cl-lib)
(require 'treesit)

;; defface and defcustom stuff
(require 'f90-ts-custom)

;; provide workarounds and missing functions for Emacs 29 and grammar
;; variant detection
(require 'f90-ts-workaround)

;; auxiliary stuff and imenu (imenu queries are used via
;; function `f90-ts--imenu-name-pos-fn node' from `f90-ts-imenu')
(require 'f90-ts-auxiliary)
(require 'f90-ts-imenu)


;;;-----------------------------------------------------------------------------

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

(provide 'f90-ts-thing)

;;; f90-ts-thing.el ends here
