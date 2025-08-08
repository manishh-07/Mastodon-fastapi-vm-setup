# PRODUCTION SETUP: Mastodon + FastAPI on Same VM

---

## 📁 PART 0: PREP FILES LOCALLY (ON YOUR LAPTOP)

On your **local machine**, prepare this folder:

```
/local-setup/
├── setup_mastodon.sh        # Mastodon installer
├── mastodon_secrets.env     # DB password (auto-generated inside script)
├── setup_fastapi.sh         # FastAPI installer
├── fastapi_env.env          # FastAPI .env file (initial version)
```

---

## 🔄 PART 1: COPY FILES TO VM

Use SCP to copy the files to your VM:

```bash
scp setup_mastodon.sh ubuntu@<VM_IP>:/home/ubuntu/
scp setup_fastapi.sh ubuntu@<VM_IP>:/home/ubuntu/

Or Do Like :

scp *.sh ubuntu@<VM_IP>:/home/ubuntu/


# just keep in mind before running .sh, needs to run :
# chmod +x <filename>.sh

```

---

## 💻 PART 2: INSTALL MASTODON

### 🔧 2.1 Run Mastodon Setup Script:

```bash
chmod +x setup_mastodon.sh
sudo ./setup_mastodon.sh
```

This will:

- Install Docker, Docker Compose, NGINX, Certbot, etc.
- Create `/opt/mastodon` structure
- Download Mastodon's `docker-compose.yml`
- Generate a secure DB password and save to `/opt/mastodon/.secrets.env`
- Setup initial Postgres DB with user `mastodon`

You will see this at the end:

```bash
⚠️ NEXT: Run the Mastodon setup wizard:
cd /opt/mastodon
docker-compose run --rm web bundle exec rake mastodon:setup
```

---

## 🧠 PART 3: MANUAL SETUP WIZARD (IMPORTANT!)

Run:

```bash
cd /opt/mastodon
docker-compose run --rm web bundle exec rake mastodon:setup
```

### Fill like this:

```text
Domain name: mastodon.yourdomain.com
Enable single user mode? Yes
DB host: db
DB name: mastodon
DB user: mastodon
DB password: (copy from /opt/mastodon/.secrets.env)
Redis host: redis
SMTP server: localhost
SMTP port: 587
SMTP login: (leave blank)
SMTP password: (leave blank)
SMTP sender: Mastodon <notifications@localhost>
```

### Then:

```bash
nano /opt/mastodon/.env.production
# Paste the wizard output here
```

**Reason:** The setup wizard outputs secrets — you must save them manually for containers to use.

---

## 👑 PART 4: CREATE ADMIN ACCOUNT

```bash
cd /opt/mastodon
docker-compose run --rm web tootctl accounts create admin --email admin@yourdomain.com --confirmed --role Owner
```

### Save it:

```bash
echo "admin@yourdomain.com, password: <set_password_here>" > /opt/mastodon/admin_creds.txt
chmod 600 /opt/mastodon/admin_creds.txt
```

### Start Mastodon:

```bash
cd /opt/mastodon
docker-compose up -d
```

---

## 🌍 PART 5: SETUP NGINX + CERTBOT FOR MASTODON

### Temporary config:

```bash
sudo mkdir -p /var/www/mastodon
echo "test" | sudo tee /var/www/mastodon/index.html
```

```bash
sudo nano /etc/nginx/conf.d/mastodon.conf
```

Paste:

```nginx
server {
  listen 80;
  server_name mastodon.yourdomain.com;
  root /var/www/mastodon;
}
```

```bash
sudo systemctl reload nginx
sudo apt install python3-venv -y
python3 -m venv /opt/certbot
/opt/certbot/bin/pip install --upgrade pip
/opt/certbot/bin/pip install certbot certbot-nginx
```

```bash
sudo /opt/certbot/bin/certbot --nginx -d mastodon.yourdomain.com
```

### Final config:

```bash
wget -O /etc/nginx/conf.d/mastodon.conf https://raw.githubusercontent.com/mastodon/mastodon/main/dist/nginx.conf
sudo nano /etc/nginx/conf.d/mastodon.conf
```

- Change `/home/mastodon/live/public` to `/opt/mastodon/public`
- Replace `example.com` with your domain
- Replace `=404` with `@proxy`

```bash
sudo systemctl reload nginx
```

---

## 🚀 PART 6: SETUP FASTAPI APP

### Run setup:

```bash
chmod +x setup_fastapi.sh
sudo ./setup_fastapi.sh
```

