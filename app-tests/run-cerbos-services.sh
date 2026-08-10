#!/bin/bash
set -e

# Make paths below independent of the caller's cwd.
cd "$(dirname "$0")"

echo "Building client-cerbos image..."
docker compose -f docker-compose-app-tests-cerbos.yml build

echo "Starting Cerbos and OPAL services..."
docker compose -f docker-compose-app-tests-cerbos.yml up -d

echo "Waiting for opal-client to finish syncing policy..."
ready=false
for _ in $(seq 1 30); do
  if curl -sf http://localhost:7766/ready > /dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 2
done

if [ "${ready}" != "true" ]; then
  echo "opal-client did not become ready" >&2
  docker compose -f docker-compose-app-tests-cerbos.yml logs
  exit 1
fi

# /ready only confirms OPAL successfully PUT the policy to Cerbos's admin API -
# Cerbos's own storage layer (sqlite3 driver, file-watch reload) can briefly lag
# behind that write before the policy is actually queryable/enforceable. Poll
# Cerbos's own admin API directly so we don't start the tests during that gap.
echo "Waiting for Cerbos to index the synced policy..."
for _ in $(seq 1 30); do
  if curl -sf -u cerbos:cerbosAdmin http://localhost:3592/admin/policies \
      | python3 -c "import json, sys; sys.exit(0 if json.load(sys.stdin).get('policyIds') else 1)" 2>/dev/null; then
    echo "Services ready"
    exit 0
  fi
  sleep 1
done

echo "Cerbos did not index the synced policy" >&2
docker compose -f docker-compose-app-tests-cerbos.yml logs
exit 1
