#!/usr/bin/env bash
# UNVALIDATED starting point for RTX PRO 6000 — no data on this card yet.
# Test stability (incl. workload output correctness — this card has ECC
# memory) before relying on it. Lower the memory offset in -250 steps if
# unstable.
set -euo pipefail

if ! command -v nvidia-tuner &>/dev/null; then
    echo "ERROR: nvidia-tuner not found in PATH" >&2
    echo "Install it first, then rerun this script." >&2
    exit 1
fi

PROFILE_NAME="efficient"
PROFILE_CORE_OFFSET=-75
PROFILE_MEMORY_OFFSET=1000
PROFILE_POWER_LIMIT=450

echo "Applying nvidia-tuner ${PROFILE_NAME} profile (RTX PRO 6000, unvalidated): core ${PROFILE_CORE_OFFSET}, memory ${PROFILE_MEMORY_OFFSET}, power ${PROFILE_POWER_LIMIT}W"
nvidia-tuner \
    --core-clock-offset "$PROFILE_CORE_OFFSET" \
    --memory-clock-offset "$PROFILE_MEMORY_OFFSET" \
    --power-limit "$PROFILE_POWER_LIMIT"
