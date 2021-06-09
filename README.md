# free5gc-kube-ovn

![](https://i.imgur.com/wy0NI6X.png)

###### tags: `docs` `Kubernetes` `free5gc`

## Introduction

Deploy free5gc v3.0.5 on kubernetes with kube-ovn v1.8.0

## Requirement

## Quick Start

* Git Clone
```bash
$ git clone https://github.com/p76081158/free5gc-kube-ovn.git
$ cd free5gc-kube-ovn
```
* Create Kubernetes Cluster by all-in-one script
```bash
$ sudo ./quickstart.sh
```
![](doc/terminalizer/gif/quickstart.gif)
* Join Worker to Kubernetes Cluster
```bash
# run sudo kubeadm join on every worker
$ sudo kubeadm join <ip> --token 31pm55.4m9buzv23pfp616n     --discovery-token-ca-cert-hash sha256:48c6017e83ab8bdd4b75bda9285c625808150a07e267d57ccd76aa569597ba4a
```
* Check Worker and Pod status
```bash
$ kubectl get node
$ kubectl get pod --all-namespaces -o wide
```
* Create free5gc yaml files by script
```bash
$ cd deployment/free5gc
# ./free5gc-create-tenant.sh <mcc> <mnc> <abbreviation of telecom> <nsi id> <amf ip> <core network id>
# default gnb ip will be the next ip of amf, so need reserve one ip for default gnb
# example
$ ./free5gc-create-tenant.sh 466 01 FET 1 192.168.72.50 1
$ ./free5gc-create-tenant.sh 466 11 FET 1 192.168.72.52 2
$ ./free5gc-create-tenant.sh 466 93 FET 1 192.168.72.54 3
```
* Apply free5gc yaml files
```bash
$ cd deployment/free5gc
# ./free5gc-apply-plmn.sh <plmn>
# example
$ ./free5gc-apply-plmn.sh 466-01
```
* Delete All free5gc
```bash
$ cd deployment/free5gc
$ ./free5gc-clear-all.sh
```
* Uninstall All
```bash
# reset kubeadm
$ cd kubeadm/
$ sudo ./kubeadm-reset.sh

# Clear kube-ovn config
$ cd kube-ovn/
$ sudo ./delete-config.sh
```

## Custom Resource

### TeleCom

```yaml
```

### gNB

```yaml
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
