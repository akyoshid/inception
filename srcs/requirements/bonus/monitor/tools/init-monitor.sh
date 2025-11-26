#!/bin/bash
set -e

echo "========================================="
echo "Starting Service Monitor..."
echo "========================================="

exec /app/venv/bin/python /app/monitor.py
