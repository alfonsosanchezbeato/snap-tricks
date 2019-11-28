#!/bin/bash -ex
# bash needed for 'wait -n'

pods=$(kubectl get pods | cut -f1 -d' ')
mngm_pod=$(echo "$pods" | grep ^management-)
ident_pod=$(echo "$pods" | grep ^identity-)
mqtt_pod=$(echo "$pods" | grep ^mqtt-)

microk8s.start
microk8s.status --wait-ready

ports=(8010 8030 8883)
pods=("$mngm_pod" "$ident_pod" "$mqtt_pod")

# Kill old forwarders if present - we need to own the processes
# for 'wait' to work
i=0
for port in "${ports[@]}"; do
    signature="port-forward ${pods[$i]} --address 0.0.0.0 $port:$port"
    pkill -f -- "$signature" || true
    i=$((i + 1))
done

while true; do
    # Create forwarders as needed
    i=0
    for port in "${ports[@]}"; do
        signature="port-forward ${pods[$i]} --address 0.0.0.0 $port:$port"
        if ! pgrep -f -- "$signature" &> /dev/null; then
            printf "not present for port: %s\n" "$port"
            # shellcheck disable=SC2086
            kubectl $signature &
        fi
        i=$((i + 1))
    done

    # Wait until a forwarder has died
    wait -n || true
done
