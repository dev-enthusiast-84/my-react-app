# Stage 1: Build the app
FROM node:20-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

# Stage 2: Serve the app with a slim Nginx image
FROM nginx:alpine-slim

# Port Nginx listens on; override at runtime with -e NGINX_PORT=...
ENV NGINX_PORT=80

RUN rm -f /etc/nginx/conf.d/default.conf

COPY --from=builder /app/build /usr/share/nginx/html
# The image's entrypoint renders templates into /etc/nginx/conf.d/ via envsubst
COPY nginx.conf /etc/nginx/templates/default.conf.template

EXPOSE ${NGINX_PORT}

# busybox wget ships with the base image, so no extra packages are needed
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null "http://127.0.0.1:${NGINX_PORT}/healthz" || exit 1

CMD ["nginx", "-g", "daemon off;"]
