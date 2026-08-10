#!/bin/sh
# Waits until opal-server's policy bundle actually contains basicResource.yaml.
#
# opal-server's git clone and initial bundle build happen asynchronously in
# the background after startup, and the client's wait-for.sh only checks that
# opal-server's TCP port is open - which is true before that clone finishes.
# Waiting for the bundle contents rather than the port keeps the client from
# syncing against a server that cannot serve policy yet.
#
# A file that never appears is a configuration problem, not a slow clone: the
# bundle is built through two independent filters, OPAL_FILTER_FILE_EXTENSIONS
# (which repo files are read at all) and OPAL_POLICY_REPO_POLICY_EXTENSIONS
# (which of those count as policy modules), and Cerbos yaml needs both to allow
# it. The bundle is printed on each attempt to make that case diagnosable.
set -e

SERVER_URL="${1:-http://opal_server:7002}"
RESPONSE_FILE="/tmp/policy-bundle-check.json"

echo "Waiting for opal-server to have a complete policy bundle..."
for i in $(seq 1 40); do
  if ! wget -q -O "${RESPONSE_FILE}" "${SERVER_URL}/policy?path=."; then
    echo "  attempt ${i}: wget failed to reach ${SERVER_URL}/policy?path=."
    sleep 1
    continue
  fi
  if python3 -c "
import json, sys
with open('${RESPONSE_FILE}') as f:
    d = json.load(f)
paths = [m['path'] for m in d.get('policy_modules', [])]
sys.exit(0 if 'basicResource.yaml' in paths else 1)
"; then
    echo "Policy bundle is complete"
    exit 0
  fi
  # Show what we actually got, so a repeat failure is diagnosable instead of silent.
  echo "  attempt ${i}: basicResource.yaml not yet in bundle. Response was:"
  cat "${RESPONSE_FILE}"
  echo
  sleep 1
done

echo "opal-server's policy bundle never became complete" >&2
echo "If the bundle above is stable and simply lacks the file, check the extension filters on opal_server." >&2
exit 1
