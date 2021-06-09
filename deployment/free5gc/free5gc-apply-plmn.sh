#!/bin/bash

if [ -z "$1" ]
then
    echo "Please enter plmn (mcc-mnc)!"
    exit
else
    echo "Apply $1 plmn free5gc!"
fi

plmn="$1"

checkpod () {
while [[ $(kubectl -n free5gc get pods -l app=$1 -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for pod" $1 && sleep 1; done
}

kustomizeapply () {
cd $1 && kubectl apply -k .
cd ../../
}

cd $plmn
cd mongodb      && kustomizeapply base

# Depends on mongodb
checkpod free5gc-mongodb-$plmn
cd nrf          && kustomizeapply base
cd webui        && kustomizeapply base

# Depends on nrf
checkpod free5gc-nrf-$plmn

cd amf          && kustomizeapply base
cd ausf         && kustomizeapply base
cd nssf         && kustomizeapply base
cd pcf          && kustomizeapply base
cd udm          && kustomizeapply base
cd udr          && kustomizeapply base
cd UERANSIM-gnb && kustomizeapply base
