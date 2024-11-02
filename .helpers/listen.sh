#!/bin/sh
# Initial sync on startup to ensure /app is up to date with /blueprint_extensions
rsync -av --exclude=".blueprint" --include="*.blueprint*" --exclude="*" --delete /blueprint_extensions/ /app/

# Continuously watch for file changes in /blueprint_extensions
while inotifywait -r -e create,delete,modify,move --include=".*\\.blueprint$" /blueprint_extensions; do
    rsync -av --exclude=".blueprint" --include="*.blueprint*" --exclude="*" --delete /blueprint_extensions/ /app/
done