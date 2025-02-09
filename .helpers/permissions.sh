#!/bin/bash

# Array of paths that should be nginx owned
paths=(
    "/app/var"
    "/etc/nginx/http.d"
    "/app/storage/logs"
    "/var/log/nginx"
    "/blueprint_extensions"
)

for path in "${paths[@]}"; do
    OWNER=$(stat -c "%U" "$path")
    if [ "$OWNER" != "nginx" ]; then
        chown -R nginx: "$path"
    fi
done