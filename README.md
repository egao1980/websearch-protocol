# websearch-protocol

Lispy **CLOS** web search for [cl-stack](https://github.com/egao1980/cl-stack). Generic functions over a backend; default colocated backend talks to a [SearXNG](https://docs.searxng.org/) JSON API (self-hostable, no API key).

| System | Role | Repo |
|--------|------|------|
| `websearch-protocol` (`stack-websearch`) | Protocol + SearXNG backend + mock | this repo |
| `websearch-protocol/capability` | `:world` `web-search` adapter | this repo |

`http-protocol`, `json-protocol`, and `html-protocol` are **soft-used** (no hard `:depends-on`). SearXNG methods require an HTTP client/backend bound (`*http-backend*` / `*http-client*`) and `*json-backend*` for decode. `fetch-page` prefers `doc-extract-protocol` when that package exists, then `html-protocol:parse` + `element-text` if `*html-backend*` is bound, else a naive tag stripper.

```lisp
(asdf:load-system "websearch-protocol")

(let ((b (stack-websearch:make-mock-websearch-backend
          :hits (list (stack-websearch:make-search-hit
                       :url "https://example.test"
                       :title "Example"
                       :snippet "A hit"
                       :rank 1
                       :source "mock")))))
  (stack-websearch:search-web b "example"))

;; Live SearXNG (needs http-protocol + json-protocol backends bound):
(stack-websearch:search-web
 (stack-websearch:make-searxng-backend :base-url "http://localhost:8080")
 "common lisp" :count 5 :freshness :month :site "lisp.org")
```

| Role | GF | In-tree |
|------|----|---------|
| search | `search-web` → list of `search-hit` | `searxng-backend`, `mock-websearch-backend` |
| fetch | `fetch-page` → extracted text | same |
| capability | `web-search` on `web-search-adapter` | `websearch-protocol/capability` |

`search-hit` slots: `url`, `title`, `snippet`, `rank`, `source`.

HTTP 401/403/451 → `websearch-denied`. Other non-2xx → `websearch-http-error` (`:status`). Operations establish `use-value` and `retry`.

`:world` catalogue already defines `:web-search`. Load the capability subsystem and register an adapter:

```lisp
(asdf:load-system "websearch-protocol/capability")
(let* ((b (stack-websearch:make-mock-websearch-backend
           :hits (list (stack-websearch:make-search-hit :url "https://ex.test"))))
       (cat (stack-websearch:make-websearch-catalogue b)))
  (capability-protocol:web-search
   (capability-protocol:get-capability cat :web-search)
   "ex"))
```

## License

MIT — see [LICENSE](LICENSE).
