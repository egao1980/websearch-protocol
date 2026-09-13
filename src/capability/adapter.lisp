(in-package #:websearch-protocol)

(defclass web-search-adapter (capability-protocol:web-search-capability)
  ((backend :initarg :backend :accessor web-search-adapter-backend :initform nil))
  (:documentation "Implements :web-search WEB-SEARCH via SEARCH-WEB."))

(defun make-web-search-adapter (&key backend)
  (make-instance 'web-search-adapter :backend backend))

(defun %cap-backend (cap)
  (or (web-search-adapter-backend cap) *websearch-backend*))

(defmethod capability-protocol:web-search ((cap web-search-adapter) query
                                           &key count freshness site)
  (search-web (%cap-backend cap) query
              :count count :freshness freshness :site site))

(defun make-websearch-catalogue (&optional backend)
  "Live :world catalogue with a WEB-SEARCH-ADAPTER registered."
  (let ((cat (capability-protocol:make-catalogue :world)))
    (capability-protocol:register-capability
     cat (make-web-search-adapter :backend backend))
    cat))

(defun register-websearch-backend (host &optional backend)
  "Register a web-search adapter for BACKEND on HOST (catalogue or blackboard)."
  (capability-protocol:register-capability
   host (make-web-search-adapter :backend backend)))
