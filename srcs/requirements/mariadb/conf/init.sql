-- --------------------------------------------------------------------------
-- Use mysql database
-- --------------------------------------------------------------------------
-- mysql: Database that contains MariaDB system tables
--        Stores users, privileges, settings, and so on
USE mysql;

-- --------------------------------------------------------------------------
-- Set root password
-- --------------------------------------------------------------------------
-- ALTER USER: Modify an existing user
-- 'root'@'localhost': the root user (only from localhost)
-- IDENTIFIED BY: set a password
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';

-- --------------------------------------------------------------------------
-- Improve security
-- --------------------------------------------------------------------------
-- Deletion of anonymous users
--  Remove users whose User column is an empty string (anonymous users)
--  Anonymous users can access without authentication, posing a security risk
DELETE FROM mysql.user WHERE User='';

-- Disable remote root login
-- Host NOT IN ('localhost', '127.0.0.1', '::1'):
--   localhost: host name
--   127.0.0.1: IPv4 loopback address
--   ::1: IPv6 loopback address
-- This ensures root can only be accessed locally
DELETE FROM mysql.user
    WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

-- Deleting the test database
-- Remove the 'test' database if it exists
-- IF EXISTS: won't error if it does not exist
DROP DATABASE IF EXISTS test;

-- Remove privileges for databases starting with 'test' or 'test_'
-- Db='test\_%': SQL LIKE pattern (starts with test_)
DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';

-- --------------------------------------------------------------------------
-- Apply the changes
-- --------------------------------------------------------------------------
-- If you don't run this, the changes won't take effect
FLUSH PRIVILEGES;

-- --------------------------------------------------------------------------
-- Create a WordPress database
-- --------------------------------------------------------------------------
-- IF NOT EXISTS: won't error if it already exists
CREATE DATABASE IF NOT EXISTS `${MYSQL_DATABASE}`;

-- --------------------------------------------------------------------------
-- Create a user for WordPress (restricted permissions)
-- --------------------------------------------------------------------------
-- '${MYSQL_USER}'@'%':
--   '${MYSQL_USER}': username (bash variable expansion)
--   @'%': can connect from any host
--         % is a wildcard (any hostname/IP address)
--         valid only within Docker internal network (not exposed externally)
-- IDENTIFIED BY '${MYSQL_PASSWORD}': set the password
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';

-- ${MYSQL_DATABASE}`.*:
--   database_name.table_name
--   .* = all tables
-- TO '${MYSQL_USER}'@'%': which user to grant the privileges to
GRANT ALL PRIVILEGES ON `${MYSQL_DATABASE}`.* TO '${MYSQL_USER}'@'%';

-- --------------------------------------------------------------------------
-- Apply the changes
-- --------------------------------------------------------------------------
FLUSH PRIVILEGES;
