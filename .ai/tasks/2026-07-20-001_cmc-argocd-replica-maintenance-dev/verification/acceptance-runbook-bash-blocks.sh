ACC_API='https://api.eneco-vpp-acc.ceap.nl:6443'
ACC_NS='eneco-vpp-argocd'
ACC_ARGOCD='eneco-vpp'

acc_bind() {
  ACC_CONTEXT="$(oc config current-context)" || return 1
  ACC_ACTUAL_API="$(oc --context "$ACC_CONTEXT" whoami --show-server)" || return 1
  if [ "$ACC_ACTUAL_API" != "$ACC_API" ]; then
    echo "STOP: expected ACC API $ACC_API but got $ACC_ACTUAL_API" >&2
    return 1
  fi
  export ACC_CONTEXT ACC_API ACC_NS ACC_ARGOCD
}

acc_oc() {
  oc --context "$ACC_CONTEXT" "$@"
}

acc_guard() {
  [ "$(acc_oc whoami --show-server)" = "$ACC_API" ] || {
    echo 'STOP: pinned context no longer resolves to ACC' >&2
    return 1
  }
}

acc_bind && acc_guard

acc_guard && acc_oc get namespace "$ACC_NS" \
  -o custom-columns='NAME:.metadata.name,UID:.metadata.uid,CREATED:.metadata.creationTimestamp'

acc_guard && acc_oc -n "$ACC_NS" get argocd "$ACC_ARGOCD" \
  -o custom-columns='NAME:.metadata.name,UID:.metadata.uid,GENERATION:.metadata.generation,PHASE:.status.phase'

acc_guard && acc_oc -n "$ACC_NS" get argocd "$ACC_ARGOCD" -o yaml
acc_guard && acc_oc -n "$ACC_NS" get hpa

acc_guard && acc_oc -n "$ACC_NS" get deployment \
  -o custom-columns='NAME:.metadata.name,GEN:.metadata.generation,OBS:.status.observedGeneration,DES:.spec.replicas,CUR:.status.replicas,UPD:.status.updatedReplicas,RDY:.status.readyReplicas,AVL:.status.availableReplicas,UNAVL:.status.unavailableReplicas'

acc_guard && acc_oc -n "$ACC_NS" get statefulset \
  -o custom-columns='NAME:.metadata.name,GEN:.metadata.generation,OBS:.status.observedGeneration,DES:.spec.replicas,CUR:.status.currentReplicas,UPD:.status.updatedReplicas,RDY:.status.readyReplicas,CREV:.status.currentRevision,UREV:.status.updateRevision'

acc_guard && acc_oc -n "$ACC_NS" get pods -o custom-columns='NAME:.metadata.name,UID:.metadata.uid,CREATED:.metadata.creationTimestamp,READY:.status.containerStatuses[*].ready,RESTARTS:.status.containerStatuses[*].restartCount,LAST_REASON:.status.containerStatuses[*].lastState.terminated.reason,NODE:.spec.nodeName,HASH:.metadata.labels.pod-template-hash,REV:.metadata.labels.controller-revision-hash'

acc_guard && acc_oc -n "$ACC_NS" get service -o wide
acc_guard && acc_oc -n "$ACC_NS" get endpointslices.discovery.k8s.io -o wide
acc_guard && acc_oc -n "$ACC_NS" get applications.argoproj.io \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,RECONCILED:.status.reconciledAt'
acc_guard && acc_oc -n "$ACC_NS" get events --sort-by=.lastTimestamp
acc_guard && acc_oc adm top pods -n "$ACC_NS" --containers
acc_guard && acc_oc adm top nodes

acc_fast_sample() {
  ACC_CAPTURE_ID="ACC-LIVE-$(date +%Y%m%d-%H%M%S)"
  ACC_SAMPLE_START="$(date +%s)"
  echo "CAPTURE=$ACC_CAPTURE_ID START=$(date -Iseconds)"

  acc_guard || { echo 'SAMPLE_FAILED identity'; return 1; }

  acc_oc -n "$ACC_NS" get deployment --request-timeout=10s \
    -o custom-columns='NAME:.metadata.name,GEN:.metadata.generation,OBS:.status.observedGeneration,DES:.spec.replicas,CUR:.status.replicas,UPD:.status.updatedReplicas,RDY:.status.readyReplicas,AVL:.status.availableReplicas,UNAVL:.status.unavailableReplicas' || return 1

  acc_oc -n "$ACC_NS" get statefulset --request-timeout=10s \
    -o custom-columns='NAME:.metadata.name,GEN:.metadata.generation,OBS:.status.observedGeneration,DES:.spec.replicas,CUR:.status.currentReplicas,UPD:.status.updatedReplicas,RDY:.status.readyReplicas,CREV:.status.currentRevision,UREV:.status.updateRevision' || return 1

  acc_oc -n "$ACC_NS" get pods --request-timeout=10s \
    -o custom-columns='NAME:.metadata.name,UID:.metadata.uid,CREATED:.metadata.creationTimestamp,READY:.status.containerStatuses[*].ready,RESTARTS:.status.containerStatuses[*].restartCount,NODE:.spec.nodeName,HASH:.metadata.labels.pod-template-hash,REV:.metadata.labels.controller-revision-hash' || return 1

  acc_oc -n "$ACC_NS" get endpointslices.discovery.k8s.io --request-timeout=10s -o wide || return 1
  acc_oc -n "$ACC_NS" get applications.argoproj.io --request-timeout=10s \
    -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,RECONCILED:.status.reconciledAt' || return 1
  acc_oc -n "$ACC_NS" get events --request-timeout=10s --sort-by=.lastTimestamp || return 1

  ACC_SAMPLE_END="$(date +%s)"
  echo "CAPTURE=$ACC_CAPTURE_ID END=$(date -Iseconds) DURATION_SECONDS=$((ACC_SAMPLE_END-ACC_SAMPLE_START))"
}

acc_slow_sample() {
  echo "SLOW_SAMPLE_START=$(date -Iseconds)"
  acc_guard || return 1
  acc_oc adm top pods -n "$ACC_NS" --containers || return 1
  acc_oc adm top nodes || return 1
  echo "SLOW_SAMPLE_END=$(date -Iseconds)"
}

acc_guard && acc_oc get --raw "/apis/metrics.k8s.io/v1beta1/namespaces/$ACC_NS/pods"

acc_guard && acc_oc describe node NODE_NAME
acc_guard && acc_oc get pods -A --field-selector spec.nodeName=NODE_NAME \
  -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,CPU_REQ:.spec.containers[*].resources.requests.cpu,MEM_REQ:.spec.containers[*].resources.requests.memory'

