#!/bin/bash
set -euo pipefail

# Colors
readonly COLOR_RESET=$(tput sgr0)
readonly COLOR_BOLD=$(tput bold)
readonly COLOR_RED=$(tput setaf 1)
readonly COLOR_GREEN=$(tput setaf 2)
readonly COLOR_YELLOW=$(tput setaf 3)
readonly COLOR_CYAN=$(tput setaf 6)

# UI helpers
info()    { echo -e "${COLOR_CYAN}${1}${COLOR_RESET}"; }
success() { echo -e "${COLOR_GREEN}${1}${COLOR_RESET}"; }
warning() { echo -e "${COLOR_YELLOW}${1}${COLOR_RESET}"; }
error()   { echo -e "${COLOR_RED}${1}${COLOR_RESET}" >&2; }

pause() {
  echo
  read -rp "${COLOR_BOLD}${COLOR_GREEN} 🔙🔙 Back to main menu? << ${COLOR_RESET}"
}

# External hooks
EXTRA_MENU_ITEMS=()
EXTRA_MENU_FUNCTIONS=()

register_menu_item() {
  EXTRA_MENU_ITEMS+=("$1")         # e.g., "42) My Special Task"
  EXTRA_MENU_FUNCTIONS+=("$2")     # e.g., "my_special_task"
}

invoke_extra_menu_function() {
  local choice="$1"
  for i in "${!EXTRA_MENU_ITEMS[@]}"; do
    local item="${EXTRA_MENU_ITEMS[i]}"
    local num="${item#[}"; num="${num%%]*}" # tirm [ and ]
    if [[ "$choice" == "$num" ]]; then
      "${EXTRA_MENU_FUNCTIONS[i]}"
      return 0
    fi
  done
  return 1
}

print_extra_menu_items() {
  for item in "${EXTRA_MENU_ITEMS[@]}"; do
    echo "  $item"
  done
  echo "${COLOR_RESET}"
}

# Actions
install_reinstall() {
  info "Starting install/reinstall process..."
}
edit_env() {
  info "Opening .env file in editor..."
  ${EDITOR:-nano} "./.env"
}
start_restart() {
  info "Starting/restarting the node..."
}
view_logs() {
  info "Showing logs (Ctrl+C to quit)..."
}
node_status() {
  info "Showing node status..."
}
stop_node() {
  info "Stopping node..."
}
enter_container_shell() {
  info "Opening shell in container..."
}

clean_up() {
  warning "Factory reset selected! This will delete all data."
  read -rp "Are you sure? [y/N]: " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    success "Factory reset completed."
  else
    info "Factory reset cancelled."
  fi
}

show_help() {
  #clear
  echo -e "${COLOR_BOLD}${COLOR_CYAN}AZTEC NODE SETUP - HELP${COLOR_RESET}"
  echo
  echo -e "${COLOR_BOLD}${COLOR_CYAN}Available Options:${COLOR_RESET}${COLOR_YELLOW}"
  echo "  [1] Install/Reinstall     - Install or reinstall the node."
  echo "  [2] Edit .env file        - Open the .env configuration file."
  echo "  [3] Start/Restart         - Start or restart the node process."
  echo "  [4] View Logs             - Show real-time node logs."
  echo "  [5] Status                - Check node status and health."
  echo "  [6] Stop                  - Stop the running node."
  echo "  [7] Shell                 - Open an interactive shell in the container."
  echo "  [RESET] Factory Reset     - Erase all data and reset to defaults."
  echo "  [0] Exit                  - Exit the menu."
  echo
  echo -e "${COLOR_BOLD}${COLOR_CYAN}Extra Items:${COLOR_RESET}${COLOR_YELLOW}"
  echo "  Custom actions added via scripts will be shown here."
  echo
  echo -e "${COLOR_BOLD}${COLOR_CYAN}Tips:${COLOR_RESET}${COLOR_YELLOW}"
  echo "  - Use arrow keys or numbers to select options."
  echo "  - Press Ctrl+C to quit logs view."
  echo ${COLOR_RESET}
}

# Menu
main_menu() {
  while true; do
    clear
    echo -e "${COLOR_CYAN}${COLOR_BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    👻 DLORD • AZTEC SETUP                    ║"
    echo "╚══════════════════════════════════════════════════════════════╝"

    echo -e "${COLOR_CYAN}Choose an option:"
    echo "  [1] Install/Reinstall"
    echo "  [2] Edit .env file"
    echo "  [3] Start/Restart"
    echo "  [4] View Logs"
    echo "  [5] Status"
    echo "  [6] Stop"
    echo "  [7] Shell"
    echo "  [8] Help"
    echo "  [RESET] Factory Reset"
    echo "  [0] Exit ${COLOR_RESET}"

    echo -e "${COLOR_YELLOW}${COLOR_BOLD}"; 
    print_extra_menu_items echo "${COLOR_RESET}"
    
    read -p "👉 Enter choice: " CHOICE

    case "$CHOICE" in
      1) install_reinstall ;;
      2) edit_env ;;
      3) start_restart ;;
      4) view_logs ;;
      5) node_status ;;
      6) stop_node ;;
      7) enter_container_shell ;;
      8) show_help ;;
      RESET) clean_up ;;
      0)
        echo -e "${COLOR_YELLOW}Goodbye.${COLOR_RESET}"
        exit 0
        ;;
      *)
        if ! invoke_extra_menu_function "$CHOICE"; then
          error "Invalid option."
        fi
        ;;
    esac

    pause
  done
}

