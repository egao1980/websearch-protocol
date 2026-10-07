(in-package #:websearch-protocol)

;;; Colocated default backend: SearXNG JSON API.
;;; GET {base-url}/search?q=…&format=json via http-protocol when bound.

(defclass searxng-backend (websearch-backend)
  ((base-url :initarg :base-url :accessor searxng-base-url
             :initform "http://localhost:8080")
   (language :initarg :language :accessor searxng-language :initform nil)
   (categories :initarg :categories :accessor searxng-categories :initform nil)))

(defun searxng-backend-p (object)
  (typep object 'searxng-backend))

(defun make-searxng-backend (&key (base-url "http://localhost:8080")
                                  language categories)
  (make-instance 'searxng-backend
                 :base-url base-url
                 :language language
                 :categories categories))

(defun use-searxng-backend (&rest args &key &allow-other-keys)
  (setf *websearch-backend* (apply #'make-searxng-backend args)))

(defun %join-url (base path)
  (format nil "~a/~a"
          (string-right-trim '(#\/) (or base ""))
          (string-left-trim '(#\/) path)))

(defun %freshness-time-range (freshness)
  (etypecase freshness
    (null nil)
    (keyword (string-downcase (symbol-name freshness)))
    (string freshness)))

(defun %compose-query (query site)
  (if (and site (plusp (length (string site))))
      (format nil "~a site:~a" query site)
      query))

(defun searxng-search-params (backend query &key count freshness site)
  "Query alist for GET /search. COUNT is applied after parse, not sent."
  (declare (ignore count))
  (append (list (cons "q" (%compose-query query site))
                (cons "format" "json"))
          (let ((tr (%freshness-time-range freshness)))
            (when tr (list (cons "time_range" tr))))
          (when (searxng-language backend)
            (list (cons "language" (searxng-language backend))))
          (when (searxng-categories backend)
            (list (cons "categories" (searxng-categories backend))))))

(defun %limit-hits (hits count)
  (if (and count (integerp count) (>= count 0))
      (subseq hits 0 (min count (length hits)))
      hits))

(defun %searxng-hit (item rank)
  (make-search-hit
   :url (%jget item "url")
   :title (%jget item "title")
   :snippet (or (%jget item "content") (%jget item "snippet"))
   :rank (or (%jget item "position")
             (let ((positions (%as-list (%jget item "positions"))))
               (when positions (first positions)))
             rank)
   :source (or (%jget item "engine")
               (let ((engines (%as-list (%jget item "engines"))))
                 (when engines (first engines))))))

(defun parse-searxng-results (decoded &key count)
  "Map a decoded SearXNG JSON object (hash-table / plist) to SEARCH-HIT list."
  (let ((hits (loop for item in (%as-list (%jget decoded "results"))
                    for rank from 1
                    collect (%searxng-hit item rank))))
    (%limit-hits hits count)))

(defmethod search-web ((backend searxng-backend) query &key count freshness site)
  (check-type query string)
  (let* ((url (%join-url (searxng-base-url backend) "search"))
         (params (searxng-search-params backend query
                                        :count count
                                        :freshness freshness
                                        :site site))
         (response (%http-get url
                              :params params
                              :timeout *search-web-timeout*
                              :headers '(("accept" . "application/json")))))
    (%check-http-status (%response-status response))
    (parse-searxng-results (%json-decode (%body-string (%response-body response)))
                           :count count)))

(defmethod fetch-page ((backend searxng-backend) url)
  (check-type url string)
  (when (%binary-url-p url)
    (return-from fetch-page nil))
  (when (and (%url-looks-like-pdf url) (null (%doc-extract-package)))
    (return-from fetch-page nil))
  (let ((response (%http-get url
                             :timeout *fetch-page-timeout*
                             :headers '(("accept" . "text/html,application/xhtml+xml;q=0.9,text/plain;q=0.8,*/*;q=0.1")))))
    (%check-http-status (%response-status response))
    (extract-fetched-page (%body-string (%response-body response))
                          :content-type (%response-header response "content-type")
                          :url url)))
