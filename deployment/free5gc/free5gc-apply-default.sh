#!/bin/bash

checkpod () {
while [[ $(kubectl -n free5gc get pods -l app=$1 -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for pod" $1 && sleep 1; done
}

kustomizeapply () {
cd $1 && kubectl apply -k .
cd ../../
}

kubectl apply -f ../namespace/free5gc.yaml
kubectl apply -f ../network-attachment-definition/
kubectl apply -f ../custom-resource-definition/
kubectl apply -f ../subnet/
cd default
cd mongodb      && kustomizeapply base
#cd UERANSIM-gnb && kustomizeapply base
#cd UERANSIM-ue  && kustomizeapply base

# Depends on mongodb
checkpod free5gc-mongodb
cd nrf          && kustomizeapply base
# cd upf-1        && kustomizeapply overlays
cd webui        && kustomizeapply base

# Depends on nrf & upf
checkpod free5gc-nrf
# checkpod free5gc-upf-1
cd amf          && kustomizeapply base
#cd amf-466-01   && kustomizeapply base
cd ausf         && kustomizeapply base
#cd ausf-466-01  && kustomizeapply base
#cd smf          && kustomizeapply overlays
cd nssf         && kustomizeapply base
cd pcf          && kustomizeapply base
cd udm          && kustomizeapply base
cd udr          && kustomizeapply base
