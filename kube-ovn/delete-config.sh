#!/bin//bash

sudo rm -rf /var/run/openvswitch
sudo rm -rf /var/run/ovn
sudo rm -rf /etc/origin/openvswitch/
sudo rm -rf /etc/origin/ovn/
# default value
sudo rm -rf /etc/cni/net.d/00-kube-ovn.conflist
# default value
sudo rm -rf /etc/cni/net.d/01-kube-ovn.conflist
sudo rm -rf /var/log/openvswitch
sudo rm -rf /var/log/ovn
