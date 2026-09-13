(in-package #:websearch-protocol/tests)

(deftest mock-search-web-returns-hits
  (let* ((hit (websearch-protocol:make-search-hit
               :url "https://example.test/a"
               :title "Example"
               :snippet "A snippet"
               :source "mock"))
         (b (websearch-protocol:make-mock-websearch-backend :hits (list hit)))
         (hits (websearch-protocol:search-web b "example")))
    (ok (= 1 (length hits)))
    (ok (websearch-protocol:search-hit-p (first hits)))
    (ok (equal "https://example.test/a"
               (websearch-protocol:search-hit-url (first hits))))
    (ok (equal "Example" (websearch-protocol:search-hit-title (first hits))))
    (ok (equal "A snippet" (websearch-protocol:search-hit-snippet (first hits))))
    (ok (eql 1 (websearch-protocol:search-hit-rank (first hits))))
    (ok (equal "mock" (websearch-protocol:search-hit-source (first hits))))))

(deftest mock-search-web-respects-count
  (let* ((hits (loop for i from 1 to 4
                     collect (websearch-protocol:make-search-hit
                              :url (format nil "https://ex.test/~a" i)
                              :title (format nil "T~a" i)
                              :rank i)))
         (b (websearch-protocol:make-mock-websearch-backend :hits hits))
         (got (websearch-protocol:search-web b "q" :count 2)))
    (ok (= 2 (length got)))
    (ok (equal "T1" (websearch-protocol:search-hit-title (first got))))))

(deftest fetch-page-strips-html
  (let* ((html (format nil "~
<html><head><style>x{}</style></head>~
<body><h1>Title</h1><p>Hello <b>world</b>.</p>~
<script>alert(1)</script></body></html>"))
         (b (websearch-protocol:make-mock-websearch-backend
             :pages `(("https://ex.test/p" . ,html))))
         (text (websearch-protocol:fetch-page b "https://ex.test/p")))
    (ok (search "Title" text))
    (ok (search "Hello world" text))
    (ng (search "alert" text))
    (ng (search "x{}" text))
    (ng (search "<p>" text))))

(deftest strip-html-tags-entities
  (let ((text (websearch-protocol:strip-html-tags
               "A&amp;B &lt;c&gt; &quot;q&quot;")))
    (ok (search "A&B" text))
    (ok (search "<c>" text))))

(deftest parse-searxng-results
  (let* ((row (make-hash-table :test 'equal))
         (decoded (make-hash-table :test 'equal)))
    (setf (gethash "url" row) "https://lisp.org/")
    (setf (gethash "title" row) "Lisp")
    (setf (gethash "content" row) "A language")
    (setf (gethash "engine" row) "duckduckgo")
    (setf (gethash "results" decoded) (vector row))
    (let ((hits (websearch-protocol:parse-searxng-results decoded)))
      (ok (= 1 (length hits)))
      (ok (equal "https://lisp.org/"
                 (websearch-protocol:search-hit-url (first hits))))
      (ok (equal "Lisp" (websearch-protocol:search-hit-title (first hits))))
      (ok (equal "A language"
                 (websearch-protocol:search-hit-snippet (first hits))))
      (ok (equal "duckduckgo"
                 (websearch-protocol:search-hit-source (first hits))))
      (ok (eql 1 (websearch-protocol:search-hit-rank (first hits)))))))

(deftest searxng-search-params
  (let* ((b (websearch-protocol:make-searxng-backend
             :base-url "http://searx.local/"
             :language "en"))
         (params (websearch-protocol:searxng-search-params
                  b "common lisp"
                  :freshness :month
                  :site "lisp.org")))
    (ok (equal "common lisp site:lisp.org" (cdr (assoc "q" params :test #'equal))))
    (ok (equal "json" (cdr (assoc "format" params :test #'equal))))
    (ok (equal "month" (cdr (assoc "time_range" params :test #'equal))))
    (ok (equal "en" (cdr (assoc "language" params :test #'equal))))))

(deftest searxng-without-http-signals
  (let ((b (websearch-protocol:make-searxng-backend))
        (http (find-package '#:http-protocol)))
    (flet ((run ()
             (ok (signals (websearch-protocol:search-web b "q")
                          'websearch-protocol:websearch-error))))
      (if http
          (progv (remove nil (list (find-symbol "*HTTP-BACKEND*" http)
                                   (find-symbol "*HTTP-CLIENT*" http)))
              '(nil nil)
            (run))
          (run)))))
