#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

NGINX_CONF="$REPO_ROOT/docker/nginx/nginx.conf"
CONF_BACKUP="$REPO_ROOT/docker/nginx/nginx.conf.bak"
CERT_DIR="$REPO_ROOT/docker/nginx/certs"

cleanup() {
  docker compose down --remove-orphans >/dev/null 2>&1 || true

  if [[ -f "$CONF_BACKUP" ]]; then
    mv "$CONF_BACKUP" "$NGINX_CONF"
  fi

  rm -f "$CERT_DIR"/fullchain.pem "$CERT_DIR"/privkey.pem
}
trap cleanup EXIT INT TERM

echo "==> Validating compose configuration"
COMPOSE_CONFIG="$(docker compose config)"
if echo "$COMPOSE_CONFIG" | grep -A 10 "services:" | grep -A 5 "web:" | grep -q "volumes:"; then
  echo "FAIL: Compose web service must not define any volumes"
  exit 1
fi

if ! echo "$COMPOSE_CONFIG" | grep -q 'published: "80"'; then
  if ! echo "$COMPOSE_CONFIG" | grep -q 'published: 80'; then
    echo "FAIL: Port 80 is not published"
    exit 1
  fi
fi

if ! echo "$COMPOSE_CONFIG" | grep -q 'published: "443"'; then
  if ! echo "$COMPOSE_CONFIG" | grep -q 'published: 443'; then
    echo "FAIL: Port 443 is not published"
    exit 1
  fi
fi

echo "==> Building and starting container"
docker compose up -d --build

echo "==> Verifying nginx configuration syntax in container"
docker compose exec -T web nginx -t

echo "==> Testing HTTP root endpoint"
INDEX_RESPONSE="$(curl -fsS --retry 5 --retry-connrefused --retry-delay 1 http://localhost/)"
if ! echo "$INDEX_RESPONSE" | grep -q "docker-compose-html"; then
  echo "FAIL: Expected index marker 'docker-compose-html' not found"
  exit 1
fi

echo "==> Testing website multi-page endpoints and content markers"
USAGE_RESPONSE="$(curl -fsS http://localhost/usage.html)"
if ! echo "$USAGE_RESPONSE" | grep -q 'id="quick-start"'; then
  echo "FAIL: Expected id=\"quick-start\" marker not found in usage.html"
  exit 1
fi

DEPLOY_RESPONSE="$(curl -fsS http://localhost/deploy.html)"
if ! echo "$DEPLOY_RESPONSE" | grep -q 'id="renewal"'; then
  echo "FAIL: Expected id=\"renewal\" marker not found in deploy.html"
  exit 1
fi

echo "==> Testing asset serving and MIME types"
CSS_HEADERS="$(curl -sI http://localhost/assets/css/styles.css)"
if ! echo "$CSS_HEADERS" | grep -i "^content-type:" | grep -qi "text/css"; then
  echo "FAIL: Expected text/css content-type for styles.css"
  exit 1
fi

if ! echo "$CSS_HEADERS" | grep -i "^cache-control:" | grep -qi "max-age"; then
  echo "FAIL: Expected Cache-Control header for static assets"
  exit 1
fi

JS_HEADERS="$(curl -sI http://localhost/assets/js/main.js)"
if ! echo "$JS_HEADERS" | grep -i "^content-type:" | grep -Eqi "(application|text)/javascript"; then
  echo "FAIL: Expected javascript content-type for main.js"
  exit 1
fi

echo "==> Testing Content-Security-Policy header"
INDEX_HEADERS="$(curl -sI http://localhost/)"
if ! echo "$INDEX_HEADERS" | grep -i "^content-security-policy:" | grep -qi "default-src 'self'"; then
  echo "FAIL: Expected Content-Security-Policy header not found"
  exit 1
fi

echo "==> Testing 404 handling"
HTTP_STATUS="$(curl -s -o /dev/null -w "%{http_code}" http://localhost/non-existent-page-test-404 || true)"
if [[ "$HTTP_STATUS" != "404" ]]; then
  echo "FAIL: Expected 404 status for missing file, got $HTTP_STATUS"
  exit 1
fi

NOT_FOUND_BODY="$(curl -s http://localhost/non-existent-page-test-404 || true)"
if ! echo "$NOT_FOUND_BODY" | grep -qi "404"; then
  echo "FAIL: Custom 404 content not served"
  exit 1
fi

if [[ "${SMOKE_SSL:-0}" == "1" ]]; then
  echo "==> Testing optional SSL mode"
  mkdir -p "$CERT_DIR"
  openssl req -x509 -nodes -days 1 -newkey rsa:2048 \
    -keyout "$CERT_DIR/privkey.pem" \
    -out "$CERT_DIR/fullchain.pem" \
    -subj "/CN=localhost" >/dev/null 2>&1

  cp "$NGINX_CONF" "$CONF_BACKUP"

  sed -i.tmp \
    -e '/# BEGIN SSL_REDIRECT/,/# END SSL_REDIRECT/ { /# /!d; /# [A-Z]/!s/^    # //; }' \
    -e '/# BEGIN SSL_SERVER/,/# END SSL_SERVER/ { /# /!d; /# [A-Z]/!s/^    # //; }' \
    -e '/# BEGIN HTTP_STANDALONE/,/# END HTTP_STANDALONE/ { /# [A-Z]/!s/^    /    # /; }' \
    "$NGINX_CONF"
  rm -f "${NGINX_CONF}.tmp"

  docker compose down
  docker compose up -d --build --force-recreate

  docker compose exec -T web nginx -t

  SSL_RESPONSE="$(curl -kfsS --retry 5 --retry-connrefused --retry-delay 1 https://localhost/)"
  if ! echo "$SSL_RESPONSE" | grep -q "docker-compose-html"; then
    echo "FAIL: HTTPS response did not contain index marker"
    exit 1
  fi

  REDIRECT_STATUS="$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ || true)"
  if [[ "$REDIRECT_STATUS" != "301" ]]; then
    echo "FAIL: Expected 301 redirect to HTTPS, got $REDIRECT_STATUS"
    exit 1
  fi
fi

echo "PASS: All smoke tests passed"
