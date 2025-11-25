#!/bin/bash
# ============================================================================
# MariaDB Initialization Script for Inception Project
# ============================================================================
# This script does the following:
# 1. Reads the password from Docker Secrets or environment variables
# 2. Initializes the MariaDB data directory (only on first run)
# 3. Creates the database and user
# 4. Starts the MariaDB server as PID 1
# ============================================================================

set -e  # Exit immediately if any command fails

echo "========================================="
echo "MariaDB Initialization Script"
echo "========================================="

# ============================================================================
# STEP 1: Read the password from Docker Secrets or environment variables
# ============================================================================
echo "[1/7] Loading configuration and secrets..."

read_secret() {
    # 1st argument: Secret name
    local secret_name="$1"
    
    # Path to the secret file
    # Docker Compose mounts secrets to /run/secrets/
    local secret_file="/run/secrets/${secret_name}"
    
    # Check if the Secret file exists
    if [ -f "${secret_file}" ]; then
        cat "${secret_file}"
        # Debug message for debugging purposes (do not display passwords)
        echo "  ✓ Loaded secret: ${secret_name}" >&2
    else
        echo "ERROR: secret '${secret_name}' is not set" >&2
        # Return an empty string (errors will be checked later)
        echo ""
    fi
}

# Password for root
export MYSQL_ROOT_PASSWORD=$(read_secret "db_root_password")
if [ -z "${MYSQL_ROOT_PASSWORD}" ]; then
    echo "ERROR: Root password is required" >&2
    exit 1
fi

# Password for WordPress user
export MYSQL_PASSWORD=$(read_secret "db_password")
if [ -z "${MYSQL_PASSWORD}" ]; then
    echo "ERROR: User password is required" >&2
    exit 1
fi

# Non-sensitive information (environment variables) is passed
#  from the environment section of docker-compose.yml

# Database name (e.g., wordpress)
if [ -z "${MYSQL_DATABASE:-}" ]; then
    echo "ERROR: Environment variable MYSQL_DATABASE is required" >&2
    exit 1
fi

# Username for WordPress user (e.g., wp_user)
if [ -z "${MYSQL_USER:-}" ]; then
    echo "ERROR: Environment variable MYSQL_USER is required" >&2
    exit 1
fi

# All configuration values have been loaded
echo "[1/7] ✓ Configuration loaded successfully"

# From this point on, using undefined variables will be treated as an error
set -u

# ============================================================================
# STEP 2: Create runtime directory (required every time)
# ============================================================================
# This directory is needed for the socket file
# It's in tmpfs, so it disappears when the container stops
mkdir -p /var/run/mysqld
chown mysql:mysql /var/run/mysqld

# ============================================================================
# STEP 3: Check if this is the first run
# ============================================================================
# The mysql directory is created during first initialization
# If it doesn't exist, we need to initialize the database

