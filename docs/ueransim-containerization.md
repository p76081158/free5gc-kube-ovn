# UERANSIM containerization

![](https://i.imgur.com/wy0NI6X.png)

###### tags: `docs` `Kubernetes` `free5gc`

## Introduction

container version of [aligungr/UERANSIM](https://github.com/aligungr/UERANSIM)

## How to create docker image

### Find requirement and install step in github repo

[requirement](https://github.com/aligungr/UERANSIM/wiki/Installation)

* Ubuntu 16.04 or later
* CMake 3.17 or later
* gcc 9.0.0 or later

[Install step](https://github.com/aligungr/UERANSIM/wiki/Installation#dependencies)

```bash
# install package
$ sudo apt install make
$ sudo apt install g++
$ sudo apt install libsctp-dev lksctp-tools
$ sudo apt install iproute2
$ sudo snap install cmake --classic

# git clone and build
$ git clone https://github.com/aligungr/UERANSIM
$ cd ~/UERANSIM
$ make
```

### Write Dockerfile base on requirement and install step

Example dockerfile for UERANSIM

```dockerfile=
FROM ubuntu:18.04 AS builder

LABEL description="aligungr/UERANSIM"

# Install dependencies
RUN apt update && \
    apt install -y software-properties-common && \
    add-apt-repository ppa:ubuntu-toolchain-r/test && \
    apt update && \
    apt install -y gcc-9 make g++ libsctp-dev lksctp-tools iproute2 apt-transport-https ca-certificates gnupg wget git iputils-ping && \
    wget -qO - https://apt.kitware.com/keys/kitware-archive-latest.asc | apt-key add - && \
    apt-add-repository 'deb https://apt.kitware.com/ubuntu/ bionic main' && \
    apt update && \
    apt install -y cmake && \
    git clone -b v3.2.0 --depth 1 https://github.com/aligungr/UERANSIM && \
    cd UERANSIM && \
    make && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* 
    
# Set working dir
WORKDIR /UERANSIM
```

### Build Dockerfile

```bash
$ docker build -t black842679513/free5gc-ueransim:v3.2.0 . --no-cache
```
![image alt](https://media.githubusercontent.com/media/p76081158/free5gc-kube-ovn/assets/docs/terminalizer/gif/ueransim-image-build.gif)

### Push to Dockerhub

```bash
$ docker push black842679513/free5gc-ueransim:v3.2.0
```
![image alt](https://media.githubusercontent.com/media/p76081158/free5gc-kube-ovn/assets/docs/terminalizer/gif/ueransim-image-push.gif)