;;; f90-ts-comment-region.el --- Comment and uncomment region for f90-ts-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2025-2026 Martin Stein

;; Author: Martin Stein <mscfd@gmx.net>

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

;; Provide a basic xref implementation for `f90-ts-mode'.  The implementation
;; does not filter semantically and finds many references not in scope at
;; point.  It is not intended to replace a proper xref tool like eglot/lsp.
;; It immediately defers to these tools if those are used.

;; Provide comment and uncomment region for `f90-ts-mode'.  It takes the comment
;; rules in `f90-ts-special-comment-rules' into account to organize indentation
;; of the comment as well as commented code.

;;; Code:

(require 'cl-lib)
(require 'treesit)

;; defface and defcustom stuff
(require 'f90-ts-custom)

;; provide workarounds and missing functions
(require 'f90-ts-workaround)

;; auxiliary stuff and indentation
(require 'f90-ts-auxiliary)
(require 'f90-ts-indent)


;;;-----------------------------------------------------------------------------

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

(provide 'f90-ts-comment-region)

;;; f90-ts-comment-region.el ends here
