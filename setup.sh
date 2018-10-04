#!/bin/bash

KUBE_CONFIG="kube_config.yaml"
CLUSTER_NAME='vagrant.k8s.local'
USER_NAME='vagrant'
CA_CERT_FILE='ca.pem'
USER_CERT_FILE="${USER_NAME}.pem"
USER_CERT_KEY="${USER_NAME}-key.pem"
KUBE_CONTEXT='vagrant-cluster'

_cleanup() {
    if [[ $? -eq 1 ]]; then
        rm -r ${KUBE_CONFIG} ${CA_CERT_FILE} ${USER_CERT_FILE} ${USER_CERT_KEY}
    else
        rm -r ${KUBE_CONFIG} ${CA_CERT_FILE}
    fi
}

main() {
    yq_bin=$(which yq)
    vagrant_bin=$(which vagrant)
    if [[ -z ${yq_bin} ]]; then
        echo 'Needs yq...'
        echo 'Install using "brew install yq"'
        exit 1
    elif [[ -z ${vagrant_bin} ]]; then
        echo 'Needs vagrant...'
        echo 'Install using "brew cask install vagrant"'
        exit 1
    fi

    # Deploy the cluster
    echo 'Deploying the Kubernetes cluster...'
    vagrant up
    trap _cleanup EXIT
    nc master.local 8888 > ${KUBE_CONFIG}
    cluster_server=$(${yq_bin} read ${KUBE_CONFIG} clusters[0].cluster.server)
    ${yq_bin} read ${KUBE_CONFIG} clusters[0].cluster.certificate-authority-data | base64 -D > ${CA_CERT_FILE}
    ${yq_bin} read ${KUBE_CONFIG} users[0].user.client-certificate-data | base64 -D > ${USER_CERT_FILE}
    ${yq_bin} read ${KUBE_CONFIG} users[0].user.client-key-data | base64 -D > ${USER_CERT_KEY}
    if [[ -z ${cluster_server} ]] || [[ ! -s ${CA_CERT_FILE} ]] || [[ ! -s ${USER_CERT_FILE} ]] || [[ ! -s ${USER_CERT_KEY} ]]; then
        echo 'Either Certs or the Cluster server is empty.'
        exit 1
    else
        kubectl config set-cluster "${CLUSTER_NAME}" --certificate-authority=ca.pem --embed-certs=true --server="${cluster_server}"
        kubectl config set-credentials "${USER_NAME}" --client-certificate="${USER_CERT_FILE}" --client-key="${USER_CERT_KEY}"
        kubectl config set-context "${KUBE_CONTEXT}" --cluster="${CLUSTER_NAME}" --user="${USER_NAME}"
        kubectl config use-context "${KUBE_CONTEXT}"
    fi
    echo 'For helm based deployments please install helm client...'
    echo 'Follow instructions https://docs.helm.sh/install/'
    exit 0
}

main

