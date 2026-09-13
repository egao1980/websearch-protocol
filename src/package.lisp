(defpackage #:websearch-protocol
  (:use #:cl)
  (:nicknames #:stack-websearch)
  (:export #:websearch-error
           #:websearch-error-message
           #:websearch-http-error
           #:websearch-http-error-status
           #:websearch-denied
           #:websearch-denied-status
           #:call-with-websearch-restarts
           #:with-websearch-restarts
           #:invoke-retry

           #:search-hit
           #:search-hit-p
           #:make-search-hit
           #:search-hit-url
           #:search-hit-title
           #:search-hit-snippet
           #:search-hit-rank
           #:search-hit-source

           #:websearch-backend
           #:websearch-backend-p
           #:*websearch-backend*

           #:search-web
           #:fetch-page
           #:strip-html-tags
           #:extract-page-text

           #:searxng-backend
           #:searxng-backend-p
           #:make-searxng-backend
           #:use-searxng-backend
           #:searxng-base-url
           #:searxng-language
           #:searxng-categories
           #:searxng-search-params
           #:parse-searxng-results

           #:mock-websearch-backend
           #:mock-websearch-backend-p
           #:make-mock-websearch-backend
           #:use-mock-websearch-backend
           #:mock-websearch-hits
           #:mock-websearch-pages
           #:mock-websearch-denied
           #:mock-websearch-handler

           #:web-search-adapter
           #:web-search-adapter-backend
           #:make-web-search-adapter
           #:make-websearch-catalogue
           #:register-websearch-backend))

(in-package #:websearch-protocol)
