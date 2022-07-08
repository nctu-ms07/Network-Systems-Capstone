#!/bin/bash

docker_build() {
    docker run --detach --interactive --privileged  \
    --network none --cap-add NET_ADMIN --cap-add NET_BROADCAST \
    --name ${1} lab3_demo
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
docker_build R3
docker_build R4
docker_build h1
docker_build h2
docker_build h3
docker_build h4

build_link R1 R2
build_link R2 R4
build_link R4 R3
build_link R3 R1

build_link R1 h1
build_link R2 h2
build_link R3 h3
build_link R4 h4

docker exec R1 ip addr add 172.19.0.2/24 dev R1h1veth
docker exec R2 ip addr add 172.20.0.2/24 dev R2h2veth
docker exec R3 ip addr add 172.21.0.2/24 dev R3h3veth
docker exec R4 ip addr add 172.22.0.2/24 dev R4h4veth
docker exec h1 ip addr add 172.19.0.3/24 dev h1R1veth
docker exec h2 ip addr add 172.20.0.3/24 dev h2R2veth
docker exec h3 ip addr add 172.21.0.3/24 dev h3R3veth
docker exec h4 ip addr add 172.22.0.3/24 dev h4R4veth

docker exec R1 ip addr add 140.113.0.2/24 dev R1R2veth
docker exec R2 ip addr add 140.113.0.3/24 dev R2R1veth
docker exec R1 ip addr add 140.114.0.2/24 dev R1R3veth
docker exec R3 ip addr add 140.114.0.3/24 dev R3R1veth
docker exec R2 ip addr add 140.115.0.2/24 dev R2R4veth
docker exec R4 ip addr add 140.115.0.3/24 dev R4R2veth
docker exec R3 ip addr add 140.116.0.2/24 dev R3R4veth
docker exec R4 ip addr add 140.116.0.3/24 dev R4R3veth

docker exec R1 ip link set R1h1veth up
docker exec R2 ip link set R2h2veth up
docker exec R3 ip link set R3h3veth up
docker exec R4 ip link set R4h4veth up
docker exec h1 ip link set h1R1veth up
docker exec h2 ip link set h2R2veth up
docker exec h3 ip link set h3R3veth up
docker exec h4 ip link set h4R4veth up

docker exec R1 ip link set R1R2veth up
docker exec R2 ip link set R2R1veth up
docker exec R1 ip link set R1R3veth up
docker exec R3 ip link set R3R1veth up
docker exec R2 ip link set R2R4veth up
docker exec R4 ip link set R4R2veth up
docker exec R3 ip link set R3R4veth up
docker exec R4 ip link set R4R3veth up

docker exec h1 ip route add default via 172.19.0.2
docker exec h2 ip route add default via 172.20.0.2
docker exec h3 ip route add default via 172.21.0.2
docker exec h4 ip route add default via 172.22.0.2

quagga_setup R1
quagga_setup R2
quagga_setup R3
quagga_setup R4