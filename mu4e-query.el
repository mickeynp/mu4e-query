;;; mu4e-query.el --- s-expression query builder for mu4e  -*- lexical-binding: t; -*-

;; Copyright (C) 2022  Mickey Petersen

;; Author: Mickey Petersen <mickey@masteringemacs.org>
;; Keywords: email utility

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; S-expression query builder for `mu find'.
;;
;; Build a `mu' QUERY using s-expressions instead of plain strings.
;;
;; All common notation supported by `mu find' also work here, along
;; with a couple of helper forms to speed up complex query building.
;;
;; All fields are supported, in both their abbreviated and complete
;; forms.  The same is true for flags.
;;
;; Flags and fields have their own forms, like so:
;;
;; (subject "Your Festivus Catalogue is on its way")
;;
;; (from "G. Costanza")
;;
;; Whitespaced strings are automatically quoted.
;;
;; You can optionally enable regular expressions for a field in one
;; of two ways:
;;
;; (from (regex "[FG]. Costanza"))
;;
;; (from (rx (| "George" "Frank")))
;;
;; The latter uses Emacs's `rx' package to build the regular
;; expression.  But note that Emacs's regexp engine is not the one
;; that is ultimately used by `mu find', so not all features work
;; the same.
;;
;; If you are searching for distinct values in a field, you can use
;; the `one-of' or `all-of' helper forms to simplify your query:
;;
;; (to (one-of "cosmo@example.com" "van.nostrand@example.com"))
;;
;; This is turned into:
;;
;; (to:cosmo@example.com or to:van.nostrand@example.com)
;;
;; Logical operators such as `not', `or' and `and' also work like they do in Lisp:
;;
;;
;; (and (flag seen) (not (flag trashed)) (from "pennypacker@example.com"))
;;
;; `size' and `date' queries expect simple cons cells like this:
;;
;; (start .. end), (.. end), or (start ..)
;;
;; Where `start' and `end' is either a string, number, nil or absent
;; entirely (to indicate it is unbounded). Constants such as `1w' or
;; `now' also work, in accordance with `mu''s own support for this.
;;
;; There are simple checks in place to prevent invalid flags or
;; fields from getting passed through to `mu', though it is not
;; infallible.
;;
;; You can always revert back to strings for parts of
;; your queries if you so desire. No effort is made to ensure they
;; are correct, though.


;;; Code:

(defconst mu4e--query-fields
  '(bcc h body b cc c changed k embed e file j flags flag g from f maildir m list v message-id
    msgid i mime mime-type y path l priority prio p references r subject s tags tag x thread w to t
    contact recip)
  "List of queryable fields mu supports.")

(defconst mu4e--query-range-fields '(size z date d)
  "List of fields that accept ranges of values.")

(defconst mu4e--query-flags
  '(draft D flagged F passed P replied R seen S trashed T new N signed z encrypted x
    attach a unread u list l personal q calendar c)
  "List of accepted values for the `flag' field.")

(defconst mu4e--query-priority '(low normal high)
  "List of priorities for the `prio' field.")

