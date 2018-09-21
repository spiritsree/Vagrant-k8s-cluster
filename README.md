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
$ sh setup.sh
```

## Destroy

You can destroy the cluster and kubectl config using `destroy.sh` script.

```
$ sh destroy.sh
```
