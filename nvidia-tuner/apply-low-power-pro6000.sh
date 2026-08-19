#!/usr/bin/env bash
# UNVALIDATED starting point for RTX PRO 6000 — no data on this card yet.
# Test stability (incl. workload output correctness — this card has ECC
# memory) before relying on it. Lower the memory offset in -250 steps if
# unstable.
#
# 300 W is comfortably within the confirmed board range (150-600 W, read via
# nvidia-smi --query-gpu=power.min_limit,power.max_limit on a Workstation
# Edition card), so no driver-side rejection is expected. The core/memory
# offsets are still untested — the clock offsets, not the wattage, are the
# unvalidated part of this profile.
set -euo pipefail

if ! command -v nvidia-tuner &>/dev/null; then
    echo "ERROR: nvidia-tuner not found in PATH" >&2
    echo "Install it first, then rerun this script." >&2
    exit 1
fi

PROFILE_NAME="low-power"
PROFILE_CORE_OFFSET=-75
PROFILE_MEMORY_OFFSET=1000
PROFILE_POWER_LIMIT=300

echo "Applying nvidia-tuner ${PROFILE_NAME} profile (RTX PRO 6000, unvalidated): core ${PROFILE_CORE_OFFSET}, memory ${PROFILE_MEMORY_OFFSET}, power ${PROFILE_POWER_LIMIT}W"
nvidia-tuner \
    --core-clock-offset "$PROFILE_CORE_OFFSET" \
    --memory-clock-offset "$PROFILE_MEMORY_OFFSET" \
    --power-limit "$PROFILE_POWER_LIMIT"
