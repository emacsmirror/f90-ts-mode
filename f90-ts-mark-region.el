;;; f90-ts-mark-region.el --- Mark region operations for f90-ts-mode -*- lexical-binding: t; -*-

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

;; Provide tree-sitter based mark region operations for `f90-ts-mode'.
;; Provided operations are shrinking and enlaring a region based on the tree
;; structure and moving a marked region to some sibling.

;;; Code:

(require 'cl-lib)
(require 'treesit)

;; defface and defcustom stuff
(require 'f90-ts-custom)

;; provide workarounds and missing functions
(require 'f90-ts-workaround)

;; auxiliary stuff
(require 'f90-ts-auxiliary)

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

(provide 'f90-ts-mark-region)

;;; f90-ts-mark-region.el ends here
