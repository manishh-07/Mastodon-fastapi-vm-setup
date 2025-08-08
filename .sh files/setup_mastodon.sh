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

