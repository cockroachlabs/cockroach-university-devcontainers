#!/bin/bash
set -e

# Get option values
COCKROACH_VERSION="${VERSION:-v25.1.2}"  # Updated default version
INSTALL_MOLT="${INSTALL_MOLT:-true}"
AUTO_START="${AUTO_START:-true}"
SQL_PORT="${PORT:-26257}"
UI_PORT="${UI:-8080}"

# --- Architecture Detection ---
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)
    COCKROACH_ARCH="linux-amd64"
    MOLT_URL="https://molt.cockroachdb.com/molt/cli/molt-latest.linux-amd64.tgz"
    ;;
  aarch64)
    COCKROACH_ARCH="linux-arm64"
    MOLT_URL="https://molt.cockroachdb.com/molt/cli/molt-latest.linux-arm64.tgz"
    ;;
  arm64)  # macOS (Apple Silicon)
    COCKROACH_ARCH="darwin-arm64"
    MOLT_URL="https://molt.cockroachdb.com/molt/cli/molt-latest.darwin-arm64.tgz"
    ;;
  *)
    echo "Error: Unsupported architecture: $ARCH" >&2
    exit 1
    ;;
esac

# Install CockroachDB
if ! command -v cockroach &> /dev/null; then
    echo "[*****] Installing CockroachDB..."
    COCKROACH_URL="https://binaries.cockroachdb.com/cockroach-${COCKROACH_VERSION}.${COCKROACH_ARCH}.tgz"
    curl -f -s -o cockroachdb.tgz "$COCKROACH_URL"  # Use -f to fail on HTTP errors
    tar -xzf cockroachdb.tgz
    cd cockroach-${COCKROACH_VERSION}.${COCKROACH_ARCH}
    # Handle different directory structures based on architecture
    # NOTE: I know is the same, but this will change in the future
    if [ "$COCKROACH_ARCH" = "darwin-arm64" ]; then
      sudo cp -i cockroach /usr/local/bin/
    else
      sudo cp -i cockroach /usr/local/bin/
    fi
    rm -rf cockroachdb.tgz cockroach-*  # Clean up downloaded files
    echo "[*****] CockroachDB installed."
else
    echo "[XXXXX] CockroachDB is already installed."
fi

# Initialize CockroachDB
if [ "$AUTO_START" = "true" ]; then
    echo "[*****] Setting up CockroachDB as a Service for autostart..."
    apt-get update && apt-get install -y curl supervisor
    
    mkdir -p /cockroach-data

    # Create supervisor config
    mkdir -p /etc/supervisor/conf.d

    cat <<EOF > /etc/supervisor/conf.d/cockroach.conf
[program:cockroach]
command=/usr/local/bin/cockroach start-single-node --insecure --store=/cockroach-data --listen-addr=0.0.0.0:$SQL_PORT --http-addr=0.0.0.0:$UI_PORT 
autostart=true
autorestart=true
stderr_logfile=/var/log/cockroach.err.log
stdout_logfile=/var/log/cockroach.out.log
EOF

    cat <<'SCRIPT' > /usr/local/bin/start-cockroach.sh
mkdir -p /var/log
exec supervisord -n -c /etc/supervisor/supervisord.conf
SCRIPT

    chmod +x /usr/local/bin/start-cockroach.sh
fi


# Install Molt (if requested)
if [ "$INSTALL_MOLT" = "true" ]; then
    if ! command -v molt &> /dev/null; then
        echo "Installing Molt..."
        curl -f -s -o molt.tgz "$MOLT_URL"
        tar -xzf molt.tgz
        # Since we know the structure of the Molt archive, we can copy directly:
        sudo cp -i molt /usr/local/bin/
        sudo cp -i replicator /usr/local/bin/
        rm -rf molt.tgz molt replicator # Clean up
        echo "Molt installed."
    else
        echo "Molt is already installed."
    fi
fi


echo "CockroachDB feature installation complete."

exit 0