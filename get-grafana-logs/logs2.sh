#!/bin/bash

# =============================================================================
# Generic Grafana/Loki log fetcher (CLI version)
# =============================================================================
#
# STEP 0: Run the tsh proxy first:
#   tsh login --proxy=teleport.parity.io:443
#   tsh proxy app loki --port 10700
#
# Then use CLI flags instead of editing the script. Run with --help for usage.
# =============================================================================

# =============================================================================
# CONFIGURATION PRESETS (for reference — pass node/chain/org-id via CLI flags)
# =============================================================================

# --- Asset Hub Polkadot (collator) ---
# TSH_APP=loki  # tsh proxy app loki --port 10700
# ORG_ID='parity-hosted-mainnet'
# --node polkadot-parachain-asset-hub-collator-node-0 --chain asset-hub-polkadot

# --- Asset Hub Polkadot (rpc) ---
# TSH_APP=loki
# ORG_ID='parity-hosted-mainnet'
# --node polkadot-asset-hub-rpc-scw-node-0 --chain asset-hub-polkadot

# --- Asset Hub Kusama ---
# TSH_APP=loki
# ORG_ID='parity-hosted-mainnet'
# --node kusama-parachain-asset-hub-collator-node-0 --chain asset-hub-kusama

# --- Asset Hub Westend (testnet) ---
# TSH_APP=loki
# ORG_ID='parity-hosted-testnet'
# --node westend-asset-hub-rpc-scw-node-0

# --- Asset Hub Paseo ---
# TSH_APP=loki
# ORG_ID='chain-paseo'
# --node paseo-asset-hub-rpc-node-0 --chain asset-hub-paseo

# --- Kusama validator ---
# TSH_APP=loki
# ORG_ID='parity-hosted-mainnet'
# --node kusama-validator-waw1-1
## other kusama validators:
## --node kusama-validator-bhs5-0

# --- Versi (BROKEN - may need different tsh app or org-id, see notes) ---
# TSH_APP=versi-loki  # or maybe: loki-versi ?
# ORG_ID='parity-hosted-testnet'  # might be wrong - try other org-ids
# --node node-0

# =============================================================================
# DEFAULTS
# =============================================================================
TSH_APP=loki
ORG_ID='default'
#ORG_ID='parity-hosted-mainnet'
LIMIT=50000000
ADDR='http://127.0.0.1:10700'

NODE=''
CHAIN=''
FILTER=''
SINCE='24h'
FROM=''
TO=''
MODE='query'  # query | list-labels | list-nodes | list-chains
SINCE_SET=false

# =============================================================================
# USAGE
# =============================================================================
usage() {
  cat <<'EOF'
Usage: logs2.sh [OPTIONS]

Prerequisites:
  tsh login --proxy=teleport.parity.io:443
  tsh proxy app loki --port 10700

Options:
  --list-labels          List all available Loki labels
  --list-nodes           List all node label values
  --list-chains          List all chain label values
  --node NODE            Select node (required for log fetching)
  --chain CHAIN          Filter by chain (optional, added to query)
  --filter PATTERN       LogQL filter pattern (e.g. 'Imported #')
  --since DURATION       Relative time range (default: 24h)
  --from TIMESTAMP       Start of absolute time range (format: YYYY-MM-DDTHH:MM:SS[.ss]Z)
  --to TIMESTAMP         End of absolute time range (format: YYYY-MM-DDTHH:MM:SS[.ss]Z)
  --org-id ID            Override org-id (default: parity-hosted-mainnet)
  --limit N              Override limit (default: 50000000)
  --help                 Show this help

Examples:
  logs2.sh --list-labels
  logs2.sh --list-nodes
  logs2.sh --list-chains
  logs2.sh --node polkadot-parachain-asset-hub-collator-node-0
  logs2.sh --node polkadot-parachain-asset-hub-collator-node-0 --chain asset-hub-polkadot
  logs2.sh --node kusama-validator-waw1-1 --since 2h
  logs2.sh --node polkadot-parachain-asset-hub-collator-node-0 --filter 'Imported #'
  logs2.sh --node westend-asset-hub-rpc-scw-node-0 --org-id parity-hosted-testnet --since 5m
  logs2.sh --node kusama-validator-waw1-1 --from 2026-02-20T11:15:00.00Z --to 2026-02-24T11:15:00.00Z
EOF
}

