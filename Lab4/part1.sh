#!/bin/bash

docker_build() {
    docker run --detach --interactive --privileged  \
    --network none --cap-add NET_ADMIN --cap-add NET_BROADCAST \
    --name ${1} lab4
}

build_link() {
    ip link add ${1}${2} type veth peer name ${2}${1}
    
    ip link set ${1}${2} netns $(docker inspect --format='{{.State.Pid}}' ${1})
    ip link set ${2}${1} netns $(docker inspect --format='{{.State.Pid}}' ${2})
}

docker_build R1
docker_build R2
docker_build h1
docker_build h2
docker_build GWr
docker_build BRG1
docker_build BRG2
docker_build BRGr

build_link h1 BRG1
build_link h2 BRG2
build_link GWr BRGr
build_link R1 BRG1
build_link R1 BRG2
build_link R1 R2
build_link R2 BRGr

docker exec h1 ip addr add 10.0.1.1/24 dev h1BRG1
docker exec h2 ip addr add 10.0.1.2/24 dev h2BRG2
docker exec GWr ip addr add 10.0.1.254/24 dev GWrBRGr

docker exec R1 ip addr add 140.114.0.2/16 dev R1BRG1
docker exec R1 ip addr add 140.115.0.2/16 dev R1BRG2
docker exec R1 ip addr add 20.0.0.1/8 dev R1R2
docker exec R2 ip addr add 20.0.0.2/8 dev R2R1
docker exec R2 ip addr add 140.113.0.2/16 dev R2BRGr

docker exec BRG1 ip addr add 140.114.0.1/16 dev BRG1R1
docker exec BRG2 ip addr add 140.115.0.1/16 dev BRG2R1
docker exec BRGr ip addr add 140.113.0.1/16 dev BRGrR2

docker exec BRG1 ip addr add 10.0.1.3/24 dev BRG1h1
docker exec BRG2 ip addr add 10.0.1.4/24 dev BRG2h2
docker exec BRGr ip addr add 10.0.1.5/24 dev BRGrGWr

docker exec h1 ip link set h1BRG1 up
docker exec h2 ip link set h2BRG2 up
docker exec GWr ip link set GWrBRGr up
docker exec R1 ip link set R1BRG1 up
docker exec R1 ip link set R1BRG2 up
docker exec R1 ip link set R1R2 up
docker exec R2 ip link set R2BRGr up
docker exec BRG1 ip link set BRG1h1 up
docker exec BRG2 ip link set BRG2h2 up
docker exec BRGr ip link set BRGrGWr up
docker exec BRG1 ip link set BRG1R1 up
docker exec BRG2 ip link set BRG2R1 up
docker exec R2 ip link set R2R1 up
docker exec BRGr ip link set BRGrR2 up

docker exec R1 sysctl net.ipv4.ip_forward=1
docker exec R1 sysctl -p
docker exec R2 sysctl net.ipv4.ip_forward=1
docker exec R2 sysctl -p
docker exec BRG1 sysctl net.ipv4.ip_forward=1
docker exec BRG1 sysctl -p
docker exec BRG2 sysctl net.ipv4.ip_forward=1
docker exec BRG2 sysctl -p
docker exec BRGr sysctl net.ipv4.ip_forward=1
docker exec BRGr sysctl -p

docker exec h1 ip route add default via 10.0.1.254
docker exec h2 ip route add default via 10.0.1.254

#docker exec R1 ip route add 140.114.0.0/16 via 140.114.0.1
#docker exec R1 ip route add 140.115.0.0/16 via 140.115.0.1
docker exec R1 ip route add 140.113.0.0/16 via 20.0.0.2
docker exec R2 ip route add 140.114.0.0/16 via 20.0.0.1
docker exec R2 ip route add 140.115.0.0/16 via 20.0.0.1
#docker exec R2 ip route add 140.113.0.0/16 via 140.113.0.1

docker exec BRG1 ip route add 140.113.0.0/16 via 140.114.0.2
docker exec BRG2 ip route add 140.113.0.0/16 via 140.115.0.2
docker exec BRGr ip route add 140.114.0.0/16 via 140.113.0.2
docker exec BRGr ip route add 140.115.0.0/16 via 140.113.0.2

docker exec BRG1 ip link add GRETAP type gretap remote 140.113.0.1 local 140.114.0.1
docker exec BRG1 ip link set GRETAP up
docker exec BRG1 ip link add br0 type bridge
docker exec BRG1 ip link set BRG1h1 master br0
docker exec BRG1 ip link set GRETAP master br0
docker exec BRG1 ip link set br0 up

docker exec BRG2 ip link add GRETAP type gretap remote 140.113.0.1 local 140.115.0.1
docker exec BRG2 ip link set GRETAP up
docker exec BRG2 ip link add br0 type bridge
docker exec BRG2 ip link set BRG2h2 master br0
docker exec BRG2 ip link set GRETAP master br0
docker exec BRG2 ip link set br0 up

docker exec BRGr ip link add GRETAP-BRG1 type gretap remote 140.114.0.1 local 140.113.0.1
docker exec BRGr ip link set GRETAP-BRG1 up

docker exec BRGr ip link add GRETAP-BRG2 type gretap remote 140.115.0.1 local 140.113.0.1
docker exec BRGr ip link set GRETAP-BRG2 up

docker exec BRGr ip link add br0 type bridge
docker exec BRGr ip link set BRGrGWr master br0
docker exec BRGr ip link set GRETAP-BRG1 master br0
docker exec BRGr ip link set GRETAP-BRG2 master br0
docker exec BRGr ip link set br0 up