# free5gc-kube-ovn

![](https://i.imgur.com/wy0NI6X.png)

###### tags: `docs` `Kubernetes` `free5gc`

## Introduction

Deploy free5gc v3.0.5 on kubernetes with kube-ovn v1.8.0

## Requirement

* [free5gc-kube-ovn Prerequest](https://hackmd.io/@Vcx/HytNUJwS_)

## Quick Start

### Git Clone

```bash
$ git clone https://github.com/p76081158/free5gc-kube-ovn.git
$ cd free5gc-kube-ovn
```

### Create Kubernetes Cluster by all-in-one script

```bash
$ sudo ./quickstart.sh
```
![](https://github.com/p76081158/free5gc-kube-ovn/blob/main/doc/terminalizer/gif/quickstart.gif?raw=true)
* [gif source](https://github.com/p76081158/free5gc-kube-ovn/blob/main/doc/terminalizer/gif/quickstart.gif)

### Join Worker to Kubernetes Cluster

```bash
# run sudo kubeadm join on every worker
$ sudo kubeadm join <ip> --token 31pm55.4m9buzv23pfp616n     --discovery-token-ca-cert-hash sha256:48c6017e83ab8bdd4b75bda9285c625808150a07e267d57ccd76aa569597ba4a
```

### Check Worker and Pod status

```bash
$ kubectl get node
$ kubectl get pod --all-namespaces -o wide
```
![](https://github.com/p76081158/free5gc-kube-ovn/blob/main/doc/terminalizer/gif/check.gif?raw=true)
* [gif source](https://github.com/p76081158/free5gc-kube-ovn/blob/main/doc/terminalizer/gif/check.gif)

### Initialization of free5gc

```bash
$ cd deployment/
$ ./free5gc-init.sh
```
![](https://github.com/p76081158/free5gc-kube-ovn/blob/main/doc/terminalizer/gif/free5gc-init.gif?raw=true)
* [gif source](https://github.com/p76081158/free5gc-kube-ovn/blob/main/doc/terminalizer/gif/free5gc-init.gif)

### Create free5gc yaml files by script and Apply to kubernetes

```bash
$ cd deployment/free5gc
# ./free5gc-create-tenant.sh <mcc> <mnc> <abbreviation of telecom> <nsi id> <amf ip>
# default gnb ip will be the next ip of amf, so need reserve one ip for default gnb
# example
$ ./free5gc-create-tenant.sh 466 01 FET 1 192.168.72.50 
$ ./free5gc-create-tenant.sh 466 11 CHT 1 192.168.72.52 
$ ./free5gc-create-tenant.sh 466 93 TWM 1 192.168.72.54 
```
![](https://github.com/p76081158/free5gc-kube-ovn/blob/main/doc/terminalizer/gif/free5gc-create-tenant.gif?raw=true)
* [gif source](https://github.com/p76081158/free5gc-kube-ovn/blob/main/doc/terminalizer/gif/free5gc-create-tenant.gif)

### Delete All free5gc in kubernetes

```bash
$ cd deployment/
$ ./free5gc-clear-all.sh
```
![](https://github.com/p76081158/free5gc-kube-ovn/blob/main/doc/terminalizer/gif/free5gc-clear.gif?raw=true)
* [gif source](https://github.com/p76081158/free5gc-kube-ovn/blob/main/doc/terminalizer/gif/free5gc-clear.gif)

### Uninstall All

```bash
# reset kubeadm, run these cmd on every node in kubernetes cluster and reboot
$ cd kubeadm/
$ sudo ./kubeadm-reset.sh

# Clear kube-ovn config
$ cd kube-ovn/
$ sudo ./delete-config.sh
```
![image alt](https://github.com/p76081158/free5gc-kube-ovn/blob/main/doc/terminalizer/gif/uninstall-all.gif?raw=true)
## Custom Resource

### TeleCom Example

```yaml=
---
apiVersion: "nso.free5gc.com/v1"
kind: TeleCom
metadata:
  name: "466-01"
  namespace: free5gc
spec:
  id: 1
  provider: free5gc
  abbrev: "FET"
  mcc: "466"
  mnc: "01"
  gnb-nums: 1
  slice-nums: 0
```

### gNB Example

```yaml=
---
apiVersion: "nso.free5gc.com/v1"
kind: gNB
metadata:
  name: "466-01-000000010"
spec:
  mcc: "466"
  mnc: "01"
  ue-nums: 0
  n3_cidr: "10.201.100.0/24"
  external_ip: "192.168.72.51"
```
