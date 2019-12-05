#!/bin/bash -ex
# bash needed for 'wait -n'

# Return kubectl args to forward a port
# $1: pod
# $2: port, same is used for external and internal
kubectl_forwarding_args()
{
    printf "port-forward %s --address 0.0.0.0 %s:%s" "$1" "$2" "$2"
}

/snap/bin/microk8s.start
/snap/bin/microk8s.status --wait-ready

pods=$(/snap/bin/kubectl get pods | cut -f1 -d' ')
mngm_pod=$(printf "%s\n" "$pods" | grep ^management-)
ident_pod=$(printf "%s\n" "$pods" | grep ^identity-)
mqtt_pod=$(printf "%s\n" "$pods" | grep ^mqtt-)

ports=(8010 8030 8883)
pods=("$mngm_pod" "$ident_pod" "$mqtt_pod")

# Kill old forwarders if present - we need to own the processes
# for 'wait' to work
i=0
for port in "${ports[@]}"; do
    signature=$(kubectl_forwarding_args "${pods[$i]}" "$port")
    pkill -f -- "$signature" || true
    i=$((i + 1))
done

while true; do
    # Create forwarders as needed
    i=0
    for port in "${ports[@]}"; do
        signature=$(kubectl_forwarding_args "${pods[$i]}" "$port")
        if ! pgrep -f -- "$signature" &> /dev/null; then
            printf "not present for port: %s\n" "$port"
            # shellcheck disable=SC2086
            /snap/bin/kubectl $signature &
        fi
        i=$((i + 1))
    done

    # Wait until a forwarder has died
    wait -n || true
done
