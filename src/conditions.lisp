(in-package #:websearch-protocol)

(define-condition websearch-error (error)
  ((message :initarg :message :reader websearch-error-message :initform nil))
  (:report (lambda (c s)
             (format s "websearch error~@[: ~a~]" (websearch-error-message c)))))

(define-condition websearch-http-error (websearch-error)
  ((status :initarg :status :reader websearch-http-error-status :initform nil))
  (:report (lambda (c s)
             (format s "websearch HTTP error~@[ ~a~]~@[: ~a~]"
                     (websearch-http-error-status c)
                     (websearch-error-message c)))))

(define-condition websearch-denied (websearch-error)
  ((status :initarg :status :reader websearch-denied-status :initform nil))
  (:report (lambda (c s)
             (format s "websearch denied~@[ (HTTP ~a)~]~@[: ~a~]"
                     (websearch-denied-status c)
                     (websearch-error-message c)))))

(defun call-with-websearch-restarts (thunk)
  "Establish RETRY / USE-VALUE around THUNK."
  (tagbody
   :retry
     (return-from call-with-websearch-restarts
       (restart-case (funcall thunk)
         (retry ()
           :report "Retry the websearch operation"
           (go :retry))
         (use-value (value)
           :report "Use a supplied value instead"
           :interactive (lambda ()
                          (format *query-io* "Value to use: ")
                          (force-output *query-io*)
                          (list (read *query-io*)))
           value)))))

(defmacro with-websearch-restarts (&body body)
  `(call-with-websearch-restarts (lambda () ,@body)))

(defun invoke-retry (&optional condition)
  (let ((r (find-restart 'retry condition)))
    (when r (invoke-restart r))))
