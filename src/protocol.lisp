(in-package #:websearch-protocol)

(defclass search-hit ()
  ((url :initarg :url :accessor search-hit-url :initform nil)
   (title :initarg :title :accessor search-hit-title :initform nil)
   (snippet :initarg :snippet :accessor search-hit-snippet :initform nil)
   (rank :initarg :rank :accessor search-hit-rank :initform nil)
   (source :initarg :source :accessor search-hit-source :initform nil)))

(defun search-hit-p (object)
  (typep object 'search-hit))

(defun make-search-hit (&key url title snippet rank source)
  (make-instance 'search-hit
                 :url url :title title :snippet snippet
                 :rank rank :source source))

(defclass websearch-backend () ())

(defun websearch-backend-p (object)
  (typep object 'websearch-backend))

(defvar *websearch-backend* nil
  "Current WEBSEARCH-BACKEND, or NIL.")

(defun %ensure-backend (&optional (backend *websearch-backend*))
  (or backend
      (restart-case
          (error 'websearch-error
                 :message "*websearch-backend* is nil — bind a backend")
        (use-value (supplied)
          :report "Use a supplied websearch backend"
          :interactive (lambda ()
                         (format *query-io* "Websearch backend: ")
                         (force-output *query-io*)
                         (list (read *query-io*)))
          supplied))))

(defgeneric search-web (backend query &key count freshness site)
  (:documentation "Search QUERY via BACKEND. → list of SEARCH-HIT.
   COUNT limits hits. FRESHNESS is :day/:week/:month/:year or a string
   (SearXNG time_range). SITE restricts to a hostname (appended as site:)."))

(defgeneric fetch-page (backend url)
  (:documentation "Fetch URL and return extracted readable text."))

(defmethod search-web :around (backend query &key count freshness site)
  (declare (ignore count freshness site))
  (call-with-websearch-restarts (lambda () (call-next-method))))

(defmethod fetch-page :around (backend url)
  (declare (ignore url))
  (call-with-websearch-restarts (lambda () (call-next-method))))

(defmethod search-web ((backend null) query &key count freshness site)
  (search-web (%ensure-backend backend) query
              :count count :freshness freshness :site site))

(defmethod fetch-page ((backend null) url)
  (fetch-page (%ensure-backend backend) url))

;;; --- soft-use helpers ------------------------------------------------------

(defun %find-symbol (package name)
  (let ((pkg (find-package package)))
    (and pkg (find-symbol name pkg))))

(defun %bound-symbol-value (package name)
  (let ((s (%find-symbol package name)))
    (and s (boundp s) (symbol-value s))))

(defun %funcall (package name &rest args)
  (let ((s (%find-symbol package name)))
    (unless (and s (fboundp s))
      (error 'websearch-error
             :message (format nil "~a:~a is not available" package name)))
    (apply (fdefinition s) args)))

(defun %as-list (object)
  (cond
    ((null object) nil)
    ((and (vectorp object) (not (stringp object))) (coerce object 'list))
    ((listp object) object)
    (t (list object))))

(defun %jget (object key)
  "Lookup KEY on a JSON object (hash-table string keys, or plist/alist)."
  (let ((keys (etypecase key
                (string (list key))
                (symbol (list (string-downcase (symbol-name key))
                              (symbol-name key)
                              key)))))
    (cond
      ((hash-table-p object)
       (dolist (k keys)
         (multiple-value-bind (val present) (gethash k object)
           (when present (return-from %jget val))))
       nil)
      ((and (consp object) (keywordp (car object)))
       (getf object (if (keywordp key)
                        key
                        (intern (string-upcase (string key)) :keyword))))
      ((listp object)
       (dolist (k keys)
         (let ((cell (assoc k object :test #'equal)))
           (when cell (return-from %jget (cdr cell)))))
       nil)
      (t nil))))

(defun %soft-utf8 (octets)
  (let ((decode (%find-symbol :encoding-protocol "DECODE")))
    (when (and decode (fboundp decode))
      (ignore-errors (funcall decode octets :encoding :utf-8)))))

(defun %body-string (body)
  (cond
    ((stringp body) body)
    ((null body) "")
    ((and (vectorp body) (not (stringp body)))
     (or (%soft-utf8 body)
         (map 'string #'code-char body)))
    (t (princ-to-string body))))

(defun %http-bound-p ()
  (or (%bound-symbol-value :http-protocol "*HTTP-BACKEND*")
      (%bound-symbol-value :http-protocol "*HTTP-CLIENT*")))

(defun %http-get (url &key params)
  "GET URL via http-protocol SEND when a client/backend is bound."
  (unless (%http-bound-p)
    (error 'websearch-error
           :message "http-protocol client/backend is not bound"))
  (let* ((backend (%bound-symbol-value :http-protocol "*HTTP-BACKEND*"))
         (make-client (%find-symbol :http-protocol "MAKE-HTTP-CLIENT"))
         (client (or (%bound-symbol-value :http-protocol "*HTTP-CLIENT*")
                     (and backend make-client (fboundp make-client)
                          (funcall make-client backend))))
         (make-req (%find-symbol :http-protocol "MAKE-HTTP-REQUEST"))
         (send (%find-symbol :http-protocol "SEND"))
         (request (when (and make-req (fboundp make-req))
                    (funcall make-req :method :get :url url :params params))))
    (unless (and backend client send (fboundp send) request)
      (error 'websearch-error
             :message "http-protocol SEND requires *http-backend*"))
    (handler-case (funcall send backend client request)
      (websearch-error (c)
        (error c))
      (error (c)
        (error 'websearch-error
               :message (format nil "http GET failed: ~a" c))))))

(defun %response-status (response)
  (let ((fn (%find-symbol :http-protocol "RESPONSE-STATUS")))
    (when (and fn (fboundp fn))
      (funcall fn response))))

(defun %response-body (response)
  (let ((fn (%find-symbol :http-protocol "RESPONSE-BODY")))
    (when (and fn (fboundp fn))
      (funcall fn response))))

(defun %check-http-status (status)
  (cond
    ((or (null status) (<= 200 status 299)) nil)
    ((member status '(401 403 451))
     (error 'websearch-denied
            :status status
            :message (format nil "websearch denied (HTTP ~a)" status)))
    (t
     (error 'websearch-http-error
            :status status
            :message (format nil "HTTP ~a" status)))))

(defun %json-decode (source)
  (let* ((decode (%find-symbol :json-protocol "DECODE"))
         (backend (%find-symbol :json-protocol "*JSON-BACKEND*")))
    (unless (and decode (fboundp decode) backend (boundp backend)
                 (symbol-value backend))
      (error 'websearch-error
             :message "json-protocol *json-backend* is unbound"))
    (funcall decode source)))

;;; --- page text -------------------------------------------------------------

(defun %html-entity-char (name)
  (cond
    ((string= name "amp") #\&)
    ((string= name "lt") #\<)
    ((string= name "gt") #\>)
    ((string= name "quot") #\")
    ((string= name "apos") #\')
    ((string= name "nbsp") #\Space)
    ((and (plusp (length name)) (char= (char name 0) #\#))
     (let* ((hex (and (> (length name) 1) (char-equal (char name 1) #\x)))
            (digits (subseq name (if hex 2 1)))
            (code (ignore-errors
                    (parse-integer digits :radix (if hex 16 10)))))
       (when (and code (<= 0 code #x10FFFF) (code-char code))
         (code-char code))))
    (t nil)))

(defun strip-html-tags (html)
  "Drop comments, script/style/noscript, and tags. Decode a few entities.
   Collapse whitespace. Used when no HTML / doc-extract backend is bound."
  (let* ((s (%body-string html))
         (out (make-string-output-stream))
         (i 0)
         (n (length s))
         (last-space t))
    (labels ((starts-p (lit)
               (and (<= (+ i (length lit)) n)
                    (string-equal s lit :start1 i :end1 (+ i (length lit)))))
             (skip-until (lit)
               (let ((pos (search lit s :start2 i :test #'char-equal)))
                 (setf i (if pos (+ pos (length lit)) n))))
             (emit (ch)
               (if (member ch '(#\Space #\Tab #\Newline #\Return #\Page))
                   (unless last-space
                     (write-char #\Space out)
                     (setf last-space t))
                   (progn
                     (write-char ch out)
                     (setf last-space nil)))))
      (loop while (< i n)
            do (cond
                 ((starts-p "<!--") (skip-until "-->"))
                 ((starts-p "<script") (skip-until "</script>"))
                 ((starts-p "<style") (skip-until "</style>"))
                 ((starts-p "<noscript") (skip-until "</noscript>"))
                 ((char= (char s i) #\<)
                  (let ((end (position #\> s :start i)))
                    (setf i (if end (1+ end) n))))
                 ((char= (char s i) #\&)
                  (let ((semi (position #\; s :start (1+ i))))
                    (if (and semi (< (- semi i) 12))
                        (let ((ch (%html-entity-char (subseq s (1+ i) semi))))
                          (if ch
                              (progn (emit ch) (setf i (1+ semi)))
                              (progn (emit #\&) (incf i))))
                        (progn (emit #\&) (incf i)))))
                 (t
                  (emit (char s i))
                  (incf i)))))
    (string-trim '(#\Space) (get-output-stream-string out))))

(defun %doc-extract-package ()
  (or (find-package :doc-extract-protocol)
      (find-package :stack-doc-extract)))

(defun %extract-via-doc-extract (html &optional url)
  "Soft-call doc-extract-protocol:EXTRACT-TEXT when that package exists.
   Do not hard-depend — the protocol may be created in parallel."
  (declare (ignore url))
  (let* ((pkg (%doc-extract-package))
         (extract (and pkg (or (find-symbol "EXTRACT-TEXT" pkg)
                               (find-symbol "EXTRACT" pkg))))
         (backend (and pkg (find-symbol "*DOC-EXTRACT-BACKEND*" pkg))))
    (when (and extract (fboundp extract))
      (cond
        ((and backend (boundp backend) (symbol-value backend))
         (ignore-errors (funcall extract (symbol-value backend) html)))
        (t (ignore-errors (funcall extract html)))))))

(defun %html-backend-bound-p ()
  (%bound-symbol-value :html-protocol "*HTML-BACKEND*"))

(defun %extract-via-html (html)
  (let ((doc (%funcall :html-protocol "PARSE" html)))
    (%funcall :html-protocol "ELEMENT-TEXT" doc)))

(defun extract-page-text (html &key url)
  "Extract readable text. Prefer doc-extract-protocol when loaded, then
   html-protocol:PARSE + ELEMENT-TEXT if *HTML-BACKEND* is bound, else
   STRIP-HTML-TAGS."
  (or (and (%doc-extract-package)
           (%extract-via-doc-extract html url))
      (and (%html-backend-bound-p)
           (%extract-via-html html))
      (strip-html-tags html)))
