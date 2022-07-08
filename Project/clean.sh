#!/bin/bash
docker_rm() {
    if [ -n "$(docker ps -a -q)" ]; then
        docker rm -f $(docker ps -a -q)
    fi
}

docker_rm
sudo ip link set br0 down
sudo ip link delete br0 type bridge
sudo iptables -t nat -D POSTROUTING 1
sudo kill -9 `ps aux | grep GWrBRGr | grep dhcpd | awk '{print $2}'`