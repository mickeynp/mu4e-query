;;; mu4e-query-tests.el --- tests for mu4e-query     -*- lexical-binding: t; -*-

;; Copyright (C) 2022  Mickey Petersen

;; Author: Mickey Petersen <mickey@masteringemacs.org>
;; Keywords:

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

;; Tests for mu4e-query.


;;; Code:

(require 'ert)
(require 'mu4e-query)

(ert-deftest test-mu4e-make-field-value-simple ()
  (should (string= (mu4e--make-field-value 'subject "a") "subject:a"))
  (should (string= (mu4e--make-field-value 'subject 1) "subject:1"))
  (should (string= (mu4e--make-field-value 'subject 'test) "subject:test")))

(ert-deftest test-mu4e-make-field-value-shorthands ()
  (should (string= (mu4e--make-field-value 'subject '(one-of "a" "b" "c")) "(subject:a or subject:b or subject:c)"))
  (should (string= (mu4e--make-field-value 'subject '(all-of "a" "b" "c")) "(subject:a and subject:b and subject:c)"))
  (should-error (string= (mu4e--make-field-value 'subject '(one-of)))))

(ert-deftest test-mu4e-make-range-query ()
  (should (string= (mu4e--make-range-query 'date '(nil .. now)) "date:..now"))
  (should (string= (mu4e--make-range-query 'date '(.. now)) "date:..now"))
  (should (string= (mu4e--make-range-query 'date '(.. "1234")) "date:..1234"))
  (should (string= (mu4e--make-range-query 'date '(now ..)) "date:now.."))
  (should (string= (mu4e--make-range-query 'date '(now .. nil)) "date:now.."))
  (should (string= (mu4e--make-range-query 'date '("1234" ..)) "date:1234.."))
  (should (string= (mu4e--make-range-query 'date '("1w" .. now)) "date:1w..now")))

(ert-deftest test-mu4e-make-query ()
  ;; primitives
  (should (string= (mu4e-make-query '("foo")) "foo"))
  (should (string= (mu4e-make-query '("foo bar")) "\"foo bar\""))
  (should (string= (mu4e-make-query '(12345)) "12345"))
  ;; fields
  (should (string= (mu4e-make-query '(subject "hello world")) "subject:\"hello world\""))
  (should (string= (mu4e-make-query '(s "hello world")) "s:\"hello world\""))
  (should (string= (mu4e-make-query '(prio high)) "prio:high"))
  (should (string= (mu4e-make-query '(flag seen)) "flag:seen"))
  (should-error (string= (mu4e-make-query '(wrong "hello world"))))
  (should-error (string= (mu4e-make-query '(prio wrong))))
  ;; logical operations
  (should (string= (mu4e-make-query '(not (flag seen))) "(not flag:seen)"))
  (should (string= (mu4e-make-query '(not (not (flag seen)))) "(not (not flag:seen))"))
  (should (string= (mu4e-make-query '(and (flag seen) (flag trashed))) "(flag:seen and flag:trashed)"))
  (should (string= (mu4e-make-query '(or (flag seen) (flag trashed))) "(flag:seen or flag:trashed)"))
  (should (string= (mu4e-make-query '(or (flag seen) (flag trashed))) "(flag:seen or flag:trashed)"))
  (should (string= (mu4e-make-query '(or (and (flag seen) (flag trashed)) (from "foo@example.com")))
                   "((flag:seen and flag:trashed) or from:foo@example.com)"))
  ;; regex
  (should (string= (mu4e-make-query '(subject (regex "Hello World[!?]"))) "subject:/Hello World[!?]/"))
  (should (string= (mu4e-make-query '(subject (rx "Hello World" (any "?!")))) "subject:/Hello World[!?]/"))
  ;; combinations
  (should (string= (mu4e-make-query '(or (flag (all-of seen trashed)) (from "foo@example.com")))
                   (mu4e-make-query '(or (and (flag seen) (flag trashed)) (from "foo@example.com")))))
  (should (string= (mu4e-make-query '(or (date (.. now)) (size ("1M" .. "1G"))))
                   (mu4e-make-query '(or (date (nil .. now)) (size (1M .. 1G)))))))

(provide 'mu4e-query-tests)
;;; mu4e-query-tests.el ends here
