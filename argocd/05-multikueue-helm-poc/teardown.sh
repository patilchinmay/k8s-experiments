#!/usr/bin/env bash
# teardown.sh — delete all 4 Kind clusters created by setup.sh
set -euo pipefail
kind delete cluster --name kueue-mgmt
kind delete cluster --name kueue-worker-1
kind delete cluster --name kueue-worker-2
kind delete cluster --name kueue-worker-3
