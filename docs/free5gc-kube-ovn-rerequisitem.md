# free5gc-kube-ovn Prerequisite

![](https://i.imgur.com/wy0NI6X.png)

###### tags: `docs` `Kubernetes` `free5gc` `NFV`

## Requirement

### Linux

* [free5gc linux kernel version & module](https://hackmd.io/@Vcx/Hy_gHkdAD)

### Git

* [Git Install for Ubuntu 18.04](https://hackmd.io/@Vcx/SyuZPlBWu)

### Container Runtime Interface

* Every machines in cluster should have CRI

#### choose one for CRI

* [CRI-O](https://kubernetes.io/docs/setup/production-environment/container-runtimes/#cri-o)
* [containerd](https://hackmd.io/@Vcx/rJFyLPRWO)
* [Docker](https://hackmd.io/@Vcx/ByYcrDvSL)

### Kubernetes

* Using Kubernetes version: **v1.19.0**
* at least **two machine** (master & worker node)

#### install for linux

```bash
# on each node run this cmd
$ sudo apt-get install -y kubelet=1.19.0-00 kubeadm=1.19.0-00 kubectl=1.19.0-00 --allow-downgrades
```

### set kernel ipv6.disable=0 on every nodes

```bash
$ sudo nano /etc/sysctl.conf

net.ipv6.conf.all.disable_ipv6=0

$ sudo sysctl -p
```

## Environment Setup

### Node Requirement

* Every nodes should have **kubelet**, **kubeadm** and **kubectl** installed.
* Also, **CRI** is required on every nodes in kubernetes cluster.
* [Check pods can communicate across nodes or not](https://hackmd.io/@Vcx/HyLSg9xM_#Check-pods-can-communicate-across-nodes-or-not)
* [Swap disabled on every nodes](https://hackmd.io/@Vcx/HyLSg9xM_#Swap-disabled)

### Node detail

* **1 Master Node**
    * **Intel(R) Xeon(R) CPU E3-1230 @ 3.2GHz**
    * 10 GB
    * Ubuntu 18.04.3 LTS
    * CRI : Docker
* **2 Worker Node**
    * **Intel(R) Core(TM) CPU i7-2600 @ 3.4GHz**
    * 12 GB
    * Ubuntu 18.04.5 LTS
    * CRI : containerd
    * **Intel(R) Core(TM) CPU i7-6700 @ 3.4GHz**
    * 16 GB
    * Ubuntu 18.04.5 LTS
    * CRI : containerd

### Get local used ip list

```bash
# get used ip in 192.168.72.0/24 
$ sudo ./get-local-used-ip.sh 192.168.72.
```
![](https://github.com/p76081158/free5gc-kube-ovn/blob/assets/docs/terminalizer/gif/get-local-used-ip.gif?raw=true)