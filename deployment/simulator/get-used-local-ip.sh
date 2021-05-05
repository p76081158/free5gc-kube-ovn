#!/bin/bash

local_ip="192.168.72"
status=$(dpkg -s nmap | grep Status)

if [ -z "$status" ]
then
    echo "Install nmap"
    sudo apt isntall nmap
fi

sudo nmap -sP -PR $local_ip* | grep $local_ip

