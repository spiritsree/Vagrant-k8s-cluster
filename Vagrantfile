# -*- mode: ruby -*-
# vi: set ft=ruby :

# Global Variables
BOX_IMAGE = "ubuntu/bionic64"
WORKER_COUNT = nil
NETWORKING_TYPE = nil
KUBERNETES_VERSION = '1.21.14'
GO_VERSION = '1.15'
DOCKER_VERSION = '19.03'
CONTAINERD_VERSION = '1.6.1'
CRICTL_VERSION = '1.21.0'
METRICS_SERVER_VERSION = '0.6.2'
METALLB_VERSION = '0.12.1'

if WORKER_COUNT.nil?
  NODE_COUNT = 2
else
  NODE_COUNT = WORKER_COUNT
end

if NETWORKING_TYPE.nil?
  NETWORKING_MODEL = "flannel"
else
  NETWORKING_MODEL = NETWORKING_TYPE
end

# Common Script for both master and nodes to install everything.
$script = <<-'SCRIPT'
export KUBE_VERSION=$1
export GO_VERSION=$2
export DOCKER_VERSION=$3
export CONTAINERD_VERSION=$4
export CRICTL_VERSION=$5
export DEBIAN_FRONTEND=noninteractive
export APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=DontWarn
echo '====================== Install mdns ======================'
echo -n 'Install avahi-daemon and mdns: '
apt-get update > /dev/null
apt-get install -y avahi-daemon libnss-mdns > /dev/null
[[ $? -eq 0 ]] && echo OK

echo '====================== Adding apt-keys ======================'
apt-get update > /dev/null && apt-get install -y apt-transport-https ca-certificates curl jq software-properties-common libseccomp2 > /dev/null
echo -n 'Add docker apt-key: '
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
echo -n 'Add docker apt-repository: '
add-apt-repository "deb https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") $(lsb_release -cs) stable" > /dev/null
[[ $? -eq 0 ]] && echo OK || { add-apt-repository -r "deb https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") $(lsb_release -cs) stable" > /dev/null; exit 1; }

echo -n 'Add google cloud apt-key: '
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo -n 'Add kubernetes apt-repository: '
add-apt-repository "deb https://apt.kubernetes.io/ kubernetes-xenial main" > /dev/null
[[ $? -eq 0 ]] && echo OK || { add-apt-repository -r "deb https://apt.kubernetes.io/ kubernetes-xenial main"; echo "Check https://packages.cloud.google.com/apt/dists"; exit 1; }
apt-get update > /dev/null
echo '====================== Install Docker ======================'
echo -n 'Install Docker-CE: '
docker_image_version=$(apt-cache madison docker-ce | grep ${DOCKER_VERSION} | head -1 | awk '{print $3}')
if [[ -z ${docker_image_version} ]]; then
  echo "Error: Docker image with version ${DOCKER_VERSION} not found !!!"
  exit 1
fi
apt-get install -y docker-ce="${docker_image_version}" > /dev/null
[[ $? -eq 0 ]] && echo OK

echo '==================== Install Containerd ===================='
echo -n 'Install Containerd: '
curl -sSLO https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/cri-containerd-cni-${CONTAINERD_VERSION}-linux-amd64.tar.gz 2> /dev/null && \
tar --no-overwrite-dir -C / -xzf cri-containerd-cni-${CONTAINERD_VERSION}-linux-amd64.tar.gz
[[ $? -eq 0 ]] && echo OK
systemctl start containerd

echo '====================== Install Kubernetes ======================'
echo -n 'Install Kubernetes: '
apt-get install -y kubeadm=$(apt-cache madison kubeadm | grep ${KUBE_VERSION} |  head -1 | awk '{print $3}') \
kubectl=$(apt-cache madison kubectl | grep ${KUBE_VERSION} |  head -1 | awk '{print $3}') \
kubelet=$(apt-cache madison kubelet | grep ${KUBE_VERSION} |  head -1 | awk '{print $3}') > /dev/null
[[ $? -eq 0 ]] && echo OK

