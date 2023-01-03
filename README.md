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

1. [flannel](https://github.com/flannel-io/flannel) (Default)
1. [calico](https://github.com/projectcalico/calico)
1. [canal](https://projectcalico.docs.tigera.io/getting-started/kubernetes/flannel/flannel)
1. [weavenet](https://www.weave.works/oss/net/)

## Other Networking

1. [AWS-VPC-CNI](https://github.com/aws/amazon-vpc-cni-k8s)
1. [Cilium](https://github.com/cilium/cilium)
1. [..and more](https://kubernetes.io/docs/concepts/cluster-administration/networking/)

## Container Runtimes

1. [Container Runtimes](https://kubernetes.io/docs/setup/production-environment/container-runtimes/)
1. [Containerd](https://github.com/containerd/containerd)
1. [CRI-O](https://github.com/cri-o/cri-o)

## Installations

1. [Calico](https://projectcalico.docs.tigera.io/getting-started/kubernetes/self-managed-onprem/onpremises)
1. [Containerd](https://github.com/containerd/containerd/blob/main/docs/cri/installation.md)
1. [CRI-O](https://github.com/cri-o/cri-o/blob/main/install.md)
1. [Critool](https://github.com/kubernetes-sigs/cri-tools#install)
1. [Kubernetes install using Kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
1. [MetalLB](https://metallb.universe.tf/installation/)

## Releases

1. [Calico](https://github.com/projectcalico/calico/releases)
1. [Containerd](https://github.com/containerd/containerd/blob/main/RELEASES.md)
1. [Containerd](https://containerd.io/releases/)
1. [CRIO](https://github.com/cri-o/cri-o/releases)
1. [Critool](https://github.com/kubernetes-sigs/cri-tools/releases)
1. [Kubernetes](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/README.md)
1. [MetalLB](https://metallb.universe.tf/release-notes/)
1. [Metrics Server](https://github.com/kubernetes-sigs/metrics-server/releases)
1. [TOML CLI](https://github.com/gnprice/toml-cli/releases)

## Reference

1. [Calico Networking](https://www.tigera.io/tigera-products/calico/)
1. [Critool](https://github.com/kubernetes-sigs/cri-tools)
1. [Helm](https://github.com/helm/helm)
1. [Kubernetes](https://github.com/kubernetes/kubernetes)
1. [MetalLB](https://github.com/metallb/metallb)
1. [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
1. [Vagrant](https://www.vagrantup.com)
1. [Vagrant Install](https://developer.hashicorp.com/vagrant/downloads)
1. [VirtualBox](https://www.virtualbox.org/wiki/Changelog)

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

2. Using Virtualbox 6.1.28 onwards need more configuration for host-only network. Details [here](https://www.virtualbox.org/manual/ch06.html#network_hostonly) also the [Changelog](https://www.virtualbox.org/manual/UserManual.html#idp10525536)

Create a file `/etc/vbox/networks.conf` with allowed IP ranges for Virtualbox.

```
$ cat /etc/vbox/networks.conf
* 172.28.128.0/24
* 192.168.56.0/24
```

## Installing Containerd

* Install containerd

```
# curl -sSLO https://github.com/containerd/containerd/releases/download/v1.6.14/containerd-1.6.14-linux-amd64.tar.gz
# tar xzvf containerd-1.6.14-linux-amd64.tar.gz -C /usr/local
```

* Install runc

```
# curl -sSLO https://github.com/opencontainers/runc/releases/download/v1.1.3/runc.amd64
# install -m 755 runc.amd64 /usr/local/sbin/runc
```

* Install CNI plugins

```
# curl -sSLO https://github.com/containernetworking/plugins/releases/download/v1.1.1/cni-plugins-linux-amd64-v1.1.1.tgz
# mkdir -p /opt/cni/bin
# tar xzvf cni-plugins-linux-amd64-v1.1.1.tgz -C /opt/cni/bin
```

* Configure containerd

```
# mkdir /etc/containerd
# containerd config default | sudo tee /etc/containerd/config.toml
# sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
# curl -L https://raw.githubusercontent.com/containerd/containerd/main/containerd.service -o /etc/systemd/system/containerd.service
# systemctl daemon-reload
# systemctl enable --now containerd
# systemctl status containerd
```

* Configure kubelet to use containerd as runtime

Edit file `/var/lib/kubelet/kubeadm-flags.env` and add `--container-runtime=remote` and `--container-runtime-endpoint=unix:///run/containerd/containerd.sock`.

`kubeadm` toold stores the CRI socket for each host as an annotation in the Node object. To change it you can execute the following command

```
$ kubectl edit node <node-name>
```

in the editor change the value of `kubeadm.alpha.kubernetes.io/cri-socket` from `/var/run/dockershim.sock` to CRI socket path of your choice, in this case (`unix:///run/containerd/containerd.sock`) and save the change.

Restart kubelet

```
# systemctl restart kubelet
```

Check if the runtime is changed

```
# kubectl get nodes -o wide
```

## Running test

From any node run the below to test container runtime

```
$ critest -parallel 10 -ginkgo.succinct
```

## Versions

Tested with below versions of the apps

* Vagrant 2.3.4 (2.3.2 or higher required with Virtualbox 7.x)
* VirtualBox 6.1.40/7.0.4 (6.1.28 and higher versions have issue with host-only network. Pls check the troubleshooting section for details)
* yq 4.6.1
* ubuntu/xenial64 (v20210623.0.0)
* ubuntu/bionic64 (v20220317.0.0)
