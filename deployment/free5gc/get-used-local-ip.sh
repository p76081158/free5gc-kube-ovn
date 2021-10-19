#!/bin/bash

if [ -z "$1" ]
then
    echo "Please enter CIDR!"
    exit
else
    echo "List used ip in $1/24 !"
fi

# input example: local_ip="192.168.72."
local_ip="$1"
status=$(dpkg -s nmap | grep Status)

if [ -z "$status" ]
then
    echo "Install nmap"
    sudo apt install nmap
fi

sudo nmap -sP -PR $local_ip* | grep $local_ip