echo '====================== Install and Setup Go ======================'
echo -n 'Download and install go: '
curl -O https://storage.googleapis.com/golang/go${GO_VERSION}.linux-amd64.tar.gz 2> /dev/null && \
tar -xzf go${GO_VERSION}.linux-amd64.tar.gz -C /usr/local
[[ $? -eq 0 ]] && { echo OK; echo 'export GOROOT=/usr/local/go' >> /etc/profile; echo 'export PATH=$PATH:$GOROOT/bin' >> /etc/profile; source /etc/profile; }
mkdir -p /go/{bin,src}
export GOPATH=/go
echo "export GOPATH=/go" >> /etc/profile
export PATH=$PATH:$GOPATH/bin
echo "export PATH=$PATH:$GOPATH/bin" >> /etc/profile

echo '====================== Install crictl ======================'
echo -n 'Install crictl: '
curl -sSLO https://github.com/kubernetes-sigs/cri-tools/releases/download/v${CRICTL_VERSION}/crictl-v${CRICTL_VERSION}-linux-amd64.tar.gz && \
tar zxf crictl-v${CRICTL_VERSION}-linux-amd64.tar.gz -C /usr/local/bin
[[ $? -eq 0 ]] && echo OK
rm -f crictl-v${CRICTL_VERSION}-linux-amd64.tar.gz

echo '====================== Swap Off ======================'
[[ $(cat /proc/swaps | wc -l) -gt 1 ]] && cat /proc/swaps
swapoff -a
echo 'Swap is off...'
[[ $(cat /etc/fstab | grep swap | wc -l) -gt 0 ]] && { sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab; }
echo 'Commented swap partition from fstab...'

# Configure same cgroup for docker and kubernetes
echo '====================== Configure cgroup to systemd ======================'
echo -n 'Docker' && docker info 2> /dev/null | grep -i cgroup
echo 'Changing Kubernetes cgroup type to systemd...'
# Adding --authentication-token-webhook=true so that metrics-server can connect without any issues.
# Adding --node-ip=VAGRANT_NODE_IP so the pods can be reached from other nodes/api
node_if=$(ifconfig | grep -B2 -E '172.28.128|192.168.56' | grep enp0 | awk '{ print $1 }')
node_ip=$(ifconfig ${node_if} | grep -E 'Mask|netmask' | awk '{ print $2 }' | cut -d: -f2)
if [[ $(cat /etc/systemd/system/kubelet.service.d/10-kubeadm.conf | grep 'authentication-token-webhook=true' | wc -l) -eq 0 ]]; then
  E_ARG_PARAM="--cgroup-driver=systemd --authentication-token-webhook=true --node-ip=${node_ip}"
else
  E_ARG_PARAM="--cgroup-driver=systemd --node-ip=${node_ip}"
