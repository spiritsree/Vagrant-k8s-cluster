#!/usr/bin/env bash

KUBE_CONFIG="kube_config.yaml"
CLUSTER_NAME='vagrant.k8s.local'
USER_NAME='vagrant'
CA_CERT_FILE='ca.pem'
USER_CERT_FILE="${USER_NAME}.pem"
USER_CERT_KEY="${USER_NAME}-key.pem"
KUBE_CONTEXT='vagrant-cluster'
NETWORKING_MODEL='flannel'
NODE=2
SCRIPT_NAME="$( basename "${BASH_SOURCE[0]}" )"
RED='\033[0;31m'      # Red
NC='\033[0m'          # Color Reset

# Usage help
_usage() {
    if [[ ! -z $@ ]]; then
        size=`echo $@ | wc -c`
        length=$((${size} + 7 + 5))
        printf "#%.0s" {1..${length}}
        echo -e "\n# ${RED}ERROR:${NC} $@"
        printf '#%.0s' {1..${length}}
        echo
    fi
    echo 'Kubernetes cluster setup on vagrant.'
    echo
    echo 'Usage:'
    echo "    ${SCRIPT_NAME} [-h|--help] [-n|--networking <flannel|calico|canal|weavenet>] [-c|--host-count <n>]"
    echo
    echo 'Arguments:'
    echo '    -h|--help                                             Print usage'
    echo '    -n|--networking <flannel|calico|canal|weavenet>       Kubernetes networking model to use [Default: flannel]'
    echo '    -c|--host-count <n>                                   Number of worker nodes [Default: 2]'
    echo
    echo 'Examples:'
    echo "    ${SCRIPT_NAME}"
    echo "    ${SCRIPT_NAME} -n calico"
    echo "    ${SCRIPT_NAME} -n calico -c 3"
    echo
}

# Get Options
_getOptions() {
    optspec=":hn:c:-:"
    while getopts "$optspec" opt; do
        case $opt in
            -)
                case "${OPTARG}" in
                    networking)
                        NETWORKING="${!OPTIND}"; OPTIND=$(( OPTIND + 1 ))
                        if [[ -z "${NETWORKING}" ]]; then
                            _usage "Need to specify an networking model from <flannel|canal|calico|weavenet>"
                            exit 1
                        elif [[ "${NETWORKING}" == "flannel" ]] || [[ "${NETWORKING}" = "calico" ]] || [[ "${NETWORKING}" == "canal" ]] || [[ "${NETWORKING}" == "weavenet" ]]; then
                            NETWORKING_MODEL="${NETWORKING}"
                        else
                            _usage  "Need to specify an networking model from <flannel|canal|calico|weavenet>"
                            exit 1
                        fi
                        ;;
                    host-count)
                        re='^[1-5]$'
                        NODE="${!OPTIND}"; OPTIND=$(( OPTIND + 1 ))
                        if [[ -z "${NODE}" ]] || [[ ! ${NODE} =~ ${re} ]]; then
                            _usage "Need to specify a valid node count from 1-5"
                            exit 1
                        fi
                        ;;
                    help)
                        _usage
                        exit 0
                        ;;
                    *)
                        if [[ "$OPTERR" = 1 ]] && [[ "${optspec:0:1}" != ":" ]]; then
                            _usage "Unknown option --${OPTARG}"
                            exit 1
                        fi
                        ;;
                esac;;
            h)
                _usage
                exit 0
                ;;
            n)
                NETWORKING="${OPTARG}"
                if [[ -z "${NETWORKING}" ]]; then
                    _usage "Need to specify an networking mode from <flannel|canal|calico|weavenet>"
                    exit 1
                elif [[ "${NETWORKING}" == "flannel" ]] || [[ "${NETWORKING}" = "calico" ]] || [[ "${NETWORKING}" == "canal" ]] || [[ "${NETWORKING}" == "weavenet" ]]; then
                    NETWORKING_MODEL="${NETWORKING}"
                else
                    _usage  "Need to specify an networking mode from <flannel|canal|calico|weavenet>"
                    exit 1
                fi
                ;;
            c)
                re='^[1-5]$'
                NODE="${OPTARG}"
                if [[ -z "${NODE}" ]] || [[ ! ${NODE} =~ ${re} ]]; then
                    _usage "Need to specify a valid node count from 1-5"
                    exit 1
                fi
                ;;
            \?)
                _usage "Invalid option: -$OPTARG"
                exit 1
                ;;
            :)
                _usage "Option -$OPTARG requires an argument."
                exit 1
                ;;
        esac
    done
}

_cleanup() {
    if [[ $? -eq 1 ]]; then
        rm -r ${KUBE_CONFIG} ${CA_CERT_FILE} ${USER_CERT_FILE} ${USER_CERT_KEY}
    else
        rm -r ${KUBE_CONFIG} ${CA_CERT_FILE}
    fi
}

main() {
    _getOptions $@
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

    # Updating the Vagrantfile
    sed -i '' "s/WORKER_COUNT = nil/WORKER_COUNT = ${NODE}/g" Vagrantfile
    sed -i '' "s/NETWORKING_TYPE = nil/NETWORKING_TYPE = \"${NETWORKING_MODEL}\"/g" Vagrantfile

    # Deploy the cluster
    echo "Deploying the Kubernetes cluster with ${NODE} worker nodes and ${NETWORKING_MODEL} networking..."
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

main $@


