#!/bin/bash
set -e

# Navigate to the script's directory and figure out paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
DEPLOY_DIR="$SCRIPT_DIR/.."
CRAFTER_SRC_DIR="$DEPLOY_DIR/../craftercms"
REMOTE_HOST="docker2"

echo "========================================="
echo "Building CrafterCMS Docker images..."
echo "========================================="
cd "$CRAFTER_SRC_DIR"
# Clean and build everything
./gradlew clean build buildDeployer buildDeliveryTomcat buildAuthoringTomcat -PdockerTag=latest

echo "========================================="
echo "Transferring custom Docker images to ${REMOTE_HOST}..."
echo "========================================="
# Save the images locally, stream them over SSH, and load them into docker2's daemon
docker save craftercms/deployer:latest craftercms/delivery_tomcat:latest craftercms/authoring_tomcat:latest | ssh "${REMOTE_HOST}" "docker load"
ssh "${REMOTE_HOST}" "docker tag craftercms/authoring_tomcat:latest craftercms/authoring_tomcat:5.0.0-SNAPSHOT"
ssh "${REMOTE_HOST}" "docker tag craftercms/deployer:latest craftercms/deployer:5.0.0-SNAPSHOT"

echo "========================================="
echo "Deploying Configuration to ${REMOTE_HOST}..."
echo "========================================="
cd "$DEPLOY_DIR"
ssh "${REMOTE_HOST}" "mkdir -p ~/personal-site-delivery/search-data ~/personal-site-delivery/search-logs"
scp -r "${DEPLOY_DIR}/nginx" "${REMOTE_HOST}:~/personal-site-delivery/"
scp "${DEPLOY_DIR}/docker-compose.yml" "${REMOTE_HOST}:~/personal-site-delivery/"

echo "========================================="
echo "Restarting Infrastructure on ${REMOTE_HOST} (Rolling Update)..."
echo "========================================="
# Bring up everything EXCEPT delivery, which we update carefully
ssh "${REMOTE_HOST}" "cd ~/personal-site-delivery && docker compose up -d search search-init authoring-search authoring-search-init crafter-deployer authoring-deployer authoring-tomcat proxy"

# Rolling update for delivery to prevent 502 Bad Gateway
# Start green first
echo "Starting green delivery container..."
ssh "${REMOTE_HOST}" "cd ~/personal-site-delivery && docker compose up -d --force-recreate crafter-delivery-green"
echo "Waiting for green container to become healthy..."
ssh "${REMOTE_HOST}" "while ! docker inspect --format \"{{json .State.Health.Status }}\" crafter-delivery-green | grep -q '\"healthy\"'; do sleep 2; done"

# Start blue next
echo "Starting blue delivery container..."
ssh "${REMOTE_HOST}" "cd ~/personal-site-delivery && docker compose up -d --force-recreate crafter-delivery"
echo "Waiting for blue container to become healthy..."
ssh "${REMOTE_HOST}" "while ! docker inspect --format \"{{json .State.Health.Status }}\" crafter-delivery | grep -q '\"healthy\"'; do sleep 2; done"

# Reload nginx just in case
ssh "${REMOTE_HOST}" "docker exec crafter-proxy nginx -s reload"

echo "========================================="
echo "Validating Production URLs..."
echo "========================================="
sleep 5 # give nginx a moment

for url in "https://jakefear.com" "https://maiiavorobiova.com"; do
    echo "Testing $url ..."
    if ! curl -s -f -o /dev/null "$url"; then
        echo "ERROR: Validation failed for $url! Site is not loading properly."
        echo "Check the Nginx proxy logs and backend health immediately."
        exit 1
    else
        echo "SUCCESS: $url is online and returning 200 OK."
    fi
done

echo "========================================="
echo "Redeployment successfully validated!"
echo "========================================="
