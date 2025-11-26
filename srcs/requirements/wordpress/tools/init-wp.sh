#!/bin/bash
# ============================================================================
# WordPress Setup Script
# ============================================================================
set -e

echo "========================================="
echo "WordPress Initialization Script"
echo "========================================="

# ============================================================================
# STEP 1: Read secrets and validate environment variables
# ============================================================================
echo "[1/5] Loading configuration and secrets..."

read_secret() {
    local secret_name="$1"
    local secret_file="/run/secrets/${secret_name}"
    
    if [ -f "${secret_file}" ]; then
        cat "${secret_file}"
        echo "  ✓ Loaded secret: ${secret_name}" >&2
    else
        echo "ERROR: secret '${secret_name}' is not set" >&2
        echo ""
    fi
}

# Read secrets
export MYSQL_PASSWORD=$(read_secret "db_password")
if [ -z "${MYSQL_PASSWORD}" ]; then
    echo "ERROR: db_password is required" >&2
    exit 1
fi

export WP_ADMIN_PASSWORD=$(read_secret "wp_admin_password")
if [ -z "${WP_ADMIN_PASSWORD}" ]; then
    echo "ERROR: wp_admin_password is required" >&2
    exit 1
fi

export WP_USER_PASSWORD=$(read_secret "wp_user_password")
if [ -z "${WP_USER_PASSWORD}" ]; then
    echo "ERROR: wp_user_password is required" >&2
    exit 1
fi

# Validate required environment variables
if [ -z "${MYSQL_DATABASE:-}" ]; then
    echo "ERROR: Environment variable MYSQL_DATABASE is required" >&2
    exit 1
fi

if [ -z "${MYSQL_USER:-}" ]; then
    echo "ERROR: Environment variable MYSQL_USER is required" >&2
    exit 1
fi

if [ -z "${MYSQL_HOST:-}" ]; then
    echo "ERROR: Environment variable MYSQL_HOST is required" >&2
    exit 1
fi

if [ -z "${DOMAIN_NAME:-}" ]; then
    echo "ERROR: Environment variable DOMAIN_NAME is required" >&2
    exit 1
fi

if [ -z "${WP_ADMIN_USER:-}" ]; then
    echo "ERROR: Environment variable WP_ADMIN_USER is required" >&2
    exit 1
fi

if [ -z "${WP_ADMIN_EMAIL:-}" ]; then
    echo "ERROR: Environment variable WP_ADMIN_EMAIL is required" >&2
    exit 1
fi

if [ -z "${WP_USER:-}" ]; then
    echo "ERROR: Environment variable WP_USER is required" >&2
    exit 1
fi

if [ -z "${WP_USER_EMAIL:-}" ]; then
    echo "ERROR: Environment variable WP_USER_EMAIL is required" >&2
    exit 1
fi

if [ -z "${WP_TITLE:-}" ]; then
    echo "ERROR: Environment variable WP_TITLE is required" >&2
    exit 1
fi

echo "[1/5] ✓ Configuration loaded successfully"

# From this point on, using undefined variables will be treated as an error
set -u

# ============================================================================
# STEP 2: Wait for MariaDB and Redis to be ready (fallback check)
# ============================================================================
# Note: docker-compose healthcheck handles this via depends_on condition,
#       but we keep a fallback check for safety and manual container runs
echo "[2/5] Verifying MariaDB & Redis connection..."

MAX_RETRIES=30
RETRY_COUNT=0

until mysqladmin ping -h"${MYSQL_HOST}" -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --silent 2>/dev/null; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "ERROR: MariaDB connection failed after ${MAX_RETRIES} attempts" >&2
        exit 1
    fi
    echo "  Waiting for MariaDB... (${RETRY_COUNT}/${MAX_RETRIES})"
    sleep 2
done

echo "[2/5] ✓ MariaDB is ready"

RETRY_COUNT=0

until redis-cli -h redis ping 2>/dev/null | grep -q "PONG"; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "ERROR: Redis connection failed after ${MAX_RETRIES} attempts" >&2
        exit 1
    fi
    echo "  Waiting for Redis... (${RETRY_COUNT}/${MAX_RETRIES})"
    sleep 2
done

echo "[2/5] ✓ Redis is ready"

# ============================================================================
# STEP 3: Check if WordPress is already installed
# ============================================================================
# - Files remain due to persistent data
# - Prevent reinstallation & maintain database integrity
echo "[3/5] Checking WordPress installation status..."

if [ -f "wp-config.php" ]; then
    echo "[3/5] ✓ WordPress already installed - Skipping installation"
else
    echo "[3/5] WordPress not found - Starting installation..."
    
    # ------------------------------------------------------------------
    # Download WordPress
    # ------------------------------------------------------------------
    echo "[4/5] Downloading WordPress core files..."
    wp core download --allow-root
    echo "[4/5] ✓ WordPress downloaded"
    
    # ------------------------------------------------------------------
    # Create wp-config.php
    # ------------------------------------------------------------------
    echo "  Creating wp-config.php..."
    wp config create \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${MYSQL_PASSWORD}" \
        --dbhost="${MYSQL_HOST}" \
        --allow-root
    echo "  ✓ wp-config.php created"
    
    # ------------------------------------------------------------------
    # Install WordPress
    # ------------------------------------------------------------------
    # Register the site title, administrator user,
    # & other information in the database.
    echo "  Installing WordPress..."
    wp core install \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email \
        --allow-root
    echo "  ✓ WordPress installed"
    
    # ------------------------------------------------------------------
    # Create additional user
    # ------------------------------------------------------------------
    echo "  Creating additional user..."
    wp user create \
        "${WP_USER}" \
        "${WP_USER_EMAIL}" \
        --role=editor \
        --user_pass="${WP_USER_PASSWORD}" \
        --allow-root
    echo "  ✓ User '${WP_USER}' created"
    
    # ------------------------------------------------------------------
    # Configure Redis Cache
    # ------------------------------------------------------------------
    echo "  Configuring Redis cache..."
    
    wp config set WP_REDIS_HOST "redis" --allow-root
    wp config set WP_REDIS_PORT "6379" --raw --allow-root
    wp config set WP_CACHE "true" --raw --allow-root
    
    wp plugin install redis-cache --activate --allow-root
    wp redis enable --allow-root
    
    echo "  ✓ Redis cache configured"
    
    echo "[4/5] ✓ WordPress installation complete"
fi

# ============================================================================
# STEP 4: Set proper permissions
# ============================================================================
# Run every time, not just on install
# This ensures permissions are correct even after volume mount
# - To allow WordPress to create and edit files
# - To install plugins
# - To upload media
# - To create cache files
echo "[5/5] Setting file permissions..."
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
echo "[5/5] ✓ Permissions set"

# ============================================================================
# STEP 5: Clear sensitive variables and start PHP-FPM
# ============================================================================
unset MYSQL_PASSWORD WP_ADMIN_PASSWORD WP_USER_PASSWORD

echo "========================================="
echo "Starting PHP-FPM as PID 1..."
echo "========================================="

# Start PHP-FPM in foreground
exec php-fpm8.2 -F
