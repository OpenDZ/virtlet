#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

opts=
if [[ ${1:-} = "console" ]]; then
  # using -it with `virsh list` causes it to use \r\n as line endings,
  # which makes it less useful
  opts="-it"
fi
args=("$@")

function get_pod_domain_id {
  # @pod[:namespace]
  if [[ ! ( ${1} =~ ^@([^:]+)(:(.*))?$ ) ]]; then
    echo "bad podspec ${1}" >&2
    exit 1
  fi

  local pod_name="${BASH_REMATCH[1]}"
  local namespace="${BASH_REMATCH[3]}"
  local namespace_opts=""
  if [[ ${namespace} ]]; then
      namespace_opts="-n ${namespace}"
  fi
  kubectl get pod ${namespace_opts} "${pod_name}" \
          -o 'jsonpath={.status.containerStatuses[0].containerID}-{.status.containerStatuses[0].name}'|sed 's/.*__//'
}

if [[ ${1:-} = "poddomain" ]]; then
  if [[ $# != 2 ]]; then
    echo "poddomain command requires @podname[:namespace]" >&2
    exit 1
  fi
  get_pod_domain_id "${2}"
  exit 0
fi

for ((n=0; n < ${#args[@]}; n++)); do
  if [[ ${args[${n}]} =~ ^@ ]]; then
    args[${n}]="$(get_pod_domain_id "${args[${n}]}")"
  fi
done

pod=$(kubectl get pods -n kube-system -l runtime=virtlet -o name|head -1|sed 's@.*/@@')
kubectl exec ${opts} -n kube-system "${pod}" -c virtlet -- virsh ${args[@]+"${args[@]}"}
