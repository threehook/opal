#!/bin/bash
set -e

# Make paths below independent of the caller's cwd (CI invokes this as
# ./app-tests/run-openfga-services.sh from the repo root).
cd "$(dirname "$0")"

# docker-compose-app-tests-openfga.yml references permitio/opal-client-openfga:latest
# (not published anywhere) and permitio/opal-server:latest (published, but without this
# branch's changes) - both need to be built from this checkout, or the server silently
# runs upstream's code instead of the one being tested here.
echo "Building client-openfga image..."
docker build -t permitio/opal-client-openfga:latest --target client-openfga -f ../docker/Dockerfile ..

echo "Building server image..."
docker build -t permitio/opal-server:latest --target server -f ../docker/Dockerfile ..

# Start the services in detached mode
echo "Starting OpenFGA and OPAL services..."
docker compose -f docker-compose-app-tests-openfga.yml up -d

# Wait for opal-client to report that it has actually synced policy and data
# into OpenFGA (a fixed sleep isn't reliable here: opal_server has to clone
# the policy repo and opal_client has to wait for opal_server, start OpenFGA,
# create a store, then sync - which can easily take longer than a short sleep).
echo "Waiting for opal-client to finish syncing policy and data..."
for _ in $(seq 1 60); do
  if curl -sf http://localhost:7766/ready > /dev/null 2>&1; then
    echo "Services ready"
    exit 0
  fi
  sleep 2
done

echo "opal-client did not become ready in time" >&2
docker compose -f docker-compose-app-tests-openfga.yml logs
exit 1
