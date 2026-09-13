(in-package #:websearch-protocol/tests)

(deftest web-search-adapter
  (let* ((hit (websearch-protocol:make-search-hit
               :url "https://ex.test" :title "Ex" :snippet "s" :rank 1))
         (backend (websearch-protocol:make-mock-websearch-backend
                   :hits (list hit)))
         (cap (websearch-protocol:make-web-search-adapter :backend backend))
         (hits (capability-protocol:web-search cap "ex")))
    (ok (= 1 (length hits)))
    (ok (equal "https://ex.test"
               (websearch-protocol:search-hit-url (first hits))))
    (ok (equal "Ex" (websearch-protocol:search-hit-title (first hits))))))

(deftest websearch-catalogue-world
  (let* ((backend (websearch-protocol:make-mock-websearch-backend
                   :hits (list (websearch-protocol:make-search-hit
                                :url "https://ex.test" :title "Ex"))))
         (cat (websearch-protocol:make-websearch-catalogue backend)))
    (ok (capability-protocol:catalogue-defines-p cat :web-search))
    (ok (capability-protocol:capability-supported-p cat :web-search))
    (ok (capability-protocol:catalogue-defines-p cat :compute))
    (ng (capability-protocol:capability-supported-p cat :compute))
    (let ((cap (capability-protocol:get-capability cat :web-search)))
      (ok (eq cap (capability-protocol:get-capability cat :web-search)))
      (ok (equal "https://ex.test"
                 (websearch-protocol:search-hit-url
                  (first (capability-protocol:invoke-operation
                          cap 'capability-protocol:web-search "ex"))))))))
