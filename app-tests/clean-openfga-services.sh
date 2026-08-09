#!/bin/bash

# Make paths below independent of the caller's cwd (CI invokes this as
# ./app-tests/clean-openfga-services.sh from the repo root).
cd "$(dirname "$0")"

# Stop and remove containers, networks, volumes
echo "Cleaning up services..."
docker compose -f docker-compose-app-tests-openfga.yml down -v

echo "Cleanup complete"
