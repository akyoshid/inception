#!/bin/bash
set -e

echo "========================================="
echo "Starting Redis Server..."
echo "========================================="

exec redis-server /etc/redis/redis.conf
