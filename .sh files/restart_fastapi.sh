#!/bin/bash
echo "🔁 Restarting FastAPI service..."
sudo systemctl restart token-api
sudo journalctl -u token-api -f
