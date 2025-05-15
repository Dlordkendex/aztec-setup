#!/bin/bash
set -euo pipefail

BOLD=$(tput bold)
RESET=$(tput sgr0)
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
RED="\033[1;31m"

PROJECT_DIR="$(pwd)"
ENV_FILE="$PROJECT_DIR/.env"
AZTEC_DATA_DIR="$PROJECT_DIR/data/aztec"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
USEFUL_PORTS="40400 8080 22"


# Create directory structure
mkdir -p "$PROJECT_DIR" "$AZTEC_DATA_DIR"
## mkdir -p "$(dirname "$JWT_FILE")"

if [[ ! -f "$ENV_FILE" ]]; then
  # If the file does not exist, create and add content
  cat <<EOF >"$ENV_FILE"
## Press Ctrl+S to save, then Ctrl+X to exit
#
#
VALIDATOR_PRIVATE_KEY=
VALIDATOR_PUBLIC_ADDRESS=
P2P_IP=
ETHEREUM_HOSTS=
L1_CONSENSUS_HOST_URLS=
TCP_UDP_PORT=40400
HTTP_PORT=8080
#
#
## Press Ctrl+S, then Ctrl+X to save and exit
EOF
fi

if [[ -f "$ENV_FILE" ]]; then
  source $ENV_FILE
fi


CHOICE=""
main_menu(){
clear
echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                  👻 DLORD • AZTEC NODE TOOL                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"


echo -e "${CYAN}Choose an option:"
echo "  [1] Install/Reinstall"
echo "  [2] Edit .env file"
echo "  [3] Start/Restart"
echo "  [4] View Logs"
echo "  [5] Status"
echo "  [6] Stop"
echo "  [7] Clean Up"
echo "  [8] Shell"
echo "  [0] Exit ${RESET}"

echo -e "${YELLOW}"
echo "  [10] Fetch L2Block + Sync Proof + PeerId"
echo "${RESET}"
read -p "👉 Enter choice: " CHOICE

case "$CHOICE" in
  1) install_reinstall ;;
  2) edit_env ;;
  3) start_restart ;;
  4) view_logs ;;
  5) node_status ;;
  6) stop_node ;;
  7) clean_up ;;
  8) enter_container_shell ;;
  10) fetchl2block_proof_peerid ;;
  0)
    echo -e "${YELLOW}Goodbye.${RESET}"
    exit 0
    ;;
  *)
    echo -e "${RED}Invalid option.${RESET}"
    ;;
esac
}

install_reinstall() {
  read -p "Warning: This will delete some data and volumes. Do you want to continue? [y/N]: " confirm
  [[ "$confirm" != [yY] ]] && echo "Cancelled." && return

  echo -e "${CYAN}Install/Reinstall started...${RESET}"
  install_dependencies
  allow_ports $USEFUL_PORTS

  cd "$PROJECT_DIR"
  docker compose down -v
  docker compose build --no-cache
  echo -e "${GREEN}✅ Install/Reinstall completed successfully!${RESET}"
}

edit_env() {
  nano $ENV_FILE
  if [[ -f "$ENV_FILE" ]]; then
    source $ENV_FILE
  fi
  setup_compose_file
  echo -e "${GREEN}✅ .env variables updated successfully!${RESET}"
}

start_restart() {
  cd "$PROJECT_DIR"
  docker compose down
  docker compose up -d
  echo -e "${GREEN}✅🔃 Node restarted successfully ${RESET}"
}

view_logs() {
  echo -e "${CYAN}Streaming logs started (Ctrl+C to exit)...${RESET}"
  cd "$PROJECT_DIR"
  docker compose logs -f
}

node_status() {
  echo -e "${CYAN}Docker container status:${RESET}"
 #docker inspect aztec
  docker inspect -f \
' Name:  {{.Name}}
 Status:  {{.State.Status}}
 Running:  {{.State.Running}}
 Started At:  {{.State.StartedAt}}
 Finished At:  {{.State.FinishedAt}}
 Exit Code:  {{.State.ExitCode}}
 Restarting:  {{.State.Restarting}}
 OOM Killed:  {{.State.OOMKilled}}' aztec
}

stop_node() {
  cd "$PROJECT_DIR"
  docker compose down
  echo -e "${RED}🛑 Node stopped.${RESET}"
}

clean_up() {
  cd "$PROJECT_DIR"
  docker compose down -v
  echo -e "${GREEN}🚮 Node cleaned up successfully.${RESET}"
}

reload_env() {
  if [[ -f "$ENV_FILE" ]]; then
    source $ENV_FILE
  fi
}

enter_container_shell() {
  cd "$PROJECT_DIR"
  echo "List of running containers in this project (empty if none):"
  docker compose ps --format "{{.Name}}"

  echo -n "Enter a container, pick from the above list: "
  read -r container

  if [ -z "$container" ]; then
    echo "No container name provided."
    return 1
  fi

  local shell

  if docker exec "$container" test -x /bin/bash; then
    shell="/bin/bash"
  elif docker exec "$container" test -x /bin/sh; then
    shell="/bin/sh"
  else
    echo "No shell found in container $container"
    return 1
  fi

  docker compose exec "$container" "$shell"
}

