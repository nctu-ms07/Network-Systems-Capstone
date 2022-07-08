#!/bin/bash

docker_build() {
    docker run --detach --interactive --privileged  \
    --network none --cap-add NET_ADMIN --cap-add NET_BROADCAST \
    --name ${1} lab3
}

build_link() {
    ip link add ${1}${2}veth type veth peer name ${2}${1}veth
    
    ip link set ${1}${2}veth netns $(docker inspect --format='{{.State.Pid}}' ${1})
    ip link set ${2}${1}veth netns $(docker inspect --format='{{.State.Pid}}' ${2})
}

quagga_setup() {
    docker exec ${1} sysctl net.ipv4.ip_forward=1
    docker exec ${1} sysctl -p
    docker cp daemons ${1}:/etc/quagga/daemons
    docker cp zebra.conf ${1}:/etc/quagga/zebra.conf
    docker cp bgp_${1}.conf ${1}:/etc/quagga/bgpd.conf
    docker exec ${1} /etc/init.d/quagga restart
}

docker_build R1
docker_build R2
docker_build h1
docker_build h2
docker_build hR

build_link R1 R2
build_link R1 h1
build_link R1 h2
build_link R2 hR

docker exec R1 ip addr add 140.113.2.1/24 dev R1R2veth
docker exec R1 ip addr add 192.168.1.1/24 dev R1h1veth
docker exec R1 ip addr add 192.168.2.1/24 dev R1h2veth
docker exec R2 ip addr add 140.113.2.2/24 dev R2R1veth
docker exec R2 ip addr add 140.113.1.1/24 dev R2hRveth
docker exec h1 ip addr add 192.168.1.2/24 dev h1R1veth
docker exec h2 ip addr add 192.168.2.2/24 dev h2R1veth
docker exec hR ip addr add 140.113.1.2/24 dev hRR2veth

docker exec R1 ip link set R1R2veth up
docker exec R1 ip link set R1h1veth up
docker exec R1 ip link set R1h2veth up
docker exec R2 ip link set R2R1veth up
docker exec R2 ip link set R2hRveth up
docker exec h1 ip link set h1R1veth up
docker exec h2 ip link set h2R1veth up
docker exec hR ip link set hRR2veth up

docker exec h1 ip route add default via 192.168.1.1
docker exec h2 ip route add default via 192.168.2.1
docker exec hR ip route add default via 140.113.1.1

quagga_setup R1
quagga_setup R2