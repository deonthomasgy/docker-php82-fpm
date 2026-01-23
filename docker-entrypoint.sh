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

# Create directories and set ownership to thomas:thomas
for VOLUME in "${VOLUMES[@]}"; do
    if [ ! -d "$VOLUME" ]; then
        mkdir -p "$VOLUME"
    fi
    # Only chown if ownership is not already correct (idempotent check)
    if [ "$(stat -c '%U:%G' "$VOLUME" 2>/dev/null)" != "thomas:thomas" ]; then
        chown -R thomas:thomas "$VOLUME" || true
    fi
done

# Ensure laravel.log exists and has correct ownership
LOG_FILE="/home/thomas/WEBDEV/mintage/storage/logs/laravel.log"
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
fi
if [ "$(stat -c '%U:%G' "$LOG_FILE" 2>/dev/null)" != "thomas:thomas" ]; then
    chown thomas:thomas "$LOG_FILE" || true
fi

# Execute the original command (PHP-FPM)
exec "$@"
