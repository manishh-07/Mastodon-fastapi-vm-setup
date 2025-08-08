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

