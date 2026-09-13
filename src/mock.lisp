(in-package #:websearch-protocol)

;;; In-memory backend for tests — no HTTP.

(defclass mock-websearch-backend (websearch-backend)
  ((hits :initarg :hits :accessor mock-websearch-hits :initform nil)
   (pages :initarg :pages :accessor mock-websearch-pages :initform nil)
   (denied :initarg :denied :accessor mock-websearch-denied :initform nil)
   (handler :initarg :handler :accessor mock-websearch-handler :initform nil)))

(defun mock-websearch-backend-p (object)
  (typep object 'mock-websearch-backend))

(defun make-mock-websearch-backend (&key hits pages denied handler)
  (make-instance 'mock-websearch-backend
                 :hits hits :pages pages :denied denied :handler handler))

(defun use-mock-websearch-backend (&rest args &key &allow-other-keys)
  (setf *websearch-backend* (apply #'make-mock-websearch-backend args)))

(defun %coerce-hit (item)
  (cond
    ((search-hit-p item) item)
    ((and (consp item) (keywordp (car item)))
     (apply #'make-search-hit item))
    (t (error 'websearch-error
              :message (format nil "not a search-hit: ~s" item)))))

(defun %pages-table (pages)
  (if (hash-table-p pages)
      pages
      (let ((table (make-hash-table :test 'equal)))
        (dolist (pair pages table)
          (setf (gethash (car pair) table) (cdr pair))))))

(defmethod search-web ((backend mock-websearch-backend) query
                       &key count freshness site)
  (when (mock-websearch-denied backend)
    (error 'websearch-denied :message "mock websearch denied"))
  (let ((hits (if (mock-websearch-handler backend)
                  (funcall (mock-websearch-handler backend) backend query
                           :count count :freshness freshness :site site)
                  (loop for item in (mock-websearch-hits backend)
                        for rank from 1
                        collect (let ((hit (%coerce-hit item)))
                                  (unless (search-hit-rank hit)
                                    (setf (search-hit-rank hit) rank))
                                  hit)))))
    (%limit-hits (if (and hits (search-hit-p (first hits)))
                     hits
                     (mapcar #'%coerce-hit (%as-list hits)))
                 count)))

(defmethod fetch-page ((backend mock-websearch-backend) url)
  (when (mock-websearch-denied backend)
    (error 'websearch-denied :message "mock websearch denied"))
  (let* ((table (%pages-table (mock-websearch-pages backend)))
         (html (gethash url table)))
    (unless html
      (error 'websearch-error
             :message (format nil "mock has no page for ~s" url)))
    (extract-page-text html :url url)))
