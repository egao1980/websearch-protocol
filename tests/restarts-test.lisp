(in-package #:websearch-protocol/tests)

(deftest missing-backend-signals
  (let ((websearch-protocol:*websearch-backend* nil))
    (ok (signals (websearch-protocol:search-web nil "q")
                 'websearch-protocol:websearch-error))))

(deftest missing-backend-use-value
  (let* ((hit (websearch-protocol:make-search-hit :url "https://ex.test" :title "T"))
         (b (websearch-protocol:make-mock-websearch-backend :hits (list hit)))
         (websearch-protocol:*websearch-backend* nil)
         (hits nil))
    (handler-bind ((websearch-protocol:websearch-error
                    (lambda (c)
                      (use-value b c))))
      (setf hits (websearch-protocol:search-web nil "q")))
    (ok (= 1 (length hits)))
    (ok (equal "https://ex.test"
               (websearch-protocol:search-hit-url (first hits))))))

(deftest denied-signals
  (let ((b (websearch-protocol:make-mock-websearch-backend :denied t)))
    (ok (signals (websearch-protocol:search-web b "q")
                 'websearch-protocol:websearch-denied))))

(deftest denied-use-value
  (let ((b (websearch-protocol:make-mock-websearch-backend :denied t))
        (got :unset))
    (handler-bind ((websearch-protocol:websearch-denied
                    (lambda (c)
                      (use-value '() c))))
      (setf got (websearch-protocol:search-web b "q")))
    (ok (null got))))

(deftest http-error-signals
  (let ((b (websearch-protocol:make-mock-websearch-backend
            :handler (lambda (backend query &key &allow-other-keys)
                       (declare (ignore backend query))
                       (error 'websearch-protocol:websearch-http-error
                              :status 503 :message "down")))))
    (ok (signals (websearch-protocol:search-web b "q")
                 'websearch-protocol:websearch-http-error))))

(deftest http-error-retry
  (let* ((n 0)
         (hit (websearch-protocol:make-search-hit :url "https://ex.test" :title "ok"))
         (b (websearch-protocol:make-mock-websearch-backend
             :handler (lambda (backend query &key &allow-other-keys)
                        (declare (ignore backend query))
                        (incf n)
                        (if (= n 1)
                            (error 'websearch-protocol:websearch-http-error
                                   :status 503 :message "down")
                            (list hit)))))
         (hits nil))
    (handler-bind ((websearch-protocol:websearch-http-error
                    (lambda (c)
                      (websearch-protocol:invoke-retry c))))
      (setf hits (websearch-protocol:search-web b "q")))
    (ok (= 2 n))
    (ok (= 1 (length hits)))
    (ok (equal "ok" (websearch-protocol:search-hit-title (first hits))))))

(deftest fetch-page-missing-use-value
  (let ((b (websearch-protocol:make-mock-websearch-backend))
        (got nil))
    (handler-bind ((websearch-protocol:websearch-error
                    (lambda (c)
                      (use-value "supplied text" c))))
      (setf got (websearch-protocol:fetch-page b "https://missing.test")))
    (ok (equal "supplied text" got))))
