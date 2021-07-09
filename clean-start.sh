#!/usr/bin/env sh

docker volume rm $(docker volume ls -f'name=^'"$(basename "$PWD")" --format='{{.Name}}')

## This still does not remove volumes
docker compose down --volumes --remove-orphans && 
docker compose up --remove-orphans --force-recreate
