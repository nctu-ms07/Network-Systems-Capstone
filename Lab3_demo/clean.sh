#!/bin/bash
docker_rm() {
    if [ -n "$(docker ps -a -q)" ]; then
        docker rm -f $(docker ps -a -q)
    fi
}

docker_rm