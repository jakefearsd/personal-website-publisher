#!/bin/bash
set -e

echo "Updating existing OpenSearch indices to use 0 replicas..."
# The search container is exposed at port 9200 within the docker network, but in docker-compose.yml
# it is NOT exposed to the host.
# We must run curl from within a container on the same network, e.g., crafter-deployer.
docker exec crafter-deployer curl -s -X PUT "http://search:9200/_settings" \
     -H 'Content-Type: application/json' \
     -d '{ "index": { "number_of_replicas": 0 } }'

echo
echo "Done!"
