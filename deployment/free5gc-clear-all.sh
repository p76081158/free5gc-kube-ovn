#!/bin/bash

kubectl delete namespace free5gc
kubectl delete -f subnet/
kubectl delete -f custom-resource-definition/
kubectl delete persistentvolume -l namespace=free5gc