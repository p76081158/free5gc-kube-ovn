#!/bin//bash

# Create kubernetes cluster master node
echo "[Initial 0] Create kubernetes cluster"
sudo kubeadm init --config kubeadm/kubeadm-config.yaml
echo "-------------------------------"
echo ""

# Set up local kubeconfig
echo "[Initial 1] Set up local kubeconfig"
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
echo "-------------------------------"
echo ""

# kube-ovn
cd kube-ovn/
sudo bash install.sh
cd ..

# other cni
echo "[Step 7] Install other cni"
cd cni
kubectl apply -f .
cd ..
echo "-------------------------------"
echo ""

# print kubeadm join token
echo "[Final] Join worker to cluster"
kubeadm token create --print-join-command
echo "-------------------------------"
echo ""