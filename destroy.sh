#!/bin/bash

CLUSTER_NAME='vagrant.k8s.local'
USER_NAME='vagrant'
USER_CERT_FILE="${USER_NAME}.pem"
USER_CERT_KEY="${USER_NAME}-key.pem"
KUBE_CONTEXT='vagrant-cluster'

main() {
    vagrant destroy -f
    current_context=$(kubectl config current-context)
    if [[ "${current_context}" == "${KUBE_CONTEXT}" ]]; then
        kubectl config unset current-context
    fi
    kubectl config unset users.${USER_NAME}
    kubectl config delete-context ${KUBE_CONTEXT}
    kubectl config delete-cluster ${CLUSTER_NAME}
    [[ -f ${USER_CERT_FILE} ]] && rm -f ${USER_CERT_FILE}
    [[ -f ${USER_CERT_KEY} ]] && rm -f ${USER_CERT_KEY}
}

main
