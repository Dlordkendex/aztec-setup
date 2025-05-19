#!/bin/bash
set -euo pipefail

# --- STYLES ---
BOLD=$(tput bold)
RESET=$(tput sgr0)
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
RED="\033[1;31m"

# --- Configuration ---
PROJECT_DIR="$(pwd)"
ENV_FILE="$PROJECT_DIR/.env"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
GETH_DATA_DIR="$PROJECT_DIR/data/geth"
PRYSM_DATA_DIR="$PROJECT_DIR/data/prysm"
JWT_FILE="$PROJECT_DIR/data/jwt/jwt.hex"
USEFUL_PORTS="30303 6060 13000 9000"

# Create directory structure
mkdir -p "$PROJECT_DIR" "$GETH_DATA_DIR" "$PRYSM_DATA_DIR" "$(dirname "$JWT_FILE")"


if [[ ! -f "$ENV_FILE" ]]; then
  # If the file does not exist, create and add content
  cat <<EOF >"$ENV_FILE"
## Press Ctrl+S to save, then Ctrl+X to exit
#
#

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
echo "║         👻 DLORD • SEPOLIA NODE - GETH + PRYSM SETUP         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"


echo -e "${CYAN}Choose an option:"
echo "  [1] Install/Reinstall"
echo "  [2] Edit .env file"
echo "  [3] Start/Restart"
echo "  [4] View Logs"
echo "  [5] Status"
echo "  [6] Stop"
echo "  [7] Shell"
echo "  [0] Exit"
echo "  [RESET] Factory Reset${RESET}"

echo -e "${YELLOW}"
echo "  [10] Run a checkup"
echo "${RESET}"
read -p "👉 Enter choice: " CHOICE

case "$CHOICE" in
  1) install_reinstall ;;
  2) edit_env ;;
  3) start_restart ;;
  4) view_logs ;;
  5) node_status ;;
  6) stop_node ;;
  7) enter_container_shell ;;
  10) run_checkup ;;
  0)
    echo -e "${YELLOW}Goodbye.${RESET}"
    exit 0
    ;;
   "RESET") clean_up ;;
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
  setup_jwt

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
  list_runing_containers

  echo -n "Enter a container, pick from the above list: "
  read -r container

  if [ -z "$container" ]; then
    echo "No container name provided."
    return 1
  fi

  echo -e "${CYAN}Docker container status:${RESET}"
  docker inspect -f \
' Name:  {{.Name}}
 Status:  {{.State.Status}}
 Running:  {{.State.Running}}
 Started At:  {{.State.StartedAt}}
 Finished At:  {{.State.FinishedAt}}
 Exit Code:  {{.State.ExitCode}}
 Restarting:  {{.State.Restarting}}
 OOM Killed:  {{.State.OOMKilled}}' $container
}

stop_node() {
  cd "$PROJECT_DIR"
  docker compose down
  echo -e "${RED}🛑 Node stopped.${RESET}"
}

clean_up() {
  cd "$PROJECT_DIR"
  docker compose down -v
  rm -rf ./data
  echo -e "${GREEN}🚮 Node cleaned up successfully.${RESET}"
}

reload_env() {
  if [[ -f "$ENV_FILE" ]]; then
    source $ENV_FILE
  fi
}

list_runing_containers() {
  cd "$PROJECT_DIR"
  echo "List of running containers in this project (empty if none):"
  docker compose ps --format "{{.Name}}"
}

enter_container_shell() {
  cd "$PROJECT_DIR"
  list_runing_containers

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


setup_compose_file() {
    # Write Docker Compose file
cat >"$COMPOSE_FILE" <<EOF
services:
  geth:
    image: ethereum/client-go:stable
    container_name: geth
    command:
      --sepolia
      --syncmode=snap
      --cache=12288
      --cache.database=50
      --cache.gc=15
      --cache.snapshot=20
      --cache.trie=15
      --http
      --http.port=8545
      --http.addr=0.0.0.0
      --http.vhosts=*
      --http.api=eth,net,web3
      --authrpc.port=8551
      --authrpc.addr=0.0.0.0
      --authrpc.vhosts=*
      --authrpc.jwtsecret=/jwtsecret
    volumes:
      - ${GETH_DATA_DIR}:/root/.ethereum
      - ${JWT_FILE}:/jwtsecret:ro
    ports:
      - 30303:30303
      - 30303:30303/udp
      - 8545:8545
      - 8546:8546
      - 8551:8551
    restart: always
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "1"
    networks:
      - sepolia_net

  prysm:
    image: prysmaticlabs/prysm-beacon-chain:stable
    container_name: prysm
    depends_on:
      - geth
    command:
      --sepolia
      --accept-terms-of-use
      --datadir=/data
      --disable-monitoring
      --rpc-host=0.0.0.0
      --execution-endpoint=http://geth:8551
      --jwt-secret=/jwtsecret
      --rpc-port=4000
      --grpc-gateway-corsdomain=*
      --grpc-gateway-host=0.0.0.0
      --grpc-gateway-port=3500
      --min-sync-peers=3
      --beacon-db-pruning=true
      --checkpoint-sync-url=https://beaconstate-sepolia.chainsafe.io
      --genesis-beacon-api-url=https://beaconstate-sepolia.chainsafe.io
    volumes:
      - ${PRYSM_DATA_DIR}:/data
      - ${JWT_FILE}:/jwtsecret:ro
    ports:
      - "3500:3500"
      - "4000:4000"
    restart: always
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "2"
    networks:
      - sepolia_net
networks:
  sepolia_net:
    driver: bridge
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

setup_jwt() {
    if [ ! -f "$JWT_FILE" ]; then
        echo -e "${YELLOW}Creating JWT secret...${RESET}"
        openssl rand -hex 32 >"$JWT_FILE"
    else
        echo -e "${GREEN}JWT secret already exists. Skipping creation.${RESET}"
    fi
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

run_checkup() {
  bash "$(dirname "$0")/checkup.sh"
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
