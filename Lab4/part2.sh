#!/bin/bash
docker exec BRGr ip link delete GRETAP-BRG1
docker exec BRGr ip link delete GRETAP-BRG2
docker exec BRGr ip link delete br0
docker cp main.cpp BRGr:/root/main.cpp
docker exec BRGr g++ -std=c++14 /root/main.cpp -o /root/main -lpcap
docker exec -it BRGr ./root/main