(defun mu4e--make-field-value (field value)
  "Create a FIELD-VALUE pair for a `mu' query as a string.

If VALUE is a form of `(one-of v1 ... vn)' or `(all-of v1
... vn)' then rewrite VALUE using `mu4e-make-query' into a string
of `and' or `or' for each of its cdr elements as a shorthand for
doing so manually.

If VALUE is not a string or a form -- such as an integer or
symbol -- coerce it to a string.

VALUE is double-quoted if it contains at least one whitespace.

The key-value set is separated with `:' as per the specification
for a mu FIELD query."
  (pcase value
    ;; helper form that expands
    ;;
    ;;    (subject (one-of "a" "b"))
    ;;
    ;; to the query form
    ;;   (or (subject "a") ...)
    ;;
    ;; as a shorthand.
    ((and `(one-of . ,rest))
     (mu4e-make-query `(or ,@(mapcar (lambda (element) `(,field ,element)) rest))))
    ;; ... as above, but using `and' instead of `or'.
    ((and `(all-of . ,rest))
     (mu4e-make-query `(and ,@(mapcar (lambda (element) `(,field ,element)) rest))))
    ;; default behaviour
    ((or (pred stringp) (pred integerp) (pred symbolp) (pred consp))
     (format "%s:%s" field (mu4e-make-query (mu4e--make-quoted-string value))))))

(defun mu4e--make-quoted-string (value)
  "Maybe double-quote VALUE if it has whitespaces."
  (if (and (stringp value)
           (seq-position value ?\ ))
      ;; whitespaced queries must be quoted.
      (format "\"%s\"" value)
    value))

(defun mu4e--make-range-query (field value)
  "Create a range FIELD-VALUE pair for a `mu' query string.

Ranged FIELDs are limited to `date' and `size' field queries.

The expected notation for VALUE is `(start .. end)' where `start' or `end'
can be nil (or absent) to mean unbounded."
  (pcase value
    ((or `(.. ,end) `(nil .. ,end)) (mu4e--make-field-value field (format "..%s" end)))
    ((or `(,start ..) `(,start .. nil)) (mu4e--make-field-value field (format "%s.." start)))
    (`(,start .. ,end) (mu4e--make-field-value field (format "%s..%s" start end)))
    (_ (error "Error: `%s' is not a valid range for `%s'" field value))))

(defun mu4e-make-query (&rest query)
  "Build a `mu' QUERY using s-expressions instead of plain strings.

All common notation supported by `mu find' also work here, along
with a couple of helper forms to speed up complex query building.

All fields are supported, in both their abbreviated and complete
forms.  The same is true for flags.

Flags and fields have their own forms, like so:

   (subject \"Your Festivus Catalogue is on its way\")

   (from \"G. Costanza\")

Whitespaced strings are automatically quoted.

You can optionally enable regular expressions for a field in one
of two ways:

   (from (regex \"[FG]. Costanza\"))

   (from (rx (| \"George\" \"Frank\")))

The latter uses Emacs's `rx' package to build the regular
expression.  But note that Emacs's regexp engine is not the one
that is ultimately used by `mu find', so not all features work
the same.

If you are searching for distinct values in a field, you can use
the `one-of' or `all-of' helper forms to simplify your query:

  (to (one-of \"cosmo@example.com\" \"van.nostrand@example.com\"))

This is turned into:

  (to:cosmo@example.com or to:van.nostrand@example.com)

Logical operators such as `not', `or' and `and' also work like they do in Lisp:


  (and (flag seen) (not (flag trashed)) (from \"pennypacker@example.com\"))

`size' and `date' queries expect simple cons cells like this:

   (start .. end), (.. end), or (start ..)

Where `start' and `end' is either a string, number, nil or absent
entirely (to indicate it is unbounded). Constants such as `1w' or
`now' also work, in accordance with `mu''s own support for this.

There are simple checks in place to prevent invalid flags or
fields from getting passed through to `mu', though it is not
infallible.

You can always revert back to strings for parts of
your queries if you so desire. No effort is made to ensure they
are correct, though."
  (mapconcat
   (lambda (q)
     (pcase q
       ;; ranged field values (`date' and `size')
       ((and `(,field ,value)
             (guard (memq field mu4e--query-range-fields)))
        (pcase value
          ;; we must disambiguate `one-of' / `all-of' helpers here.
          ((or `(one-of . ,_) `(all-of . ,_)) (mu4e--make-field-value field value))
          ;; ... everything else
          (_  (mu4e--make-range-query field value))))
       ;; `prio'-only field values.
       ((and (or `(prio ,prio) `(priority ,prio))
             (guard (or (consp prio) (memq prio mu4e--query-priority))))
        (mu4e--make-field-value 'prio prio))
       ;; `flag'-only field values.
       ((and (or `(flag ,flag) `(flags ,flag) `(g ,flag))
             (guard (or (consp flag) (memq flag mu4e--query-flags))))
        (mu4e--make-field-value 'flag flag))
       ;; all other known, supported fields
       ;; excl. `flag' / `g' / `prio' / `date' / `d' / `size' / `z'.
       ((and (pred consp) `(,field ,value)
             (guard (memq field mu4e--query-fields)))
        (mu4e--make-field-value field value))
       ;; maps to the ed-style /regex/ notation
       (`(regex ,regex) (format "/%s/" regex))
       ;; reifies an `rx' regexp form to a string. note that mu does
       ;; not use Emacs's regexp engine under the hood though.
       (`(rx . ,regex) (format "/%s/" (rx-to-string `(and ,@regex) t)))
       ;; boolean logic
       (`(not . ,rest) (if rest (format "(not %s)" (mapconcat 'mu4e-make-query rest "")) ""))
       (`(or . ,rest) (if rest (format "(%s)" (mapconcat 'mu4e-make-query rest " or ")) ""))
       (`(and . ,rest) (if rest (format "(%s)" (mapconcat 'mu4e-make-query rest " and ")) ""))
       ;; handle string forms as it is possible to search a range of
       ;; fields without a field specifier.
       ((and (pred consp) `(,s)) (mu4e--make-quoted-string (format "%s" s)))
       ;; coalesce strings, integers and symbols into their canonical
       ;; string represenation.
       ((or (pred stringp) (pred integerp) (pred symbolp)) (format "%s" q))
       (_ (error "Error: `%s' is not a valid expression, field, or value" q))))
   query
   " "))

(provide 'mu4e-query)
;;; mu4e-query.el ends here
