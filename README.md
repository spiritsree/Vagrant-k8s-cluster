# Vagrant-k8s-cluster

This installs a test Kubernetes cluster in [vagrant](http://vagrantup.com/) using [virtualbox](https://www.virtualbox.org/) hosts..

## Requirements

* [Vagrant](http://vagrantup.com/)
* [Virtualbox](https://www.virtualbox.org/)
* [yq](http://mikefarah.github.io/yq/)
* [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

## Setup

You can setup the cluster and kubectl context using the `setup.sh` script. This configures 1 Master node and 3 Worker nodes. You can change the number of worker nodes in `Vagrantfile` by updating the value of `NODE_COUNT`.

```
$ ./setup.sh -h
Kubernetes cluster setup on vagrant.

Usage:
    setup.sh [-h|--help] [-n|--networking <flannel|calico|canal|weavenet>] [-c|--host-count <n>]

Arguments:
    -h|--help                                             Print usage
    -n|--networking <flannel|calico|canal|weavenet>       Kubernetes networking model to use [Default: flannel]
    -c|--host-count <n>                                   Number of worker nodes [Default: 2]

Examples:
    ./setup.sh
    ./setup.sh -n calico
    ./setup.sh -n weavenet -c 3

```

## Destroy

You can destroy the cluster and kubectl config using `destroy.sh` script.

```
$ sh destroy.sh
```

## Supported Networking

1. [flannel](https://github.com/coreos/flannel) (Default)
1. [calico](https://www.projectcalico.org/)
1. [canal](https://github.com/projectcalico/canal)
1. [weavenet](https://www.weave.works/oss/net/)

## Other Networking

1. [AWS-VPC-CNI](https://github.com/aws/amazon-vpc-cni-k8s)
1. [Cilium](https://github.com/cilium/cilium)
1. [..and more](https://kubernetes.io/docs/concepts/cluster-administration/networking/)

## Reference

1. [Critool](https://github.com/kubernetes-sigs/cri-tools)
1. [Helm](https://github.com/helm/helm)
1. [Kubeadm install](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
1. [Kubernetes](https://github.com/kubernetes/kubernetes)
1. [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
1. [MetalLB](https://github.com/metallb/metallb)

## Troubleshooting

1. If you see an error as below while running the setup

```
There was an error while executing `VBoxManage`, a CLI used by Vagrant
for controlling VirtualBox. The command and stderr is shown below.

Command: ["hostonlyif", "create"]

Stderr: 0%...
Progress state: NS_ERROR_FAILURE
```

Do a reinstall of Virtualbox and allow `Oracle` from System Preferences > Security & Privacy

## Versions

Tested with below versions of the apps

* Vagrant 2.2.17
* VirtualBox 6.1.22
* yq 4.6.1
