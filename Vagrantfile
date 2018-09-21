# -*- mode: ruby -*-
# vi: set ft=ruby :

# Common Script for both master and nodes to install everything.
$script = <<-'SCRIPT'
KUBE_VERSION='1.9.10'
GO_VERSION='1.10'
DOCKER_VERSION='17.03'
export DEBIAN_FRONTEND=noninteractive
echo '====================== Install mdns ======================'
echo -n 'Install avahi-daemon and mdns: '
apt-get install -y avahi-daemon libnss-mdns > /dev/null
[[ $? -eq 0 ]] && echo OK

echo '====================== Install Docker ======================'
apt-get update > /dev/null && apt-get install -y apt-transport-https ca-certificates curl software-properties-common > /dev/null
echo -n 'Add docker apt-key: '
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
echo -n 'Add docker apt-repository: '
add-apt-repository "deb https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") $(lsb_release -cs) stable"
[[ $? -eq 0 ]] && echo OK
echo -n 'Install Docker-CE: '
apt-get update > /dev/null && apt-get install -y docker-ce=$(apt-cache madison docker-ce | grep ${DOCKER_VERSION} | head -1 | awk '{print $3}') > /dev/null
[[ $? -eq 0 ]] && echo OK

echo '====================== Install Kubernetes ======================'
echo -n 'Add google cloud apt-key: '
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo -n 'Add kubernetes apt-repository: '
add-apt-repository "deb https://apt.kubernetes.io/ kubernetes-$(lsb_release -cs) main"
[[ $? -eq 0 ]] && echo OK
echo -n 'Install Kubernetes: '
apt-get update > /dev/null && apt-get install -y kubeadm=$(apt-cache madison kubeadm | grep ${KUBE_VERSION} |  head -1 | awk '{print $3}') \
kubectl=$(apt-cache madison kubeadm | grep ${KUBE_VERSION} |  head -1 | awk '{print $3}') \
kubelet=$(apt-cache madison kubelet | grep ${KUBE_VERSION} |  head -1 | awk '{print $3}') > /dev/null
[[ $? -eq 0 ]] && echo OK

echo '====================== Install Go ======================'
echo -n 'Download and install go: '
curl -O https://storage.googleapis.com/golang/go${GO_VERSION}.linux-amd64.tar.gz 2> /dev/null && tar -xzf go${GO_VERSION}.linux-amd64.tar.gz -C /usr/local
[[ $? -eq 0 ]] && { echo OK; echo 'export GOROOT=/usr/local/go' >> /etc/profile; echo 'export PATH=$PATH:$GOROOT/bin' >> /etc/profile; source /etc/profile; }

echo '====================== Install crictl ======================'
echo -n 'Install crictl: '
go get github.com/kubernetes-incubator/cri-tools/cmd/crictl
[[ $? -eq 0 ]] && echo OK

echo '====================== Swap Off ======================'
cat /proc/swaps
swapoff -a
echo 'Swap is off...'
[[ $(cat /etc/fstab | grep swap | wc -l) -gt 0 ]] && { sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab; }
echo 'Commented swap partition from fstab...'

