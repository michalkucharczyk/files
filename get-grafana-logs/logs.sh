#!/bin/bash -x

# =============================================================================
# Generic Grafana/Loki log fetcher
# =============================================================================
#
# STEP 0: Run the tsh proxy first (see TSH_APP below):
#   tsh login --proxy=teleport.parity.io:443
#   tsh proxy app <TSH_APP> --port 10700
#
# STEP 1: Uncomment ONE configuration preset below (or define custom)
# STEP 2: Uncomment ONE filter pattern (or leave empty for all logs)
# STEP 3: Adjust time range at the bottom (--since or --from/--to)
# =============================================================================

# =============================================================================
# CONFIGURATION PRESETS
# Uncomment ONE block. Each sets: TSH_APP, ORG_ID, Q (node/chain selector)
# =============================================================================

# --- Asset Hub Polkadot (collator) ---
# TSH_APP=loki  # tsh proxy app loki --port 10700
# ORG_ID='parity-hosted-mainnet'
# Q='{node=~"polkadot-parachain-asset-hub-collator-node-0", chain="asset-hub-polkadot"}'

# --- Asset Hub Polkadot (rpc) ---
# TSH_APP=loki
# ORG_ID='parity-hosted-mainnet'
# Q='{node=~"polkadot-asset-hub-rpc-scw-node-0", chain="asset-hub-polkadot"}'

# --- Asset Hub Kusama ---
# TSH_APP=loki
# ORG_ID='parity-hosted-mainnet'
# Q='{node=~"kusama-parachain-asset-hub-collator-node-0", chain="asset-hub-kusama"}'

# --- Asset Hub Westend (testnet) ---
# TSH_APP=loki
# ORG_ID='parity-hosted-testnet'
# Q='{node=~"westend-asset-hub-rpc-scw-node-0"}'

# --- Asset Hub Paseo ---
TSH_APP=loki
ORG_ID='chain-paseo'
Q='{chain="asset-hub-paseo", node="paseo-asset-hub-rpc-node-0"}'

# --- Kusama validator ---
# TSH_APP=loki
# ORG_ID='parity-hosted-mainnet'
# Q='{node=~"kusama-validator-waw1-1"}'
## other kusama validators:
## Q='{node=~"kusama-validator-bhs5-0"}'

# --- Polkadot Asset Hub via versi-loki (logs2.sh style) ---
# TSH_APP=versi-loki
# ORG_ID='parity-hosted-mainnet'
# Q='{node=~"polkadot-parachain-asset-hub-collator-node-1", chain="asset-hub-polkadot"}'

# --- Versi (BROKEN - may need different tsh app or org-id, see notes) ---
# TSH_APP=versi-loki  # or maybe: loki-versi ?
# ORG_ID='parity-hosted-testnet'  # might be wrong - try other org-ids
# Q='{node=~"node-0"}'

# =============================================================================
# FILTER PATTERN (uncomment ONE, or leave FILTER empty for unfiltered)
# =============================================================================
FILTER=''
# FILTER=' |~ `Imported #`'
# FILTER=' |~ `txpool|Imported #`'
# FILTER=' |~ `Parachain.*maintain`'
# FILTER=' |~ `txpool`'
# FILTER=' |~ `proposing`'
# FILTER=' |~ `maintain|Prepared block for proposing at|Imported`'
# FILTER=' |~ `Timeout|maintain`'
# FILTER=' |~ `failed|Failed|error|panic|Panic`'
# FILTER=' |~ `Timeout|maintain|Imported #|Prepared block for proposing at|INFO.*txpool`'
# FILTER=' |~ `Imported #|maintain|extrinsics_count|Starting consensus session|txpool|included=`'
# FILTER=' |~ `extrinsics_count`'
# FILTER=' |~ `deadline|maintain`'
# FILTER=' |~ `Invalid transaction:`'
# FILTER=' |~ `validate_transaction_blocking`'

# =============================================================================
# SANITY CHECK
# =============================================================================
if [ -z "$ORG_ID" ] || [ -z "$Q" ]; then
  echo "ERROR: No configuration selected. Uncomment one preset above."
  echo ""
  echo "Available presets:"
  grep -E '^\s*# ---' "$0"
  exit 1
fi

echo "=== Config: TSH_APP=$TSH_APP  ORG_ID=$ORG_ID ==="
echo "=== Make sure you ran: tsh proxy app $TSH_APP --port 10700 ==="

# =============================================================================
# QUERY
# =============================================================================
Q="${Q}${FILTER}"

# LIMIT=1000000
LIMIT=50000000  # use higher limit for kusama validators

logcli query \
  --addr=http://127.0.0.1:10700 \
  --org-id="$ORG_ID" \
  --timezone=UTC \
  "$Q" \
  --batch 5000 \
  --limit "$LIMIT" \
  --forward \
  --output=raw \
  --since=24h

  # --from=2026-02-20T11:15:00.00Z \
  # --to=2026-02-24T11:15:00.00Z

  # --from=2026-02-08T18:30:00.00Z \
  # --to=2026-02-08T19:00:00.00Z
  # --- Time range alternatives (uncomment one, remove --since above) ---
  # --since=5m
  # --since=20m
  # --since=2h
  # --since=48h
  # --from=2025-12-16T01:50:00Z \
  # --to=2025-12-16T02:10:00Z
