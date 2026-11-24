#!/usr/bin/env bash
# teardown.sh: delete both Kind clusters created by setup.sh
set -euo pipefail
kind delete cluster --name kueue-manager
kind delete cluster --name kueue-worker-1
