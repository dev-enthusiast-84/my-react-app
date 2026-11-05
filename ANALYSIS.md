# Image Size Analysis: Single-Stage vs Multi-Stage

## Image Size Comparison

| Image | Base image(s) | Size | Compressed |
|---|---|---|---|
| react-app:single | node:20 | 2.17 GB (2170 MB) | 505 MB |
| react-app:multistage | node:18-alpine → nginx:alpine | 95.1 MB | 26.6 MB |
| **Saved** | | **2074.9 MB** | **478.4 MB** |
| **Reduction** | | **≈ 95.6%** | **≈ 94.7%** |

## Calculation

**Formula:**

```
Reduction (%) = (Single size − Multi-stage size) ÷ Single size × 100
```

### 1. Uncompressed size

Convert GB to MB (Docker uses decimal units, so 1 GB = 1000 MB):

```
2.17 GB × 1000 = 2170 MB

Saved     = 2170 − 95.1        = 2074.9 MB
Reduction = 2074.9 ÷ 2170      = 0.9562
          = 0.9562 × 100       ≈ 95.6%
```

### 2. Compressed size

```
Saved     = 505 − 26.6         = 478.4 MB
Reduction = 478.4 ÷ 505        = 0.9473
          = 0.9473 × 100       ≈ 94.7%
```

### 3. How many times smaller

```
Uncompressed: 2170 ÷ 95.1  ≈ 22.8× smaller
Compressed:   505 ÷ 26.6   ≈ 19.0× smaller
```

**Conclusion:** The multi-stage image is about **95.6% smaller** (about **22.8 times smaller**). Each registry push or pull moves about **26.6 MB** instead of **505 MB**.

## Analysis

The single-stage image (`react-app:single`, built on `node:20`) is 2.17 GB (505 MB compressed). The multi-stage image (`react-app:multistage`, built with `node:18-alpine` and served by `nginx:alpine`) is 95.1 MB (26.6 MB compressed). That is about a 95.6% reduction in size (94.7% compressed).

### Security

The smaller runtime image is more secure because it contains only Nginx and the static `build/` output. Node.js, npm, `node_modules`, source code and build tools are left out, so there are fewer packages that could have known CVEs (security vulnerabilities). This shrinks the attack surface: an attacker has fewer binaries, shells and libraries to exploit, and no dev dependencies or source files can leak at runtime.

### Deployment speed

The smaller size also speeds up deployment. Registry pushes and pulls move about 27 MB instead of about 505 MB, so new nodes start faster, scaling and rollbacks are quicker, and storage and bandwidth costs go down.

### Build caching

For build caching, `package*.json` is copied and `npm ci` is run before `COPY . .`. The dependency layer is then reused from cache unless the package files change, so source-only edits rebuild in seconds. A `.dockerignore` file that excludes `node_modules`, `build` and `.git` also keeps the build context small.

---

# Runtime Image Optimisations: v1 → v2 → v3

The optional improvements are now in the current `Dockerfile` and `nginx.conf`. They add an Nginx health check, cache headers, a port set through an environment variable, and a lighter runtime image. This section compares the result with the earlier versions.

## Which file is which

| Version | Dockerfile | Nginx config | Image tag | Status |
|---|---|---|---|---|
| v1 | `Dockerfile.multistage.v1` | *(Nginx default)* | `react-app:multistage` | Original two-stage build (backup) |
| v2 | `Dockerfile.multistage.v2` | `nginx.conf.v2` | `react-app:multistage-v2` | Previous committed version (backup) |
| v3 | `Dockerfile` | `nginx.conf` | `react-app:multistage-v3` | **Current / latest** |

## Image size comparison

| Image | Runtime base | Size | Compressed |
|---|---|---|---|
| react-app:single | node:20 | 2170 MB | 505 MB |
| react-app:multistage (v1) | nginx:alpine | 95.1 MB | 26.6 MB |
| react-app:multistage-v2 | nginx:alpine + curl | 95.3 MB | 26.7 MB |
| **react-app:multistage-v3** | **nginx:alpine-slim** | **22.2 MB** | **6.1 MB** |

### Calculation (v2 → v3)

```
Uncompressed: Saved = 95.3 − 22.2 = 73.1 MB   Reduction = 73.1 ÷ 95.3 ≈ 76.7%
Compressed:   Saved = 26.7 − 6.1  = 20.6 MB   Reduction = 20.6 ÷ 26.7 ≈ 77.2%
```

### Calculation (single-stage → v3)

```
Uncompressed: (2170 − 22.2) ÷ 2170 ≈ 99.0%   2170 ÷ 22.2 ≈ 97.7× smaller
Compressed:   (505 − 6.1)  ÷ 505  ≈ 98.8%   505  ÷ 6.1  ≈ 82.8× smaller
```

## Feature comparison

| Feature | v1 | v2 | v3 (current) |
|---|---|---|---|
| Runtime base | `nginx:alpine` | `nginx:alpine` | `nginx:alpine-slim` |
| Health check | none | `curl -f http://localhost/` (installs curl, fetches the full page) | busybox `wget` against a dedicated `/healthz` (no extra packages, no access log noise), with `start-period` and `retries` set |
| Port | fixed 80 | fixed 80 | `NGINX_PORT` env var (default 80), filled in by the image's envsubst template step |
| SPA routing | none (deep links 404) | `try_files $uri /index.html` | same |
| `index.html` caching | default | default | `no-cache`, so new deploys are picked up at once |
| Hashed assets (`/static/`) | default | `.js/.css/.png/.jpg/.svg` → 30d `immutable` | `/static/` → 1 year `immutable` |
| Unhashed files (favicon, manifest, logos) | default | 30d `immutable` (stale after a deploy) | 1 day |
| gzip | off | off | on (level 6, files ≥ 1 KB) |

## Verification (run on v3)

```sh
docker run -d --name t3 -e NGINX_PORT=8080 -p 8089:8080 react-app:multistage-v3
docker inspect -f '{{.State.Health.Status}}' t3     # healthy
curl -s  localhost:8089/healthz                       # ok
curl -sI localhost:8089/                              # Cache-Control: no-cache
curl -sI -H 'Accept-Encoding: gzip' localhost:8089/static/js/main.<hash>.js
                                                      # Cache-Control: public, max-age=31536000, immutable
                                                      # Content-Encoding: gzip
curl -sI localhost:8089/favicon.ico                   # Cache-Control: public, max-age=86400
curl -sI localhost:8089/some/route                    # 200 (SPA fallback), no-cache
```

Results: the container reported `healthy` on port 8080 as well as on the default port 80, and every response had the expected `Cache-Control` header.

## Analysis

- **Size:** `nginx:alpine-slim` leaves out the extra Nginx modules and tooling, and v3 no longer installs `curl`. The image drops from 95.3 MB to 22.2 MB (about 77%), and a pull moves about 6 MB.
- **Security:** fewer packages means fewer possible CVEs. v2 added `curl` only for the health check, while v3 uses the busybox `wget` that ships with the base image.
- **Health check:** `/healthz` returns a fixed response straight from Nginx. It does not read the disk or write to the access log, so frequent probes cost almost nothing.
- **Caching:** v2 marked every `.js/.css/.png` file as `immutable`, which is only safe for files with a content hash in the name. v3 caches only the hashed `/static/` output long-term, keeps `index.html` at `no-cache`, and caches other files for one day. Users get new deploys at once and still cache assets aggressively.
- **Port:** the same image can run on any port (`-e NGINX_PORT=...`) without a rebuild, for example behind a platform that assigns ports.
