#!/bin/bash
COMMAND=$1
if [ $COMMAND == "translate" ]; then
    echo "docker-main-decode-parallel.sh ${@:2}"
    bash /app/scripts/docker-main-decode-parallel.sh "${@:2}"
fi
