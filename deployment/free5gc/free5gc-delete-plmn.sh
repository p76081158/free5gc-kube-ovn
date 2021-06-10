#!/bin/bash

if [ -z "$1" ]
then
    echo "Please enter plmn (mcc-mnc)!"
    exit
else
    echo "Apply $1 plmn free5gc!"
fi

kustomizedelete () {
cd $1 && kubectl delete -k .
cd ../../
}

plmn="$1"

# Delete core network from kubernetes
cd $plmn
cd amf          && kustomizedelete base
cd ausf         && kustomizedelete base
cd nssf         && kustomizedelete base
cd pcf          && kustomizedelete base
cd udm          && kustomizedelete base
cd udr          && kustomizedelete base
cd UERANSIM-gnb && kustomizedelete base
cd webui        && kustomizedelete base
cd nrf          && kustomizedelete base
cd mongodb      && kustomizedelete base

# Delete custom resource
kubectl delete -f custom-resource/