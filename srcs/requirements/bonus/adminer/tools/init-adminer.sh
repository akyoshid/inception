#!/bin/bash
set -e

echo "========================================="
echo "Starting Adminer on port 8080..."
echo "========================================="

# PHP built-in server (foreground mode)
exec php -S 0.0.0.0:8080 -t /var/www/html
