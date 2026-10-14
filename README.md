# docker-compose-html

Production-ready Nginx static HTML server orchestrated with Docker Compose. Serves content from `www/` on ports 80 (HTTP) and 443 (HTTPS), with optional SSL, security headers, and an immutable image design.

## Features

- **Single command deployment**: Spin up a fully configured Nginx web server with Docker Compose.
- **Immutable image architecture**: Static assets and configuration are baked directly into the Docker image. No bind mounts or host volume dependencies.
- **Optional SSL/TLS**: Seamless toggle between HTTP-only and HTTPS with TLS 1.2/1.3, HTTP/2, session caching, and opt-in HSTS.
- **Hardened defaults**: Version disclosure disabled (`server_tokens off`), security headers (`nosniff`, `SAMEORIGIN`, `strict-origin-when-cross-origin`), and custom 404 error handling.
- **Automated test suite**: Includes bash smoke tests and GitHub Actions CI for both HTTP and SSL modes.

---

## Prerequisites

- [Docker Engine](https://docs.docker.com/engine/install/) (v20.10+)
- [Docker Compose](https://docs.docker.com/compose/) v2 plugin (`docker compose`)

Verify your installation:

```bash
docker compose version
```

---

## Quick Start

1. **Clone the repository:**

   ```bash
   git clone git@github.com:hydrokat/docker-compose-html.git
   cd docker-compose-html
   ```

2. **Start the web service:**

   ```bash
   docker compose up -d --build
   ```

3. **Open in browser:**

   Visit [http://localhost](http://localhost). You should see the static index page.

4. **Verify container health and Nginx syntax:**

   ```bash
   docker compose exec web nginx -t
   ```

---

## Stopping and Cleaning Up

- **Stop containers:**

  ```bash
  docker compose down
  ```

- **Stop containers and remove built images:**

  ```bash
  docker compose down --rmi local
  ```

---

## Updating Website Content

Because this project uses an **immutable image design without volumes**, static files are copied into the container filesystem at build time (`COPY www/ /usr/share/nginx/html/`).

When you edit or add HTML, CSS, JavaScript, or images in `www/`:

1. Update the files in `www/`.
2. Rebuild and restart the container:

   ```bash
   docker compose up -d --build
   ```

> **Why no volumes?**
> Baking files into the image guarantees atomic deployments, environment parity, portability across servers, and avoids permission issues between host and container.

---

## Enabling SSL / HTTPS

By default, the server runs in HTTP-only mode. SSL is optional and configured through `docker/nginx/nginx.conf`.

### 1. Obtain or Generate SSL Certificates

The Nginx configuration expects two certificate files in `docker/nginx/certs/`:
- `fullchain.pem` (certificate + intermediate CA chain)
- `privkey.pem` (private key)

#### Option A: Local Self-Signed Certificate (for testing)

Generate a self-signed certificate valid for 1 year:

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout docker/nginx/certs/privkey.pem \
  -out docker/nginx/certs/fullchain.pem \
  -subj "/CN=localhost"
```

#### Option B: Let's Encrypt Certificate (for production VPS)

On your host server, obtain certificates using Certbot standalone mode (ensure port 80 is temporarily free):

```bash
sudo certbot certonly --standalone -d example.com -d www.example.com
```

Copy the issued certificates into your project build directory:

```bash
sudo cp /etc/letsencrypt/live/example.com/fullchain.pem docker/nginx/certs/
sudo cp /etc/letsencrypt/live/example.com/privkey.pem docker/nginx/certs/
sudo chown $(id -u):$(id -g) docker/nginx/certs/*.pem
chmod 600 docker/nginx/certs/privkey.pem
```

> ⚠️ **SECURITY WARNING:**
> Certificates and private keys in `docker/nginx/certs/` are copied into the Docker image at build time.
> - Never commit certificates or private keys to git (`.gitignore` excludes `docker/nginx/certs/*` except `.gitkeep`).
> - Never push the built Docker image containing private keys to public registries like Docker Hub or GitHub Container Registry.

### 2. Configure `docker/nginx/nginx.conf`

Open `docker/nginx/nginx.conf`:

1. **Comment out** the `BEGIN HTTP_STANDALONE` block (lines around 36–54).
2. **Uncomment** the `BEGIN SSL_REDIRECT` block (redirects port 80 to 443).
3. **Uncomment** the `BEGIN SSL_SERVER` block (listens on 443 with SSL).
4. Update `server_name` with your actual domain name if applicable.
5. (Optional) Uncomment the HSTS header line (`Strict-Transport-Security`) once SSL is verified.

### 3. Rebuild and Start

```bash
docker compose up -d --build
```

Test HTTPS access:

```bash
curl -kfsS https://localhost/
```

### Disabling SSL

To revert back to HTTP-only mode:

1. In `docker/nginx/nginx.conf`, re-comment the `SSL_REDIRECT` and `SSL_SERVER` blocks.
2. Uncomment the `HTTP_STANDALONE` server block.
3. Remove certificates from `docker/nginx/certs/` if desired.
4. Rebuild: `docker compose up -d --build`.

---

## Port Configuration & Troubleshooting

`docker-compose.yaml` maps ports 80 and 443 on the host to ports 80 and 443 in the container:

```yaml
ports:
  - "80:80"
  - "443:443"
```

### Port Conflicts

If port 80 or 443 is already bound by another process (Apache, Nginx, or another Docker container):

1. **Find what is using the port:**

   ```bash
   lsof -i :80
   lsof -i :443
   docker ps
   ```

2. **Remap host ports in `docker-compose.yaml`:**

   ```yaml
   ports:
     - "8080:80"
     - "8443:443"
   ```

   Then access the site at `http://localhost:8080`.

---

## Project Structure

```text
docker-compose-html/
├── .dockerignore              # Excludes git, CI, and test files from Docker context
├── .gitignore                 # Ignores OS files, cert keys, and environments
├── .github/
│   └── workflows/
│       └── smoke.yml          # GitHub Actions CI for HTTP and SSL validation
├── docker-compose.yaml        # Service definition (web service, ports 80 & 443)
├── README.md                  # Comprehensive documentation
├── docker/
│   └── nginx/
│       ├── Dockerfile         # Pinned nginx:1.27-alpine base image
│       ├── nginx.conf         # Nginx configuration with optional SSL blocks
│       └── certs/
│           └── .gitkeep       # Target directory for fullchain.pem & privkey.pem
├── tests/
│   └── smoke.sh               # Automated test suite (HTTP, 404, optional SSL)
└── www/
    ├── index.html             # Static HTML root page
    └── 404.html               # Custom 404 error page
```

---

## Testing

Run the automated smoke test suite locally:

- **Test HTTP mode:**

  ```bash
  ./tests/smoke.sh
  ```

- **Test SSL mode (generates temporary certificate, tests HTTPS, and cleans up):**

  ```bash
  SMOKE_SSL=1 ./tests/smoke.sh
  ```

---

## Troubleshooting

- **Check container status:**

  ```bash
  docker compose ps
  ```

- **View live Nginx logs:**

  ```bash
  docker compose logs -f web
  ```

- **Test Nginx configuration syntax inside container:**

  ```bash
  docker compose exec web nginx -t
  ```

- **Missing certificates error when enabling SSL:**
  If you uncomment the SSL blocks without placing `fullchain.pem` and `privkey.pem` in `docker/nginx/certs/`, Nginx will fail to start. Ensure certificate filenames match exactly.

---

## License

MIT License. See [LICENSE](LICENSE) for details.
