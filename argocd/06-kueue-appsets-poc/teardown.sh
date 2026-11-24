#!/usr/bin/env bash
# teardown.sh: delete both Kind clusters created by setup.sh
set -euo pipefail
kind delete cluster --name kueue-hub
kind delete cluster --name kueue-wl-1
