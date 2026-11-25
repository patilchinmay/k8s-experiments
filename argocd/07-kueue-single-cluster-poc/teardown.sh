#!/usr/bin/env bash
# teardown.sh
# Deletes the Kind cluster created by setup.sh.

set -euo pipefail

kind delete cluster --name kueue-poc
