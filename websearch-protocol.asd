(defsystem "websearch-protocol"
  :version "0.1.1"
  :description "CLOS web search protocol for cl-stack (SearXNG JSON + fetch-page)"
  :author "egao1980"
  :license "MIT"
  :depends-on ()
  :properties (:cl-repo
               (:ci (:with ("websearch-protocol/capability"))))
  :serial t
  :pathname "src"
  :components ((:file "package")
               (:file "conditions")
               (:file "protocol")
               (:file "searxng")
               (:file "mock"))
  :in-order-to ((test-op (test-op "websearch-protocol/tests"))))

(defsystem "websearch-protocol/capability"
  :version "0.1.1"
  :description "capability-protocol :web-search adapter over websearch-protocol"
  :author "egao1980"
  :license "MIT"
  :depends-on ("websearch-protocol" "capability-protocol")
  :serial t
  :pathname "src/capability"
  :components ((:file "adapter"))
  :in-order-to ((test-op (test-op "websearch-protocol/tests"))))

(defsystem "websearch-protocol/tests"
  :depends-on ("websearch-protocol" "websearch-protocol/capability" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "protocol-test")
               (:file "restarts-test")
               (:file "capability-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