if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "[2/7] First run detected - Initializing MariaDB data directory..."
    
    # ------------------------------------------------------------------
    # Create data directory
    # ------------------------------------------------------------------
    
    # Data directory
    # Where MariaDB's data files (tables, indexes, etc.) are stored
    mkdir -p /var/lib/mysql
    
    # ------------------------------------------------------------------
    # Set proper owner
    # ------------------------------------------------------------------
    # MariaDB runs as the 'mysql' user
    # Therefore these directories must be owned by mysql:mysql
    # -R: recursive (all files inside the directory)
    # mysql:mysql: user:group
    chown -R mysql:mysql /var/lib/mysql
    
    # ------------------------------------------------------------------
    # Initialize the data directory
    # ------------------------------------------------------------------
    # mysql_install_db: Create MariaDB system tables
    # --user=mysql: Run as the mysql user
    # --datadir=/var/lib/mysql: Path to the data directory
    # > /dev/null: Discard standard output (hide progress messages)
    # 2>&1: Redirect standard error to standard output
    mysql_install_db \
        --user=mysql \
        --datadir=/var/lib/mysql \
        > /dev/null 2>&1
    
    echo "[2/7] ✓ Data directory initialized successfully"

    # ============================================================================
    # STEP 3: Start MariaDB temporarily for configuration
    # ============================================================================
    echo "[3/7] Configuring MariaDB (creating databases and users)..."
    # --skip-networking:
    #   Do not accept TCP/IP network connections
    #   In other words, the server will be in a state
    #    where it can only be connected to
    #    from localhost socket connections (--socket=...).
    #   This is to prevent external access during initial setup.
    # --socket=/var/run/mysqld/mysqld.sock:
    #   Specify the path to the socket file
    #   Later, the mysql and mysqladmin commands
    #    will connect to the server via this socket
    # &(End-of-line):
    #   Means to start the command as a background job.
    #   This allows the script to proceed to the next line
    #    without waiting for mysqld to exit.
    # mysqld may take some time to finish starting up
    mysqld --user=mysql \
           --skip-networking \
           --socket=/var/run/mysqld/mysqld.sock &

    # $! is the PID of the process most recently started in the background.
    # This is for later waiting with wait "$pid" or for use in error handling.
    pid="$!"

    # Waiting for startup (wait up to 30 seconds)
    for i in {30..0}; do
        # mysqladmin: command to send administrative commands to the server
        # ping: checks whether the server can respond
        # --user=root: connect as the root user
        # --socket: connect to the socket file specified when mysqld was started
        # If mysqladmin ping succeeds,
        #  MariaDB is already running, so break exits the loop.
        if mysqladmin \
            --user=root \
            --socket=/var/run/mysqld/mysqld.sock \
            ping > /dev/null 2>&1; then
            break
        fi
        echo "  Waiting for MariaDB to be ready... ($i)"
        sleep 1
    done

    # If the value of i is "0" after exiting the loop,
    #  it is judged that it did not start even after waiting 30 seconds.
    if [ "$i" = "0" ]; then
        echo "ERROR: MariaDB did not start" >&2
        exit 1
    fi

    echo "[3/7] Running init.sql..."
    # Expand environment variables and execute init.sql
    envsubst < /usr/local/etc/mariadb/init.sql | \
        mysql --user=root --socket=/var/run/mysqld/mysqld.sock

    echo "[3/7] ✓ MariaDB configured successfully"
    echo "[4/7] ✓ MariaDB configured via init.sql"
    echo "[5/7] ✓ Root password set"
    echo "[6/7] ✓ Database '${MYSQL_DATABASE}' and user '${MYSQL_USER}' created"

    # Stop the temporary MariaDB server
    # mysql server may take some time to finish shutting down
    mysqladmin \
        --user=root \
        --password="${MYSQL_ROOT_PASSWORD}" \
        --socket=/var/run/mysqld/mysqld.sock \
        shutdown

    unset MYSQL_ROOT_PASSWORD
    unset MYSQL_PASSWORD

    wait "$pid" || true

else
    # Skip initialization (retain data)
    echo "[2/7] Data directory already exists - Skipping initialization"
fi

# ============================================================================
# STEP 4: Start the MariaDB server as PID 1
# ============================================================================
echo "[7/7] Starting MariaDB server as PID 1..."
echo "========================================="
echo "MariaDB is ready to accept connections"
echo "========================================="

# Normal behavior:
#   bash (PID 1) → starts mysqld → mysqld (PID X)
#   Result: bash is PID 1, mysqld is a child process
# 
# When using exec:
#   bash (PID 1) → exec mysqld → mysqld replaces PID 1
#   Result: the bash process disappears and mysqld becomes PID 1
# 
# Why it matters:
# 1. Signal handling:
#    - Docker’s stop command (SIGTERM) is sent to PID 1
#    - If PID 1 is mysqld, proper shutdown procedures will run
#    - If PID 1 is bash, signals may not be propagated correctly
# 
# 2. Avoiding zombie processes:
#    - PID 1 is responsible for reaping zombie processes
#    - If mysqld is PID 1, it can fulfill this responsibility
# 
# 3. Resource efficiency:
#    - Removes the unnecessary bash process
#    - Saves memory and CPU
# 
# --user=mysql: Run as mysql user (not root - security best practice)
# --skip-daemonize:
#  Prevent mysqld from forking into the background so it stays in the foreground
# --console: Log to stdout/stderr (better for Docker logging)
exec mysqld --user=mysql --skip-daemonize --console

# By using exec, this script's process is replaced by mysqld  
# Therefore, any lines after this will never be executed
