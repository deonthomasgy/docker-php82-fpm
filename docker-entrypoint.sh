#!/bin/bash
set -e

# Fix permissions on mounted volumes
# These paths match the volume mounts in docker-compose.yml
VOLUMES=(
    "/home/thomas/WEBDEV/mintage/storage/logs"
    "/home/thomas/WEBDEV/mintage/storage/backups"
    "/home/thomas/WEBDEV/mintage/storage/app/imports"
    "/home/thomas/WEBDEV/mintage/database/snapshots"
)

# Create directories (running as root, so no ownership changes needed)
for VOLUME in "${VOLUMES[@]}"; do
    if [ ! -d "$VOLUME" ]; then
        mkdir -p "$VOLUME"
    fi
done

# Ensure laravel.log exists
LOG_FILE="/home/thomas/WEBDEV/mintage/storage/logs/laravel.log"
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
fi

# Execute the original command (PHP-FPM)
exec "$@"
