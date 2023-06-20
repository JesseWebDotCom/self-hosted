#!/bin/bash
# Deletes/removes all docker content

# containers
if [[ $(docker ps -a -q) ]]; then
    echo stopping containers...
    docker stop $(docker ps -a -q) 
    echo removing containers...
    docker rm $(docker ps -a -q) 
fi

# images
if [[ $(docker images -a -q) ]]; then
    echo deleting images...
    docker rmi -f $(docker images -a -q)
fi

# networks
if [[ $(docker network ls | wc -l | xargs) != '4' ]]; then
    echo pruning networks...
    docker network prune --force
fi

# volumes
if [[ $(docker volume ls | wc -l | xargs) != '0' ]]; then
    echo pruning volumes...
    docker volume prune --force
fi