#!/bin/bash
echo "🔁 Restarting Mastodon containers..."
cd /opt/mastodon
docker-compose restart
docker-compose logs -f web