healthcheck(){
  STATUS=$(curl -fs http://localhost/health > /dev/null 2>&1; echo $?)
  if [ "$STATUS" -eq 0 ]; then
    EMOJI="🟩"
  else
    EMOJI="🟥"
  fi

  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    -d parse_mode="MarkdownV2" \
    -d text="*Container:* \`aztec\`
*Health:* ${EMOJI}"

  exit $STATUS
}

setup_compose_file() {
  cat >"$COMPOSE_FILE" <<EOF
services:
  aztec:
    image: aztecprotocol/aztec:0.85.0-alpha-testnet.8
    container_name: aztec
    environment:
      ETHEREUM_HOSTS: "${ETHEREUM_HOSTS}"
      L1_CONSENSUS_HOST_URLS: "${L1_CONSENSUS_HOST_URLS}"
      DATA_DIRECTORY: "/data"
      VALIDATOR_PRIVATE_KEY: "${VALIDATOR_PRIVATE_KEY}"
      COINBASE: "${VALIDATOR_PUBLIC_ADDRESS}"

      P2P_IP: "${P2P_IP}"
      LOG_LEVEL: "info"
      P2P_MAX_TX_POOL_SIZE: "1000000000"
    entrypoint: >
      sh -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --network=alpha-testnet --node --archiver --sequencer'
    ports:
      - ${TCP_UDP_PORT}:40400/tcp
      - ${TCP_UDP_PORT}:40400/udp
      - ${HTTP_PORT}:8080
    volumes:
      - ${AZTEC_DATA_DIR}:/data
      - ./aztec.sh:/usr/local/bin/aztec.sh
    restart: unless-stopped
EOF
}

install_dependencies() {
  echo -e "\n🔧 ${YELLOW}${BOLD}Setting up system dependencies...${RESET}"

  sudo apt update > /dev/null 2>&1
  sudo apt install -y -qq --no-upgrade curl jq git ufw apt-transport-https ca-certificates software-properties-common gnupg lsb-release

  if ! command -v docker &> /dev/null; then
    echo "Docker not found. Installing Docker..."

    sudo apt-get remove -y containerd || true
    sudo apt-get purge -y containerd || true

    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker "$USER"

    echo "Docker installation complete."
  else
    echo "Docker is already installed."
  fi
}


####################################################################################################


fetchl2block_proof_peerid() {
  echo -e "\n🔍 ${YELLOW}Fetching latest L2 block info..."

  BLOCK=$(curl -s -X POST -H 'Content-Type: application/json' -d '{"jsonrpc":"2.0","method":"node_getL2Tips","params":[],"id":67}' http://localhost:$HTTP_PORT | jq -r ".result.proven.number")

  if [[ -z "$BLOCK" || "$BLOCK" == "null" ]]; then
    echo -e "❌ ${RED}Failed to fetch block number.${RESET}"
    return
  fi

  echo -e "✅ Current L2 Block Number: ${BOLD}$BLOCK${RESET}"
  echo -e "\n🔍 ${CYAN} computing Proof..."

  PROOF=$(curl -s -X POST -H 'Content-Type: application/json' -d "{\"jsonrpc\":\"2.0\",\"method\":\"node_getArchiveSiblingPath\",\"params\":[\"$BLOCK\",\"$BLOCK\"],\"id\":67}" http://localhost:$HTTP_PORT | jq -r ".result")

  echo -e "🔗 Sync Proof:"
  echo -e "$PROOF ${RESET}"
  echo -e "\n${YELLOW}🆔 Retrieving sequencer PeerId..."

  PEER_ID=$(docker logs aztec 2>&1 | grep -i '"peerId"' | grep -o '"peerId":"[^"]*"' | cut -d'"' -f4 | head -n 1)

  if [[ -n "$PEER_ID" ]]; then
    echo -e "✅ Sequencer PeerId: ${BOLD}$PEER_ID${RESET}"
  else
    echo -e "❌ ${RED}PeerId not found in logs.${RESET}"
  fi
}

fetch_ip() {
  local ip=$(curl -s https://ipinfo.io/ip)
  ip=${ip:-127.0.0.1}

  echo -e "📡 ${YELLOW}Detected server IP: ${GREEN}${BOLD}${ip}${RESET}"

  echo "$ip"
}

allow_ports() {
  for port in "$@"; do
    for proto in tcp udp; do
      if ! sudo ufw status | grep -q "$port/$proto"; then
        echo "Allowing port $port/$proto..."
        sudo ufw allow ${port}/${proto}
      fi
    done
  done
  sudo ufw --force enable
}


####################################################################################################

# Flags and options router 
for arg in "$@"; do
  case $arg in
    --help)
      echo "help"
      exit 0
      ;;
    --healthcheck)
      healthcheck
      exit 0
      ;;
    *)
  esac
done

# Show main menu if no arguments were passed
if [ $# -eq 0 ]; then
  setup_compose_file
  main_menu
  exit 0
fi