# Configure same cgroup for docker and kubernetes
echo '====================== Configure cgroup to systemd ======================'
echo -n 'Docker ' && docker info 2> /dev/null | grep -i cgroup
echo 'Changing Kubernetes cgroup type to systemd...'
sed -i '0,/ExecStart=/ s//Environment="KUBELET_EXTRA_ARGS=--cgroup-driver=systemd"\n&/' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
echo 'Changing Docker cgroup type to systemd...'
cat <<EOF >/etc/docker/daemon.json
{
    "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

echo '====================== Reload services ======================'
echo 'Reloading kubelet and docker...'
systemctl daemon-reload
systemctl restart kubelet
systemctl restart docker

echo '====================== Verify cgroup type ======================'
echo -n 'Docker ' && docker info 2> /dev/null | grep -i cgroup

echo '====================== Net Info ======================'
echo -e "IP Link ...... \n $(ip link)"
echo -e "Product UUID ...... \n $(cat /sys/class/dmi/id/product_uuid)"

SCRIPT

# Master Script to initialize and setup Kubernetes Master.
$masterscript = <<-'MASTERSCRIPT'

export NET_INTERFACE=$(ifconfig | grep -B2 172 | grep enp0 | awk '{ print $1 }')
export IPADDR=$(ifconfig ${NET_INTERFACE} | grep Mask | awk '{ print $2 }' | cut -d: -f2)
export NODENAME=$(hostname -s)
echo This VM has IP address $IPADDR and name $NODENAME
echo "$IPADDR  $NODENAME" >> /etc/hosts
echo "$IPADDR  $NODENAME.local" >> /etc/hosts

echo '====================== Initialize Kubeadm ======================'
kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$IPADDR --ignore-preflight-errors=cri | tee kubeinit.out
echo "$(cat kubeinit.out | grep -e '^[ ]*kubeadm join' | sed -e 's/^[ \t]*//') --ignore-preflight-errors=cri" > /opt/join.cmd
export KUBECONFIG=/etc/kubernetes/admin.conf

echo '====================== Traffic through iptables ======================'
echo 'IPv4 trafic to pass through the iptables chain..'
echo 'Setting net.bridge.bridge-nf-call-iptables to 1..'
sysctl net.bridge.bridge-nf-call-iptables=1

echo '====================== Setup admin cred ======================'
echo 'Copying credentials to $HOME/.kube/config ...'
if [[ "$HOME" == "/home/vagrant" ]]; then
  mkdir -p $HOME/.kube
  sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
else
  mkdir -p $HOME/.kube /home/vagrant/.kube
  cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
  cp -f /etc/kubernetes/admin.conf /home/vagrant/.kube/config
  chown $(id -u):$(id -g) $HOME/.kube/config /home/vagrant/.kube/config
fi

echo '====================== Expose configs ======================'
echo 'Exposing ~/.kube/config on port 8888 ...'
CONFIG_EXPOSE() { while :; do cat /etc/kubernetes/admin.conf | nc -l $IPADDR -p 8888 -q 1;done; }
export -f CONFIG_EXPOSE
nohup bash -c CONFIG_EXPOSE &

echo 'Exposing /opt/join.cmd on port 8889 ...'
JOIN_EXPOSE() { while :; do cat /opt/join.cmd | nc -l $IPADDR -p 8889 -q 1;done; }
export -f JOIN_EXPOSE
nohup bash -c JOIN_EXPOSE &

echo '====================== Deploy Flannel ======================'
echo 'Deploying flannel...'
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/v0.10.0/Documentation/kube-flannel.yml

echo '====================== Kubernetes Cluster Status ======================'
kubectl cluster-info

echo '====================== END ======================'
MASTERSCRIPT

# Worker Script to initialize and join the Master to form a cluster.
$workerscript = <<-'WORKERSCRIPT'
export NET_INTERFACE=$(ifconfig | grep -B2 172 | grep enp0 | awk '{ print $1 }')
export IPADDR=$(ifconfig ${NET_INTERFACE} | grep Mask | awk '{ print $2 }' | cut -d: -f2)
export NODENAME=$(hostname -s)
export CONFIG_READY=0
echo This VM has IP address $IPADDR and name $NODENAME
echo "$IPADDR  $NODENAME" >> /etc/hosts
echo "$IPADDR  $NODENAME.local" >> /etc/hosts

echo '====================== Get Configs from Master ======================'
export MASTERIP=$(getent ahosts master.local | awk '{ print $1 }' | head -1)
echo 'Getting Config from Master...'
nc ${MASTERIP} 8888 | tee kube_config
echo 'Getting Join command from Master...'
nc ${MASTERIP} 8889 | tee kube_join
[[ ! -s kube_config ]] &&  CONFIG_READY=1

echo '====================== Kubeadm Join cluster ======================'
echo "Joining to master with IP ${MASTERIP}..."
sh kube_join

echo '====================== Update Kube config ======================'
echo 'Verifying if kube config is available..'
[[ ${CONFIG_READY} == 1 ]] && nc ${MASTERIP} 8888 | tee kube_config
echo 'Copying Kube config to $HOME..'
if [[ "$HOME" == "/home/vagrant" ]]; then
  mkdir -p $HOME/.kube
  sudo cp -f kube_config $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
else
  mkdir -p $HOME/.kube /home/vagrant/.kube
  cp -f kube_config $HOME/.kube/config
  cp -f kube_config /home/vagrant/.kube/config
  chown $(id -u):$(id -g) $HOME/.kube/config /home/vagrant/.kube/config
fi

echo '====================== Kubernetes available nodes ======================'
kubectl get nodes

echo '====================== END ======================'
WORKERSCRIPT

BOX_IMAGE = "ubuntu/xenial64"
NODE_COUNT = 3

Vagrant.configure("2") do |config|

  config.vm.define "master" do |master|
    master.vm.box = BOX_IMAGE
    master.vm.hostname = "master"
    master.vm.network "private_network", type: "dhcp"
    master.vm.provision "shell", inline: $script
    master.vm.provision "shell", inline: $masterscript
  end

  (1..NODE_COUNT).each do |i|
    config.vm.define "node-#{i}" do |node|
      node.vm.box = BOX_IMAGE
      node.vm.hostname = "node-#{i}"
      node.vm.network "private_network", type: "dhcp"
      node.vm.provision "shell", inline: $script
      node.vm.provision "shell", inline: $workerscript
    end
  end

end
