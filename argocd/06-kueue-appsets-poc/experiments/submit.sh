#!/usr/bin/env bash
# Submit N single-pod Jobs (500m CPU / 512Mi each) to a team's LocalQueue.
#
# Usage: submit.sh <team-a|team-b> <count> [priority-class] [sleep-seconds]
#   priority-class: p0-realtime | p1-urgent | p2-research | p3-batch (default p2-research)
#
# Example: ./submit.sh team-a 6 p3-batch 900
set -euo pipefail

NS="${1:?namespace (team-a|team-b)}"
COUNT="${2:?count}"
PRIO="${3:-p2-research}"
SLEEP="${4:-900}"
CTX="${CTX:-kind-kueue-wl-1}"

for _ in $(seq 1 "${COUNT}"); do
  kubectl create --context "${CTX}" -f - <<YAML
apiVersion: batch/v1
kind: Job
metadata:
  generateName: ${NS}-${PRIO}-
  namespace: ${NS}
  labels:
    kueue.x-k8s.io/queue-name: ${NS}-lq
    kueue.x-k8s.io/priority-class: ${PRIO}
spec:
  parallelism: 1
  completions: 1
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: sleeper
          image: busybox:1.36
          command: ["sleep", "${SLEEP}"]
          resources:
            requests:
              cpu: 500m
              memory: 512Mi
            limits:
              cpu: 500m
              memory: 512Mi
YAML
done
