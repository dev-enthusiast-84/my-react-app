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
