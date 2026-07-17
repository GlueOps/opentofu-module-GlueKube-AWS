#!/usr/bin/env bash
#
# Check that the cluster created by `tofu apply` + the AutoGlue setup action is healthy.
#
# Resolves the org id by name, picks a master server, reveals that server's ssh private
# key, then ssh's in and runs `kubectl get pods -A` against the kubeadm admin kubeconfig.
# Exits 0 if kubectl responds, 1 otherwise. Requires `curl`, `jq` and `ssh` on PATH.
#
# Required environment variables:
#   BASE_URL   AutoGlue API base url
#   API_KEY    AutoGlue API key   (sent as X-API-KEY header)
#   ORG_NAME   AutoGlue org name  (resolved to org id via the /orgs endpoint)
set -euo pipefail

: "${BASE_URL:?BASE_URL is required}"
: "${API_KEY:?API_KEY is required}"
: "${ORG_NAME:?ORG_NAME is required}"

echo "==> Step 1: Getting org_id for org '${ORG_NAME}'..."
ORGS=$(curl -sfS --http1.1 -X GET "${BASE_URL}/orgs" \
  -H "accept: application/json" \
  -H "X-API-KEY: ${API_KEY}")

ORG_ID=$(echo "$ORGS" | jq -r --arg name "$ORG_NAME" \
  '.[] | select(.name == $name) | .id')

if [ -z "$ORG_ID" ] || [ "$ORG_ID" = "null" ]; then
  echo "ERROR: Org '${ORG_NAME}' not found"
  exit 1
fi
echo "Found org_id: ${ORG_ID}"

echo "==> Step 2: Getting a master server..."
SERVERS=$(curl -sfS --http1.1 -G "${BASE_URL}/servers" \
  --data-urlencode "role=master" \
  -H "accept: application/json" \
  -H "X-API-KEY: ${API_KEY}" \
  -H "x-org-id: ${ORG_ID}")

SERVER=$(echo "$SERVERS" | jq -r '.[0] // empty')
if [ -z "$SERVER" ]; then
  echo "ERROR: no master servers returned by ${BASE_URL}/servers?role=master"
  exit 1
fi

MASTER_IP=$(echo "$SERVER" | jq -r '.public_ip_address')
SSH_USER=$(echo "$SERVER" | jq -r '.ssh_user')
SSH_KEY_ID=$(echo "$SERVER" | jq -r '.ssh_key_id')
HOSTNAME_=$(echo "$SERVER" | jq -r '.hostname')

if [ -z "$MASTER_IP" ] || [ "$MASTER_IP" = "null" ]; then
  echo "ERROR: master server '${HOSTNAME_}' has no public_ip_address"
  exit 1
fi
echo "Using master ${HOSTNAME_} at ${MASTER_IP} (ssh_user: ${SSH_USER})"

echo "==> Step 3: Revealing the private key..."
KEY=$(curl -sfS --http1.1 -G "${BASE_URL}/ssh/${SSH_KEY_ID}" \
  --data-urlencode "reveal=true" \
  -H "accept: application/json" \
  -H "X-API-KEY: ${API_KEY}" \
  -H "x-org-id: ${ORG_ID}")

KEY_FILE=$(mktemp)
trap 'rm -f "$KEY_FILE"' EXIT
chmod 600 "$KEY_FILE"
echo "$KEY" | jq -r '.private_key // empty' > "$KEY_FILE"

if [ ! -s "$KEY_FILE" ]; then
  echo "ERROR: ssh key ${SSH_KEY_ID} returned an empty private_key"
  exit 1
fi
# Guard against a key stored without its trailing newline; ssh rejects those.
[ -n "$(tail -c1 "$KEY_FILE")" ] && echo >> "$KEY_FILE"

echo "==> Step 4: Running kubectl on ${MASTER_IP}..."
ssh -i "$KEY_FILE" \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o ConnectTimeout=30 \
  "${SSH_USER}@${MASTER_IP}" \
  'sudo KUBECONFIG=/etc/kubernetes/admin.conf kubectl get pods -A'

echo "Cluster is reachable and kubectl responded."
