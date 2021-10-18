#!/bin//bash

# Create kubernetes cluster master node
echo "[Initial 0] Create kubernetes cluster"
kubeadm init --config kubeadm/kubeadm-config.yaml
echo "-------------------------------"
echo ""

# Set up local kubeconfig
echo "[Initial 1] Set up local kubeconfig"
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
echo "-------------------------------"
echo ""

# kube-ovn
cd kube-ovn/
bash install-new.sh
cd ..

# other cni
echo "[Step 7] Install other CNI"
cd cni
kubectl apply -f .
cd ..
echo "-------------------------------"
echo ""

# prometheus
echo "[Step 8] Install other Prometheus"
cd prometheus
./install.sh
cd ..
echo "-------------------------------"
echo ""

# other plugin
# echo "[Step 8] Install Kubernetes Plugin"
# cd plugin
# kubectl apply -f .
# cd ..
# echo "-------------------------------"
# echo ""

# print kubeadm join token
echo "[Final] Join worker to cluster"
kubeadm token create --print-join-command
echo "-------------------------------"
echo ""

# kubectl without root
chown -R $USER $HOME/.kube