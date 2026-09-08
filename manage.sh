#!/bin/bash
set -uo pipefail
STATE_FILE="./instances.json"
PURPLE='\033[1;35m'; GREEN='\033[0;32m'; NC='\033[0m'

cmd="${1:-}"

case "$cmd" in
  list)
    if [ ! -f "$STATE_FILE" ]; then
      echo "No instances recorded yet."
      exit 0
    fi
    python3 -c "
import json
with open('$STATE_FILE') as f:
    data = json.load(f)
for name, info in data.items():
    print(f\"{name}: user={info['ssh_user']} port={info['ssh_port']} node={info['node_hostname']} created={info['created_at']}\")
"
    echo ""
    docker ps --filter "name=qvm-" --format "  [running] {{.Names}}  ({{.Status}})"
    ;;
  remove)
    customer="${2:-}"
    [ -z "$customer" ] && { echo "Usage: $0 remove <customer_name>"; exit 1; }
    docker rm -f "qvm-${customer}" 2>/dev/null || true
    python3 -c "
import json
with open('$STATE_FILE') as f:
    data = json.load(f)
data.pop('$customer', None)
with open('$STATE_FILE', 'w') as f:
    json.dump(data, f, indent=2)
"
    echo "Removed ${customer}."
    ;;
  show)
    customer="${2:-}"
    [ -z "$customer" ] && { echo "Usage: $0 show <customer_name>"; exit 1; }
    python3 -c "
import json
with open('$STATE_FILE') as f:
    data = json.load(f)
info = data.get('$customer')
if not info:
    print('No record for $customer')
else:
    print(f\"Customer:   $customer\")
    print(f\"Node:       {info['node_hostname']}\")
    print(f\"Username:   {info['ssh_user']}\")
    print(f\"Port:       {info['ssh_port']}\")
    print(f\"Auth token: {info['auth_token']}\")
    print(f\"Created:    {info['created_at']}\")
    print('(Password isn\\'t stored on disk — only shown at creation + webhook.)')
"
    ;;
  *)
    echo "Usage: $0 {list|remove <customer_name>|show <customer_name>}"
    exit 1
    ;;
esac
