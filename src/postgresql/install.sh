#!/bin/bash
set -e

# --- Configuration ---
PG_VERSION="${VERSION:-15}"
PG_PORT="${PORT:-5432}"
AUTO_START="${AUTO_START:-true}"
PG_USERS="${USERS:-none}"
PG_SQL="${SQL:-none}"


# --- Validate Supported Versions ---
SUPPORTED_VERSIONS=("11" "12" "13" "14" "15" "16" "17")
if [[ ! " ${SUPPORTED_VERSIONS[@]} " =~ " ${PG_VERSION} " ]]; then
    echo "[ERROR] Unsupported PostgreSQL version: $PG_VERSION"
    echo "Supported versions are: ${SUPPORTED_VERSIONS[*]}"
    exit 1
fi

echo "[INFO] Installing PostgreSQL $PG_VERSION on port $PG_PORT..."

# --- Install Dependencies ---
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y wget gnupg2 lsb-release curl supervisor sudo

# --- Add PostgreSQL Repository ---
sh -c "echo 'deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main' > /etc/apt/sources.list.d/pgdg.list"
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
apt-get update --allow-releaseinfo-change
apt-get install -y "postgresql-$PG_VERSION" "postgresql-contrib-$PG_VERSION"

echo "[✓] [INFO] PostgreSQL installed"

# --- PostgreSQL Paths ---
PG_DATA_DIR="/var/lib/postgresql/$PG_VERSION/main"
PG_CONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
PG_HBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"

# --- Update PostgreSQL Config ---
sed -i "s/^#listen_addresses =.*/listen_addresses = '*'/" "$PG_CONF"
sed -i "s/^port =.*/port = $PG_PORT/" "$PG_CONF"

# --- Update pg_hba.conf ---
NEW_AUTH_METHOD="scram-sha-256"
sed -i.bak '/^local\s\+all\s\+all\s\+/ s/peer$/'"$NEW_AUTH_METHOD"'/' "$PG_HBA"


# echo "host all all all trust" >> "$PG_HBA"

# --- Ensure Permissions ---
chown -R postgres:postgres /var/lib/postgresql
chmod 700 "$PG_DATA_DIR"

# --- Setup supervisord ---
if [ "$AUTO_START" = "true" ]; then
    echo "[INFO] Setting up PostgreSQL supervisor service..."

    mkdir -p /etc/supervisor/conf.d

    cat <<EOF > /etc/supervisor/conf.d/postgresql.conf
[program:postgresql]
command=/usr/lib/postgresql/$PG_VERSION/bin/postgres -D $PG_DATA_DIR --config-file=$PG_CONF
user=postgres
autostart=true
autorestart=true
stderr_logfile=/var/log/postgresql.err.log
stdout_logfile=/var/log/postgresql.out.log
EOF

    # Create wrapper script to start supervisor
    cat <<SCRIPT > /usr/local/bin/start-postgresql.sh
#!/bin/bash
set -e

exec supervisord -n -c /etc/supervisor/supervisord.conf
SCRIPT

    chmod +x /usr/local/bin/start-postgresql.sh
fi

# Only create user init script if PG_USERS is not 'none'
if [ "$PG_USERS" != "none" ]; then
    echo "[INFO] Creating init-pg-users.sh script..."
    cat << CREATESCRIPT > /usr/local/bin/create-pg-users.sh
#!/bin/bash
set -e
PG_USERS="${PG_USERS}" /usr/local/bin/init-pg-users.sh
CREATESCRIPT

    cat <<'EOSCRIPT' > /usr/local/bin/init-pg-users.sh
#!/bin/bash
set -e

PG_USERS="${PG_USERS:-none}"

if [ "$PG_USERS" = "none" ]; then
    echo "[INFO] No PG_USERS specified. Format: user1:pass1;user2:pass2. Skipping custom user creation."
    exit 0
fi

echo "[INFO] Creating PostgreSQL users from PG_USERS..."

# Loop through each user:pass pair separated by semicolon
for pair in $(echo "$PG_USERS" | tr ';' '\n'); do
    username="${pair%%:*}"
    password="${pair#*:}"

    if [ -z "$username" ] || [ -z "$password" ] || [ "$pair" = "$username" ]; then
        echo "[WARN] Skipping invalid user entry: $pair"
        continue
    fi

    echo "[INFO] Creating user '$username'..."
    sudo -u postgres psql -c "create role $username with superuser login password '$password';"  2>/dev/null
done

echo "[✓] [INFO] PostgreSQL is ready (Users created)." 
echo "[✓] [INFO] PostgreSQL users created successfully."
EOSCRIPT

    chmod +x /usr/local/bin/init-pg-users.sh
    chmod +x /usr/local/bin/create-pg-users.sh
fi


# --- Make vscode a passwordless sudoer (optional but useful) ---
if id "vscode" &>/dev/null; then
    echo "[INFO] Granting vscode passwordless sudo access..."
    usermod -aG sudo vscode
    echo "vscode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vscode
    chmod 0440 /etc/sudoers.d/vscode
fi


if [ "$PG_SQL" = "none" ]; then
    echo "[INFO] [BUILD PHASE] No SQL file specified. Skipping init SQL execution."
else
    cat << SQLSCRIPT > /usr/local/bin/init-pg-sql.sh
#!/bin/bash
set -e

PG_SQL="${PG_SQL:-none}" /usr/local/bin/run-pg-init-sql.sh 

SQLSCRIPT

    cat << 'EOSQL' > /usr/local/bin/run-pg-init-sql.sh
#!/bin/bash
set -e

PG_SQL="${PG_SQL:-none}"

if [ "$PG_SQL" = "none" ]; then
  echo "[INFO] No SQL file specified. Skipping init SQL execution."
  exit 0
fi

# Wait for PostgreSQL to be ready
echo "[INFO] Waiting for PostgreSQL to be ready before executing SQL..."
until pg_isready -q -h localhost -p 5432 -U postgres; do
  sleep 1
done

# Handle remote or local SQL file
if [[ "$PG_SQL" =~ ^https?:// ]]; then
  echo "[INFO] Downloading SQL file from: $PG_SQL"
  curl -fsSL "$PG_SQL" -o /tmp/init.sql || {
    echo "[ERROR] Failed to download SQL file from $PG_SQL"
    exit 1
  }
  SQL_PATH="/tmp/init.sql"
else
  if [ -f "$PG_SQL" ]; then
    SQL_PATH="$PG_SQL"
  elif [ -f "/workspaces/\$(basename \$PWD)/$PG_SQL" ]; then
    SQL_PATH="/workspaces/\$(basename \$PWD)/$PG_SQL"
  else
    echo "[ERROR] SQL file not found: $PG_SQL"
    exit 1
  fi
fi

echo "[INFO] Executing SQL file: $SQL_PATH"
sudo -u postgres psql -f "$SQL_PATH"

echo "[✓] SQL initialization complete."
EOSQL

    chmod +x /usr/local/bin/run-pg-init-sql.sh
    chmod +x /usr/local/bin/init-pg-sql.sh
fi




echo "[✓] [INFO] Feature PostgreSQL $PG_VERSION installed and configured on port $PG_PORT."