This will:

- Clone the FastAPI repo to `/opt/token-api`
- Create a Python virtual environment
- Install dependencies
- Create a blank `.env` file with placeholders
- Create a systemd service to run it on port 8000

> 🧠 The FastAPI app **auto-fills the client ID and secret** on first run and writes it back to `.env`.

---

## 🌐 PART 7: NGINX + CERTBOT FOR FASTAPI

### Reverse proxy:

```bash
sudo nano /etc/nginx/conf.d/token-api.conf
```

Paste:

```nginx
server {
  listen 80;
  server_name api.yourdomain.com;

  location / {
    proxy_pass http://127.0.0.1:8000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }
}
```

```bash
sudo systemctl reload nginx
sudo /opt/certbot/bin/certbot --nginx -d api.yourdomain.com
```

---

## 🧪 PART 8: VALIDATE

- Mastodon UI: [https://mastodon.yourdomain.com](https://mastodon.yourdomain.com)
- FastAPI Swagger: [https://api.yourdomain.com/docs](https://api.yourdomain.com/docs)

---

## 🛠️ MAINTENANCE

```bash
# Mastodon
cd /opt/mastodon
docker-compose restart
docker-compose logs -f web

# FastAPI
sudo systemctl restart token-api
sudo journalctl -u token-api -f
```

---

## 📜 SCRIPT: setup\_mastodon.sh

```bash
#!/bin/bash
# Purpose: Install Mastodon base setup on Ubuntu 24.04 VM

set -e

echo "🔧 Installing required packages..."
sudo apt update && sudo apt install -y docker.io docker-compose nginx python3-venv git curl openssl
sudo systemctl enable docker
sudo systemctl start docker

echo "📁 Creating Mastodon directory structure..."
sudo mkdir -p /opt/mastodon/{postgres14,redis,public/system}
sudo chown -R 991:991 /opt/mastodon/public
cd /opt/mastodon

echo "⬇️ Downloading docker-compose.yml..."
wget https://raw.githubusercontent.com/mastodon/mastodon/main/docker-compose.yml

echo "⚙️ Patching docker-compose.yml..."
sed -i '/build:/s/^/#/' docker-compose.yml
sed -i 's/image: tootsuite\\/mastodon/image: tootsuite\\/mastodon:v4.4.1/' docker-compose.yml

echo "🔐 Generating DB password and saving..."
DB_PASS=$(openssl rand -hex 12)
echo "DB_PASS=$DB_PASS" > /opt/mastodon/.secrets.env

echo "🐘 Setting up PostgreSQL..."
docker run --rm --name postgres \
  -v $PWD/postgres14:/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD="$DB_PASS" -d postgres:14-alpine

sleep 10

docker exec -it postgres psql -U postgres -c "CREATE USER mastodon WITH PASSWORD '$DB_PASS' CREATEDB;"
docker stop postgres

echo "✅ Base setup complete!"
echo "⚠️ NEXT: Run the Mastodon setup wizard:"
echo ""
echo "cd /opt/mastodon"
echo "docker-compose run --rm web bundle exec rake mastodon:setup"
echo ""
echo "📌 Then save the output to: /opt/mastodon/.env.production"
```

---

## 📜 SCRIPT: setup\_fastapi.sh

```bash
#!/bin/bash
# Purpose: Set up FastAPI OAuth app for Mastodon

set -e

echo "📦 Setting up FastAPI project in /opt/token-api..."
cd /opt
git clone https://github.com/manishh-07/mastodon_access_token_api.git token-api
cd token-api

echo "🐍 Creating venv and installing deps..."
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

echo "🔐 Saving FastAPI secrets to .env..."
cat <<EOF > /opt/token-api/.env
MASTODON_INSTANCE=https://mastodon.yourdomain.com
CLIENT_NAME=FastAPIApp
SCOPES=read write follow
MASTODON_DOCKER=mastodon_web_1
MASTODON_CLIENT_ID=
MASTODON_CLIENT_SECRET=
EOF

echo "⚠️ NOTE: CLIENT_ID and SECRET will be auto-filled on first API call!"

echo "🛠️ Creating systemd service..."
cat <<EOF | sudo tee /etc/systemd/system/token-api.service
[Unit]
Description=FastAPI OAuth App
After=network.target

[Service]
WorkingDirectory=/opt/token-api
ExecStart=/opt/token-api/venv/bin/gunicorn app.main:app -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl enable token-api
sudo systemctl start token-api

echo "✅ FastAPI app running on port 8000"
```

---
