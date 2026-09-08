#!/bin/bash
#
# QuantumCloud Provider — interactive admin provisioning script
#
# Run this YOURSELF as the admin. Not a public API — only runs when
# you, the admin, run it on the host.
#
set -uo pipefail

IMAGE_NAME="quantum-vps-base"
STATE_FILE="./instances.json"
CONFIG_FILE="./webhook.conf"

PURPLE='\033[1;35m'
CYAN='\033[0;36m'
DIM='\033[2m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

DISCORD_WEBHOOK_URL=""
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

# --- small helpers -------------------------------------------------------
step() { printf "${CYAN}[*]${NC} %s\n" "$1"; }
ok()   { printf "${GREEN}[ok]${NC} %s\n" "$1"; }
fail() { printf "${RED}[!]${NC} %s\n" "$1"; }

spinner() {
  # spinner "message" -- <command...>
  local msg="$1"; shift
  local pid frames="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏" i=0
  ( "$@" > /tmp/qvm_last_step.log 2>&1 ) &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i+1) % ${#frames} ))
    printf "\r${CYAN}%s${NC} %s   " "${frames:$i:1}" "$msg"
    sleep 0.1
  done
  wait "$pid"
  local rc=$?
  if [ $rc -eq 0 ]; then
    printf "\r${GREEN}✔${NC} %s   \n" "$msg"
  else
    printf "\r${RED}✘${NC} %s   \n" "$msg"
    echo "----- output -----"
    cat /tmp/qvm_last_step.log
    echo "-------------------"
  fi
  return $rc
}

printf "${PURPLE}"
cat << "EOF"
   ____                   _
  / __ \                 | |
 | |  | |_   _  __ _ _ __ | |_ _   _ _ __ ___
 | |  | | | | |/ _` | '_ \| __| | | | '_ ` _ \
 | |__| | |_| | (_| | | | | |_| |_| | | | | | |
  \___\_\\__,_|\__,_|_| |_|\__|\__,_|_| |_| |_|

     C L O U D   P R O V I D E R  —  P R O V I S I O N E R
EOF
printf "${NC}\n"

# --- interactive prompts --------------------------------------------------
read -rp "Node hostname (e.g. quantumnode1): " NODE_HOSTNAME
NODE_HOSTNAME=${NODE_HOSTNAME:-quantumnode1}

read -rp "Customer/record name (e.g. alice-01): " CUSTOMER_NAME
if [ -z "${CUSTOMER_NAME}" ]; then fail "Customer name is required."; exit 1; fi

read -rp "SSH username to create: " SSH_USER
if [ -z "${SSH_USER}" ]; then fail "SSH username is required."; exit 1; fi

echo "${DIM}(password will be visible as you type — some web terminals don't support hidden input)${NC}"
read -rp "SSH password to set: " SSH_PASS
if [ -z "${SSH_PASS}" ]; then fail "Password is required."; exit 1; fi

read -rp "Host SSH port [blank = random 22000-27000]: " HOST_PORT
HOST_PORT=${HOST_PORT:-$(( RANDOM % 5000 + 22000 ))}

CONTAINER_NAME="qvm-${CUSTOMER_NAME}"
echo ""

# --- build image if needed ------------------------------------------------
if ! docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
  spinner "Building base image (one-time, ~1-2 min)" docker build -t "$IMAGE_NAME" . || { fail "Image build failed."; exit 1; }
else
  ok "Base image already present."
fi

if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}\$"; then
  fail "A container named '${CONTAINER_NAME}' already exists."
  echo "    Remove it first: docker rm -f ${CONTAINER_NAME}"
  exit 1
fi

# quantum-<13 random alphanumeric chars>
# (openssl rand instead of tr|head — avoids the broken-pipe warning some
#  terminals print when head closes the pipe early on tr's output)
RAND13=$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | cut -c1-13)
AUTH_TOKEN="quantum-${RAND13}"

