#!/usr/bin/env bash
# teardown.sh — deletes all 4 Kind clusters

set -euo pipefail

for name in kueue-mgmt kueue-worker-1 kueue-worker-2 kueue-worker-3; do
  echo "==> Deleting cluster: ${name}..."
  kind delete cluster --name "${name}" || true
done

echo ""
echo "✅ All clusters deleted."