# =============================================================================
# TIMESTAMP VALIDATION
# =============================================================================
validate_timestamp() {
  local ts="$1"
  local flag="$2"
  if ! [[ "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?Z$ ]]; then
    echo "ERROR: Invalid timestamp for $flag: $ts" >&2
    echo "Expected format: YYYY-MM-DDTHH:MM:SS[.ss]Z (e.g. 2026-02-08T19:00:00.00Z)" >&2
    exit 1
  fi
}

# =============================================================================
# PARSE ARGUMENTS
# =============================================================================
if [ $# -eq 0 ]; then
  usage
  exit 1
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --help)
      usage
      exit 0
      ;;
    --list-labels)
      MODE='list-labels'
      shift
      ;;
    --list-nodes)
      MODE='list-nodes'
      shift
      ;;
    --list-chains)
      MODE='list-chains'
      shift
      ;;
    --node)
      [ -z "${2:-}" ] && { echo "ERROR: --node requires a value" >&2; exit 1; }
      NODE="$2"
      shift 2
      ;;
    --chain)
      [ -z "${2:-}" ] && { echo "ERROR: --chain requires a value" >&2; exit 1; }
      CHAIN="$2"
      shift 2
      ;;
    --filter)
      [ -z "${2:-}" ] && { echo "ERROR: --filter requires a value" >&2; exit 1; }
      FILTER="$2"
      shift 2
      ;;
    --since)
      [ -z "${2:-}" ] && { echo "ERROR: --since requires a value" >&2; exit 1; }
      SINCE="$2"
      SINCE_SET=true
      shift 2
      ;;
    --from)
      [ -z "${2:-}" ] && { echo "ERROR: --from requires a value" >&2; exit 1; }
      FROM="$2"
      shift 2
      ;;
    --to)
      [ -z "${2:-}" ] && { echo "ERROR: --to requires a value" >&2; exit 1; }
      TO="$2"
      shift 2
      ;;
    --org-id)
      [ -z "${2:-}" ] && { echo "ERROR: --org-id requires a value" >&2; exit 1; }
      ORG_ID="$2"
      shift 2
      ;;
    --limit)
      [ -z "${2:-}" ] && { echo "ERROR: --limit requires a value" >&2; exit 1; }
      LIMIT="$2"
      shift 2
      ;;
    *)
      echo "ERROR: Unknown option: $1" >&2
      echo "" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# =============================================================================
# VALIDATION
# =============================================================================

# Validate --from/--to pair
if [ -n "$FROM" ] && [ -z "$TO" ]; then
  echo "ERROR: --from requires --to" >&2
  exit 1
fi
if [ -z "$FROM" ] && [ -n "$TO" ]; then
  echo "ERROR: --to requires --from" >&2
  exit 1
fi

# Validate mutual exclusivity
if [ -n "$FROM" ] && [ "$SINCE_SET" = true ]; then
  echo "ERROR: --since and --from/--to are mutually exclusive" >&2
  exit 1
fi

# Validate timestamp formats
if [ -n "$FROM" ]; then
  validate_timestamp "$FROM" "--from"
  validate_timestamp "$TO" "--to"
fi

# For query mode, --node is required
if [ "$MODE" = "query" ] && [ -z "$NODE" ]; then
  echo "ERROR: --node is required for fetching logs" >&2
  echo "Use --list-nodes to see available nodes, or --help for usage." >&2
  exit 1
fi

# =============================================================================
# COMMON ARGS
# =============================================================================
COMMON_ARGS=(--addr="$ADDR" --org-id="$ORG_ID")

# =============================================================================
# LIST MODES
# =============================================================================
if [ "$MODE" != "query" ]; then
  # If --node or --chain provided, use "logcli series" + extract unique values
  # Otherwise, use "logcli labels" (faster, no filter needed)
  HAS_FILTER=false
  LIST_QUERY_PARTS=()
  [ -n "$NODE" ]  && { LIST_QUERY_PARTS+=("node=~\"${NODE}\""); HAS_FILTER=true; }
  [ -n "$CHAIN" ] && { LIST_QUERY_PARTS+=("chain=\"${CHAIN}\""); HAS_FILTER=true; }

  case "$MODE" in
    list-labels)
      echo "=== Listing labels (ORG_ID=$ORG_ID) ==="
      logcli labels "${COMMON_ARGS[@]}"
      exit $?
      ;;
    list-nodes)
      echo "=== Listing nodes (ORG_ID=$ORG_ID) ==="
      if [ "$HAS_FILTER" = true ]; then
        SERIES_Q="{$(IFS=', '; echo "${LIST_QUERY_PARTS[*]}")}"
        logcli series "${COMMON_ARGS[@]}" "$SERIES_Q" \
          | grep -oP 'node="[^"]*"' | sed 's/node="//;s/"//' | sort -u
      else
        logcli labels node "${COMMON_ARGS[@]}"
      fi
      exit $?
      ;;
    list-chains)
      echo "=== Listing chains (ORG_ID=$ORG_ID) ==="
      if [ "$HAS_FILTER" = true ]; then
        SERIES_Q="{$(IFS=', '; echo "${LIST_QUERY_PARTS[*]}")}"
        logcli series "${COMMON_ARGS[@]}" "$SERIES_Q" \
          | grep -oP 'chain="[^"]*"' | sed 's/chain="//;s/"//' | sort -u
      else
        logcli labels chain "${COMMON_ARGS[@]}"
      fi
      exit $?
      ;;
  esac
fi

# =============================================================================
# BUILD QUERY
# =============================================================================
if [ -n "$CHAIN" ]; then
  Q="{node=~\"${NODE}\", chain=\"${CHAIN}\"}"
else
  Q="{node=~\"${NODE}\"}"
fi

if [ -n "$FILTER" ]; then
  Q="${Q} |~ \`${FILTER}\`"
fi

# =============================================================================
# BUILD TIME ARGS
# =============================================================================
TIME_ARGS=()
if [ -n "$FROM" ]; then
  TIME_ARGS+=(--from="$FROM" --to="$TO")
else
  TIME_ARGS+=(--since="$SINCE")
fi

# =============================================================================
# EXECUTE
# =============================================================================
echo "=== Config: TSH_APP=$TSH_APP  ORG_ID=$ORG_ID ==="
echo "=== Query: $Q ==="
echo "=== Make sure you ran: tsh proxy app $TSH_APP --port 10700 ==="

logcli query \
  "${COMMON_ARGS[@]}" \
  --timezone=UTC \
  "$Q" \
  --batch 5000 \
  --limit "$LIMIT" \
  --forward \
  --output=raw \
  "${TIME_ARGS[@]}"