# --- create container -------------------------------------------------
spinner "Creating container '${CONTAINER_NAME}'" docker run -d \
  --name "${CONTAINER_NAME}" \
  --hostname "${NODE_HOSTNAME}" \
  --restart unless-stopped \
  --memory="1g" \
  --cpus="1" \
  --pids-limit=200 \
  -p "${HOST_PORT}:22" \
  "${IMAGE_NAME}" || { fail "Container creation failed."; exit 1; }

# --- create the user inside it -----------------------------------------
spinner "Creating SSH user '${SSH_USER}'" docker exec "${CONTAINER_NAME}" bash -c "
  useradd -m -s /bin/bash '${SSH_USER}' &&
  echo '${SSH_USER}:${SSH_PASS}' | chpasswd &&
  usermod -aG sudo '${SSH_USER}'
" || { fail "User creation failed inside container."; exit 1; }

# --- save record ---------------------------------------------------------
python3 - "$STATE_FILE" "$CUSTOMER_NAME" "$CONTAINER_NAME" "$SSH_USER" "$HOST_PORT" "$AUTH_TOKEN" "$NODE_HOSTNAME" << 'PYEOF'
import json, sys, os, datetime
state_file, customer, container, user, port, token, node = sys.argv[1:8]
data = {}
if os.path.exists(state_file):
    with open(state_file) as f:
        data = json.load(f)
data[customer] = {
    "container_name": container,
    "node_hostname": node,
    "ssh_user": user,
    "ssh_port": int(port),
    "auth_token": token,
    "created_at": datetime.datetime.utcnow().isoformat() + "Z",
}
with open(state_file, "w") as f:
    json.dump(data, f, indent=2)
PYEOF
ok "Instance record saved to ${STATE_FILE}"

HOST_IP=$(curl -s ifconfig.me || echo "YOUR_SERVER_IP")
PASS_B64=$(printf '%s' "${SSH_PASS}" | base64)

echo ""
printf "${PURPLE}"
echo "========================================================"
echo "  QuantumCloud Provider — instance ready"
echo "========================================================"
printf "${NC}"
echo "  Node hostname:  ${NODE_HOSTNAME}"
echo "  SSH command:    ssh ${SSH_USER}@${HOST_IP} -p ${HOST_PORT}"
echo "  Username:       ${SSH_USER}"
echo "  Password:       (as entered above)"
echo "  Auth token:     ${AUTH_TOKEN}"
printf "${PURPLE}"
echo "========================================================"
printf "${NC}"

# --- Discord webhook (admin-only notification) --------------------------
if [ -n "${DISCORD_WEBHOOK_URL}" ]; then
  spinner "Notifying Discord webhook" python3 - "$DISCORD_WEBHOOK_URL" "$CUSTOMER_NAME" "$NODE_HOSTNAME" "$SSH_USER" \
           "$HOST_IP" "$HOST_PORT" "$AUTH_TOKEN" "$PASS_B64" << 'PYEOF'
import sys, json, urllib.request
webhook_url, customer, node, user, host, port, token, pass_b64 = sys.argv[1:9]
ssh_cmd = f"ssh {user}@{host} -p {port}"
embed = {
    "title": "New QuantumCloud Provider instance",
    "color": 0x9B30FF,
    "fields": [
        {"name": "Customer / record", "value": customer, "inline": True},
        {"name": "Node hostname", "value": node, "inline": True},
        {"name": "Username", "value": user, "inline": True},
        {"name": "SSH command", "value": f"```{ssh_cmd}```", "inline": False},
        {"name": "Auth token", "value": f"`{token}`", "inline": False},
        {"name": "Password (base64, click to reveal)", "value": f"||`{pass_b64}`||", "inline": False},
    ],
    "footer": {"text": "Admin-only record — do not forward this message."},
}
payload = json.dumps({"embeds": [embed]}).encode("utf-8")
req = urllib.request.Request(webhook_url, data=payload, headers={"Content-Type": "application/json"}, method="POST")
urllib.request.urlopen(req, timeout=10)
PYEOF
else
  echo "${DIM}[i] No webhook configured — copy webhook.conf.example to webhook.conf to enable notifications.${NC}"
fi
