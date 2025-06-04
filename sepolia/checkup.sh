#!/bin/bash

# --- Configuration ---

EL_RPC_URL="http://localhost:8545"
CL_API_URL="http://localhost:3500"

#EL_RPC_URL="http://:8545"
#CL_API_URL="http://:3500"

INTERVAL_MS=500                  # Interval between checks
REQ_TIMEOUT_MS=500            # Requests timeout 
DURATION_MIN=1                   # Duration in minutes







TIMEOUT=5
CURL_OPTS="-s --fail --connect-timeout $TIMEOUT --max-time $TIMEOUT"
CURL_OPTS_EL="$CURL_OPTS -X POST -H Content-Type:application/json --data"
CURL_OPTS_CL="$CURL_OPTS -X GET -H Accept:application/json"

COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[0;33m'
COLOR_BLUE='\033[0;34m'
COLOR_RESET='\033[0m'

check_jq() {
  if ! command -v jq &> /dev/null; then
    echo -e "${COLOR_RED}Error: 'jq' not found.${COLOR_RESET}"
    exit 1
  fi
}

check_jq

passed_el=0
failed_el=0
failed_el_methods=()

passed_cl=0
failed_cl=0
failed_cl_paths=()

query_el() {
  local method="$1"
  local params="$2"

  local request_body
  if [[ "$params" == "[]" ]]; then
    request_body=$(jq -nc --arg method "$method" '{jsonrpc:"2.0", method:$method, params:[], id:1}')
  else
    if ! echo "$params" | jq empty 2>/dev/null; then
      echo -e "  ❌"
      return 2
    fi
    request_body=$(jq -nc --arg method "$method" --argjson params "$params" \
      '{jsonrpc:"2.0", method:$method, params:$params, id:1}')
  fi

  response=$(curl $CURL_OPTS_EL "$request_body" "$EL_RPC_URL" 2>&1)
  if [ $? -ne 0 ] || echo "$response" | jq -e '.error' > /dev/null; then
    echo -e "  ❌"
    return 1
  fi

  echo -e "  ✅"
  return 0
}

query_cl() {
  local path="$1"
  local url="${CL_API_URL}${path}"
  response=$(curl $CURL_OPTS_CL "$url" 2>&1)
  if [ $? -ne 0 ] || ! echo "$response" | jq -e . > /dev/null; then
    echo -e "  ❌"
    return 1
  fi
  echo -e "  ✅"
  return 0
}

echo -e "${COLOR_BLUE}Checking EL RPC methods...${COLOR_RESET}"

EL_METHODS=(
  "web3_clientVersion"
  "web3_sha3" '["0x68656c6c6f20776f726c64"]'
  "net_version"
  "net_peerCount"
  "net_listening"
  "eth_protocolVersion"
  "eth_syncing"
  "eth_coinbase"
  "eth_mining"
  "eth_hashrate"
  "eth_gasPrice"
  "eth_accounts"
  "eth_blockNumber"
  "eth_getBalance" '["0x0000000000000000000000000000000000000000", "latest"]'
  "eth_getStorageAt" '["0x0000000000000000000000000000000000000000", "0x0", "latest"]'
  "eth_getTransactionCount" '["0x0000000000000000000000000000000000000000", "latest"]'
  "eth_getBlockTransactionCountByHash" '["0x0000000000000000000000000000000000000000000000000000000000000000"]'
  "eth_getBlockTransactionCountByNumber" '["latest"]'
  "eth_getUncleCountByBlockHash" '["0x0000000000000000000000000000000000000000000000000000000000000000"]'
  "eth_getUncleCountByBlockNumber" '["latest"]'
  "eth_getCode" '["0x0000000000000000000000000000000000000000", "latest"]'
  "eth_sign" '["0x0000000000000000000000000000000000000000", "0xdeadbeef"]'
  "eth_sendTransaction" '[{"from":"0x0000000000000000000000000000000000000000","to":"0x0000000000000000000000000000000000000000","value":"0x0"}]'
  "eth_sendRawTransaction" '["0x"]'
  "eth_call" '[{"to":"0x0000000000000000000000000000000000000000", "data":"0x"}, "latest"]'
  "eth_estimateGas" '[{"to":"0x0000000000000000000000000000000000000000"}]'
  "eth_getBlockByHash" '["0x0000000000000000000000000000000000000000000000000000000000000000", false]'
  "eth_getBlockByNumber" '["latest", false]'
  "eth_getTransactionByHash" '["0x0000000000000000000000000000000000000000000000000000000000000000"]'
  "eth_getTransactionByBlockHashAndIndex" '["0x0000000000000000000000000000000000000000000000000000000000000000", "0x0"]'
  "eth_getTransactionByBlockNumberAndIndex" '["latest", "0x0"]'
  "eth_getTransactionReceipt" '["0x0000000000000000000000000000000000000000000000000000000000000000"]'
  "eth_getUncleByBlockHashAndIndex" '["0x0000000000000000000000000000000000000000000000000000000000000000", "0x0"]'
  "eth_getUncleByBlockNumberAndIndex" '["latest", "0x0"]'
  "eth_newFilter" '[{"fromBlock":"latest","toBlock":"latest","address":"0x0000000000000000000000000000000000000000"}]'
  "eth_newBlockFilter"
  "eth_newPendingTransactionFilter"
  "eth_uninstallFilter" '["0x1"]'
  "eth_getFilterChanges" '["0x1"]'
  "eth_getFilterLogs" '["0x1"]'
  "eth_getLogs" '[{"fromBlock":"latest","toBlock":"latest","address":"0x0000000000000000000000000000000000000000"}]'
  "eth_chainId"
)

for ((i=0; i<${#EL_METHODS[@]}; i+=2)); do
  method="${EL_METHODS[i]}"
  params="${EL_METHODS[i+1]:-[]}"
  query_el "$method" "$params" >/dev/null
  result=$?
  if [ $result -eq 0 ]; then
    ((passed_el++))
  else
    ((failed_el++))
    failed_el_methods+=("$method")
  fi
done

echo -e "\n${COLOR_BLUE}Checking CL REST endpoints...${COLOR_RESET}"
CL_PATHS=(
  "/eth/v1/node/health"
  "/eth/v1/node/syncing"
  "/eth/v1/node/version"
  "/eth/v1/node/identity"
  "/eth/v1/beacon/genesis"
  "/eth/v1/beacon/states/head/fork"
  "/eth/v1/beacon/states/head/finality_checkpoints"
  "/eth/v1/beacon/states/head/validators"
  "/eth/v1/beacon/headers/head"
  "/eth/v1/config/spec"
  "/eth/v1/config/deposit_contract"
  "/eth/v1/debug/beacon/states/head"
  "/eth/v1/events"
  "/eth/v1/validator/duties/proposer/1"
  "/eth/v1/validator/duties/attester/1"
  "/eth/v1/validator/blocks/1"
  "/eth/v1/validator/sync_committees/1"
  "/eth/v1/beacon/states/head/validators/0"
)

for path in "${CL_PATHS[@]}"; do
  query_cl "$path" >/dev/null
  if [ $? -eq 0 ]; then
    ((passed_cl++))
  else
    ((failed_cl++))
    failed_cl_paths+=("$path")
  fi
done

echo -e "\n${COLOR_GREEN}✅ EL methods passed: $passed_el${COLOR_RESET}"
echo -e "${COLOR_RED}❌ EL methods failed: $failed_el${COLOR_RESET}"
if [ $failed_el -gt 0 ]; then
  for m in "${failed_el_methods[@]}"; do
    echo "  - $m"
  done
fi

echo -e "\n${COLOR_GREEN}✅ CL endpoints passed: $passed_cl${COLOR_RESET}"
echo -e "${COLOR_RED}❌ CL endpoints failed: $failed_cl${COLOR_RESET}"
if [ $failed_cl -gt 0 ]; then
  for p in "${failed_cl_paths[@]}"; do
    echo "  - $p"
  done
fi











echo -e "\n${COLOR_BLUE} starting latency tests...${COLOR_RESET}"






#!/bin/bash

INTERVAL_SEC=$(bc <<< "scale=3; $INTERVAL_MS/1000")
DURATION_SEC=$((DURATION_MIN * 60))
REQ_TIMEOUT_SEC=$(bc <<< "scale=3; $REQ_TIMEOUT_MS/1000")

# === L1 RPC (EL) ===
echo "Checking L1 RPC ($EL_RPC_URL) for $DURATION_MIN minutes every ${INTERVAL_MS}ms..."
l1_success=0
l1_fail=0
end_time=$((SECONDS + DURATION_SEC))
while [ $SECONDS -lt $end_time ]; do
  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time "$REQ_TIMEOUT_SEC" \
    -X POST -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' "$EL_RPC_URL")

  if [ "$http_code" -eq 200 ]; then
    ((l1_success++))
  else
    ((l1_fail++))
  fi

  sleep "$INTERVAL_SEC"
done
echo -e "L1 RPC results:\n✅: $l1_success\n❌: $l1_fail"

# === Beacon RPC (CL) ===
echo -e "\nChecking Beacon RPC ($CL_API_URL) for $DURATION_MIN minutes every ${INTERVAL_MS}ms..."
cl_success=0
cl_fail=0
end_time=$((SECONDS + DURATION_SEC))
while [ $SECONDS -lt $end_time ]; do
  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time "$REQ_TIMEOUT_SEC" \
    "$CL_API_URL/eth/v1/beacon/headers/head")

  if [ "$http_code" -eq 200 ]; then
    ((cl_success++))
  else
    ((cl_fail++))
  fi

  sleep "$INTERVAL_SEC"
done
echo -e "Beacon RPC results:\n✅: $cl_success\n❌: $cl_fail"

echo -e "\n${COLOR_BLUE}All checks complete.${COLOR_RESET}"
exit 0