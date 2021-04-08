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
    git clone https://github.com/aligungr/UERANSIM && \
    cd UERANSIM && \
    make && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* 
    
# Set working dir
WORKDIR /UERANSIM

