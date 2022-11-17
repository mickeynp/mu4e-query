====================
 mu4e query builder
====================

This simple library builds valid ``mu find`` queries from simple and idiomatic S-expression forms.

For instance:

.. code-block:: common-lisp

   ELISP> (mu4e-make-query '(and (subject "Your Festivus Catalogue is on its way!") (to "costanza@example.com")))
   "(subject:\"Your Festivus Catalogue is on its way!\" and to:costanza@example.com)"

Instead of wrangling strings, you can build your queries freely using variables and nested forms to meet your needs.

Here's an example that configures ``mu4e-bookmarks``:

.. code-block:: common-lisp

    (setq mu4e-bookmarks `((:name "Shared inbox"
                            :query ,(mp-mu4e-make-query
                                     '(and (not (flag trashed)) (maildir (regex "Inbox$"))))
                            :key ?i))

All known features of ``mu find`` are supported, including:

- Automatic quoting when white spaces are used
- Support for free-form searches
- String fallback if you want to mix S-expressions and ``mu`` queries
- Full support for all flags and fields, including shorthands and aliases
- Range queries (for ``date`` and ``size``) are also supported
- Several helper forms that simplify query building, including ``(rx ...)`` for Emacsy regex generation
- and ``(one-of ...)`` and ``(all-of ...)`` forms that generate logical ``or`` or ``and`` queries for a field, to speed up query writing

============
 How to use
============

Install this module somewhere then ``require`` it, and call ``mu4e-make-query``. See its docstring (or the commentary in ``mu4e-query.el``) for more information.

Fields and Flags
================

Both shorthands -- like ``f``, ``b``, ``p``, etc. -- and their longform field names work.

You can express flags with either their long-form or shorthand names also. Date and size ranges also work.


Easy Regex Generation
=====================

The ``(regex ...)`` form generates an ed-style regex:


.. code-block:: common-lisp

   ELISP> (mu4e-make-query '(from (rx (| "George" "Frank"))))
   "from:/\\(?:Frank\\|George\\)/"

But you can also use Emacs's excellent ``rx`` package to generate complex regex patterns. Note, though, that ``mu`` does not use Emacs's regex engine, so there are differences:

   ELISP> (mu4e-make-query '(from (regex "[FG] Costanza")))
   "from:/[FG] Costanza/"

One of / All of
===============

Instead of repeating yourself if you have a range of fields that must match one or -- or all of -- a set of a values, you can use the helper forms ``(one-of ...)`` and ``(all-of ...)`` instead:

.. code-block:: common-lisp

    ELISP> (mu4e-make-query '(from (one-of "elaine benez" "cosmo kramer")))
    "(from:\"elaine benez\" or from:\"cosmo kramer\")"
