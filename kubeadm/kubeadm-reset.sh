
# kubeadm reset
sudo kubeadm reset
sudo systemctl restart kubelet

# clear cni
sudo rm -rf /var/lib/cni/
sudo rm -rf /var/lib/kubelet/*
sudo rm -rf /run/flannel
sudo rm -rf /etc/cni/
