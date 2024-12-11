#!/bin/bash
set -euo pipefail

trap 'echo "Interrupted"; exit 1' INT TERM

# Initial sync
rsync -av --exclude=".blueprint" --include="*.blueprint*" --exclude="*" --delete "/blueprint_extensions/" "/app/"

# Continuous monitor task
inotifywait -m -q \
  -e close_write,delete,moved_to,moved_from \
  --format '%e %w%f' \
  "/blueprint_extensions/" |
while read -r event filepath; do
    case "$filepath" in
        *.blueprint)
            case "$event" in
                CLOSE_WRITE,CLOSE|MOVED_TO)
                    if ! cp "$filepath" "/app/$(basename "$filepath")"; then
                        echo "Error copying: $filepath" >&2
                    else
                        echo "Updated: $filepath"
                    fi
                    ;;
                DELETE|MOVED_FROM)
                    if ! rm -f "/app/$(basename "$filepath")"; then
                        echo "Error removing: $filepath" >&2
                    else
                        echo "Removed: $filepath"
                    fi
                    ;;
            esac
            ;;
    esac
done
