#!/bin/bash

kubectl delete namespace free5gc
kubectl delete -f custom-resource-definition/
kubectl delete subnets.kubeovn.io -l namespace=free5gc
kubectl delete persistentvolume -l namespace=free5gc