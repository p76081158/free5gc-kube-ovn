#!/bin/bash

kubectl apply -f namespace/
kubectl apply -f network-attachment-definition/
kubectl apply -f custom-resource-definition/
kubectl apply -f subnet/