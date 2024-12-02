#!/bin/bash
# from https://www.elastic.co/guide/en/cloud-on-k8s/master/k8s-virtual-memory.html#k8s_using_a_daemonset_to_set_virtual_memory
source ./common_vars.env
source ./common.sh

check_inst_arg
load_inst_env
get_project_id
get_gsa_email

cat <<EOF | kubectl apply -n $INST -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: max-map-count-setter
  labels:
    k8s-app: max-map-count-setter
spec:
  selector:
    matchLabels:
      name: max-map-count-setter
  template:
    metadata:
      labels:
        name: max-map-count-setter
    spec:
      initContainers:
        - name: max-map-count-setter
          image: docker.io/bash:5.2.21
          resources:
            limits:
              cpu: 100m
              memory: 32Mi
          securityContext:
            privileged: true
            runAsUser: 0
          command: ['/usr/local/bin/bash', '-e', '-c', 'echo 262144 > /proc/sys/vm/max_map_count']
      containers:
        - name: sleep
          image: docker.io/bash:5.2.21
          command: ['sleep', 'infinity']
EOF