#!/usr/bin/env bash
set -euo pipefail

REMOTE_HOST="docker2"
REMOTE_DIR="$HOME/personal-site-delivery"

echo "🚀 Deploying Crafter CMS Delivery to ${REMOTE_HOST}..."

# 1. Ensure remote directories exist and are writable
ssh "${REMOTE_HOST}" "mkdir -p ${REMOTE_DIR}/crafter-data ${REMOTE_DIR}/search-data ${REMOTE_DIR}/search-logs && docker run --rm -v ${REMOTE_DIR}:/app alpine chown -R 1000:1000 /app/search-data /app/search-logs"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
scp -r "${SCRIPT_DIR}/../nginx" "${REMOTE_HOST}:${REMOTE_DIR}/"
scp "${SCRIPT_DIR}/../docker-compose.yml" "${REMOTE_HOST}:${REMOTE_DIR}/"

# 3. Spin up the containers
ssh "${REMOTE_HOST}" "cd ${REMOTE_DIR} && docker compose pull && docker compose up -d"

echo "✅ Containers are running!"
echo ""
echo "⚠️ Next Step on docker2:"
echo "You must SSH into docker2 and run the init-site.sh script inside the delivery container to hook it up to your GitHub repo:"
echo "docker exec -it -u crafter crafter-deployer /opt/crafter/bin/init-site.sh -b main -u jakefearsd -p <YOUR_PAT> personal-site https://github.com/jakefearsd/personal-site.git"
