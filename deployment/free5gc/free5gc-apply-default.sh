#!/bin/bash

checkpod () {
while [[ $(kubectl -n free5gc get pods -l app=$1 -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for pod" $1 && sleep 1; done
}

kustomizeapply () {
cd $1 && kubectl apply -k .
cd ../../
}

cd default
cd mongodb      && kustomizeapply base

# Depends on mongodb
checkpod free5gc-mongodb
cd nrf          && kustomizeapply base
cd webui        && kustomizeapply base

# Depends on nrf
checkpod free5gc-nrf
cd amf          && kustomizeapply base
cd ausf         && kustomizeapply base
cd nssf         && kustomizeapply base
cd pcf          && kustomizeapply base
cd udm          && kustomizeapply base
cd udr          && kustomizeapply base