fi
sed -i "0,/ExecStart=/ s//Environment=\"KUBELET_EXTRA_ARGS=${E_ARG_PARAM}\"\n&/" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
echo 'Changing Docker cgroup type to systemd...'
cat <<EOF >/etc/docker/daemon.json
{
    "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

# Loading ip_vs modules to avoidwarning https://github.com/kubernetes/kubeadm/issues/975
echo 'Loading ip_vs kernel...'
modprobe -a ip_vs ip_vs_rr ip_vs_wrr ip_vs_sh nf_conntrack_ipv4
echo "8192" > /proc/sys/net/ipv4/tcp_rmem
echo "8192" > /proc/sys/net/ipv4/tcp_wmem

echo '====================== Reload services ======================'
echo 'Reloading kubelet, containerd and docker...'
systemctl daemon-reload
systemctl restart kubelet
systemctl restart docker
systemctl restart containerd

echo '====================== Verify cgroup type ======================'
echo -n 'Docker ' && docker info 2> /dev/null | grep -i cgroup

echo '====================== Net Info ======================'
echo -e "IP Link ...... \n $(ip link)"
echo -e "Product UUID ...... \n $(cat /sys/class/dmi/id/product_uuid)"

SCRIPT

# Master Script to initialize and setup Kubernetes Master.
$masterscript = <<-'MASTERSCRIPT'

export NET_INTERFACE=$(ifconfig | grep -B2 -E '172.28.128|192.168.56' | grep enp0 | awk '{ print $1 }' | tr -d ':')
export IPADDR=$(ifconfig ${NET_INTERFACE} | grep -E 'Mask|netmask' | awk '{ print $2 }' | cut -d: -f2)
export NODENAME=$(hostname -s)
export NETWORKING=$1
export METRICS_SERVER=$2
export METALLB_VER=$3

echo This VM has IP address $IPADDR and name $NODENAME
echo "$IPADDR  $NODENAME" >> /etc/hosts
echo "$IPADDR  $NODENAME.local" >> /etc/hosts

echo '====================== Initialize Kubeadm ======================'
kube_version=$(kubectl version --client --short -o json | jq -r '"stable-" + .clientVersion.major + "." + .clientVersion.minor')
kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=$IPADDR --kubernetes-version=${kube_version} | tee kubeinit.out
echo "$(cat kubeinit.out | sed ':a;N;$!ba;s/\\\n/ /g' | grep -e '^[ ]*kubeadm join' | sed -e 's/^[ \t]*//')" > /opt/join.cmd
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
echo '' >> /etc/kubernetes/admin.conf
CONFIG_EXPOSE() { rm -f /tmp/conf; mkfifo /tmp/conf; while :; do cat /tmp/conf | /bin/cat /etc/kubernetes/admin.conf | base64 | nc -C -O 8192 -l $IPADDR -p 8888 -q 1 > /tmp/conf; done; }
export -f CONFIG_EXPOSE
nohup bash -c CONFIG_EXPOSE &

echo 'Exposing /opt/join.cmd on port 8889 ...'
JOIN_EXPOSE() { rm -f /tmp/join; mkfifo /tmp/join; while :; do cat /tmp/join | /bin/cat /opt/join.cmd | nc -l $IPADDR -p 8889 -q 1 > /tmp/join; done; }
export -f JOIN_EXPOSE
nohup bash -c JOIN_EXPOSE &

echo '====================== Deploy Networking ======================'
echo "Selected networking model is ${NETWORKING} ..."
echo "Deploying ${NETWORKING}..."
if [[ ${NETWORKING} == 'flannel' ]]; then
  curl 'https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml' -O 2> /dev/null
  sed -i "s/- --ip-masq/- --iface=${NET_INTERFACE}\n        - --ip-masq/g" kube-flannel.yml
  kubectl apply -f kube-flannel.yml
elif [[ ${NETWORKING} == 'canal' ]]; then
  curl -k 'https://projectcalico.docs.tigera.io/manifests/canal.yaml' -O 2> /dev/null
  sed -i "s/\"--ip-masq\"/\"--iface=${NET_INTERFACE}\", \"--ip-masq\"/g" canal.yaml
  kubectl apply -f canal.yaml
elif [[ ${NETWORKING} == 'calico' ]]; then
  curl -k 'https://projectcalico.docs.tigera.io/manifests/calico.yaml' -O 2> /dev/null
  sed -i 's/192.168.0.0/10.244.0.0/g' calico.yaml
  sed -i '/CALICO_IPV4POOL_CIDR/s/# //' calico.yaml
  sed -i '/10.244.0.0/s/# //' calico.yaml
  kubectl apply -f calico.yaml
elif [[ ${NETWORKING} == 'weavenet' ]]; then
  kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
fi

echo '====================== Kubernetes Cluster Status ======================'
kubectl cluster-info | grep --line-buffered '^'

echo '====================== Deploying helm ======================'
echo 'Installing helm client...'
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get 2> /dev/null | bash > /dev/null 2>&1
echo 'Adding service account tiller...'
kubectl create serviceaccount --namespace kube-system tiller > /dev/null 2>&1
echo 'Adding cluster role binding for tiller service account...'
kubectl create clusterrolebinding add-on-cluster-admin --clusterrole=cluster-admin --serviceaccount=kube-system:tiller > /dev/null 2>&1
echo 'Deploying helm tiller with service account tiller...'
helm init --service-account tiller --upgrade > /dev/null 2>&1

echo '====================== Deploying metrics-server ======================'
echo 'Get the metric-server deployment manifest...'
curl -sSLO  https://github.com/kubernetes-sigs/metrics-server/releases/download/v${METRICS_SERVER}/components.yaml
# The below command is to fix metrics-server resolving the node name using internalIP and
# also to avoid getting error on TLS connection due to the IP not being there in the
# subject alternate names in client certificate.
if [[ $(grep 'args:' components.yaml | wc -l) == 1 ]]; then
  sed -Ei '0,/args:/ s/args:/args:\n        - --kubelet-insecure-tls\n        - --kubelet-preferred-address-types=InternalIP/' components.yaml
else
  sed -Ei '0,/image: k8s\.gcr\.io\/metrics-server-amd64:v[0-9]+\.[0-9]+\.[0-9]+/ s//args:\n        - --kubelet-insecure-tls\n        - --kubelet-preferred-address-types=InternalIP\n        &/' components.yaml
fi
echo 'Deploying metrics-server...'
kubectl create -f components.yaml > /dev/null 2>&1

echo '====================== Deploying MetalLB ======================'
echo 'Get the MetalLB manifest...'
curl -sSLO https://raw.githubusercontent.com/metallb/metallb/v${METALLB_VER}/manifests/namespace.yaml
curl -sSLO https://raw.githubusercontent.com/metallb/metallb/v${METALLB_VER}/manifests/metallb.yaml
echo 'Deploying MetalLB...'
kubectl create -f namespace.yaml > /dev/null 2>&1
kubectl create -f metallb.yaml > /dev/null 2>&1
curl -sSLO https://raw.githubusercontent.com/spiritsree/Vagrant-k8s-cluster/master/configs/metallb-config.yaml
export IPF=$(echo ${IPADDR} | awk -F'.' '{ print $1 "." $2 "." $3 ".240" }')
export IPL=$(echo ${IPADDR} | awk -F'.' '{ print $1 "." $2 "." $3 ".250" }')
sed -i "s/IPF/${IPF}/g" metallb-config.yaml
sed -i "s/IPL/${IPL}/g" metallb-config.yaml
kubectl create -f metallb-config.yaml > /dev/null 2>&1

echo '====================== END ======================'
MASTERSCRIPT

# Worker Script to initialize and join the Master to form a cluster.
$workerscript = <<-'WORKERSCRIPT'
export NET_INTERFACE=$(ifconfig | grep -B2 -E '172.28.128|192.168.56' | grep enp0 | awk '{ print $1 }')
export IPADDR=$(ifconfig ${NET_INTERFACE} | grep -e 'Mask|netmask' | awk '{ print $2 }' | cut -d: -f2)
export NODENAME=$(hostname -s)
export CONFIG_READY=0
echo This VM has IP address $IPADDR and name $NODENAME
echo "$IPADDR  $NODENAME" >> /etc/hosts
echo "$IPADDR  $NODENAME.local" >> /etc/hosts

echo '====================== Get Configs from Master ======================'
export MASTERIP=$(getent ahosts master.local | awk '{ print $1 }' | head -1)
echo 'Getting Config from Master...'
nc -w3 -C -I 8192 ${MASTERIP} 8888 | base64 -d -i > kube_config
echo 'Getting Join command from Master...'
nc ${MASTERIP} 8889 > kube_join
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
kubectl get nodes | grep --line-buffered '^'

echo '====================== END ======================'
WORKERSCRIPT


Vagrant.configure("2") do |config|

  config.vm.provider "virtualbox" do |vb|
    vb.memory = "1800"
  end
  config.vm.define "master" do |master|
    master.vm.box = BOX_IMAGE
    master.vm.hostname = "master"
    master.vm.network "private_network", type: "dhcp"
    master.vm.provision "shell" do |script|
      script.inline = $script
      script.args = [KUBERNETES_VERSION, GO_VERSION, DOCKER_VERSION, CONTAINERD_VERSION, CRICTL_VERSION]
    end
    master.vm.provision "shell" do |masterscript|
      masterscript.inline = $masterscript
      masterscript.args = [NETWORKING_MODEL, METRICS_SERVER_VERSION, METALLB_VERSION]
    end
  end

  (1..NODE_COUNT).each do |i|
    config.vm.define "node-#{i}" do |node|
      node.vm.box = BOX_IMAGE
      node.vm.hostname = "node-#{i}"
      node.vm.network "private_network", type: "dhcp"
      node.vm.provision "shell" do |script|
       script.inline = $script
       script.args = [KUBERNETES_VERSION, GO_VERSION, DOCKER_VERSION, CONTAINERD_VERSION, CRICTL_VERSION]
      end
      node.vm.provision "shell", inline: $workerscript
    end
  end

end
