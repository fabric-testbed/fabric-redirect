#!/usr/bin/env bash

### Resolve paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"

### Lock file to prevent concurrent runs
LOCK_FILE="/tmp/fabric-redirect-renew.lock"

cleanup() {
    rm -f "$LOCK_FILE"
}

if [ -f "$LOCK_FILE" ]; then
    echo "[ERROR] Another instance is already running (lock file: $LOCK_FILE). Exiting."
    exit 1
fi
touch "$LOCK_FILE"
trap cleanup EXIT

### Preflight: verify Docker is available
if ! docker info >/dev/null 2>&1; then
    echo "[ERROR] Docker daemon is not available. Exiting."
    exit 1
fi

### days before renew
DAYS_BEFORE_RENEW=15

### track overall success
HAD_ERRORS=0

### hostnames to check
HOSTNAMES_TO_CHECK=(
    "redirect.fabric-testbed.net,$PROJECT_ROOT/cert/redirect"
    "dev.fabric-testbed.net,$PROJECT_ROOT/cert/dev"
    "www.fabric-testbed.net,$PROJECT_ROOT/cert/www"
    "fabric-testbed.net,$PROJECT_ROOT/cert/base"
    "whatisfabric.net,$PROJECT_ROOT/cert/whatisfabric"
)

get_days_remaining() {
    # input format Jun  9 17:04:17 2024 GMT
    local INPUT_FORMAT="%b %d %H:%M:%S %Y %Z"
    local INPUT_DATE="$1"
    local OUTPUT_FORMAT="%s"
    local PLATFORM=$(uname)
    ts_now=$(date +"$OUTPUT_FORMAT")
    if [[ "$PLATFORM" == "Darwin" ]]; then
        # Mac OS X
        ts_expiry=$(date -j -f "$INPUT_FORMAT" "$INPUT_DATE" +"$OUTPUT_FORMAT")
    elif [[ "$PLATFORM" == "Linux" ]]; then
        # Linux
        ts_expiry=$(date -d "$INPUT_DATE" +"$OUTPUT_FORMAT")
    else
        # Unsupported system
        echo "Unsupported system"
    fi
    echo $(((ts_expiry - ts_now) / (60 * 60 * 24)))
}

check_certificate_expiry() {
    is_lets_encrypt=0
    time_to_renew=0
    echo "### Checking certificate expiry for $1 ###"
    result="$("$SCRIPT_DIR/ez_letsencrypt.sh" -h "$1" -k)"
    if [[ -z "$result" ]]; then
        echo "-- [WARNING] Certificate check returned empty output for $1 (host may be unreachable)"
        return 2
    fi
    while IFS= read -r line; do
        echo "$line"
        # determine if cert is Let's Encrypt generated
        if [[ "$line" == *"Let's Encrypt"* ]]; then
            is_lets_encrypt=1
        fi
        # determine if it time to renew the certificate
        if [[ "$line" == *"notAfter="* ]]; then
            days_remaining=$(get_days_remaining "$(echo "$line" | cut -d "=" -f 2)")
            if [[ $days_remaining -le $DAYS_BEFORE_RENEW ]]; then
                time_to_renew=1
            fi
        fi
    done <<<"$result"
    echo "-- ["$is_lets_encrypt"] is_lets_encrypt"
    echo "-- ["$time_to_renew"] time_to_renew"
    if [[ "$is_lets_encrypt" == 1 && "$time_to_renew" == 1 ]]; then
        return 1
    else
        return 0
    fi
}

renew_lets_encrypt_certificate() {
    docker stop letsencrypt_nginx && docker rm -fv letsencrypt_nginx
    "$SCRIPT_DIR/ez_letsencrypt.sh" -h "$1" \
        --certsdir "$2" \
        --webrootdir "$SCRIPT_DIR/acme_challenge" \
        --renew \
        --verbose
}

### main
echo "Run at: $(date)"
echo "#############"
for line in "${HOSTNAMES_TO_CHECK[@]}"; do
    host="$(echo "$line" | cut -d "," -f 1)"
    cert_path="$(echo "$line" | cut -d "," -f 2)"
    check_certificate_expiry "$host"
    renew_cert=$?
    if [[ "$renew_cert" == 2 ]]; then
        echo "-- [WARNING] Skipping $host due to certificate check failure"
        HAD_ERRORS=1
        continue
    fi
    if [[ "$renew_cert" == 1 ]]; then
        echo "-- Renew Cert? Yes"
    else
        echo "-- Renew Cert? No"
    fi
    if [[ $renew_cert == 1 ]]; then
        echo "-- Renewing certificate located at $cert_path"
        # stop redirect service
        echo "-- Stopping redirect service"
        docker compose -f "$COMPOSE_FILE" stop
        # verify redirect-nginx is actually stopped
        if docker ps --format '{{.Names}}' | grep -q '^redirect-nginx$'; then
            echo "-- [ERROR] redirect-nginx is still running after stop. Skipping renewal for $host."
            docker compose -f "$COMPOSE_FILE" up -d
            HAD_ERRORS=1
            continue
        fi
        # verify port 80 is free
        if lsof -i :80 -sTCP:LISTEN >/dev/null 2>&1; then
            echo "-- [ERROR] Port 80 is still in use. Skipping renewal for $host."
            docker compose -f "$COMPOSE_FILE" up -d
            HAD_ERRORS=1
            continue
        fi
        # attempt to renew certificates
        echo "-- Renew Let's Encrypt certificate"
        renew_lets_encrypt_certificate "$host" "$cert_path"
        sleep 10s
        # restart redirect service
        echo "-- Restart redirect service"
        docker compose -f "$COMPOSE_FILE" up -d
        sleep 10s
        # verify new certificates
        echo "-- Verify new certificate"
        check_certificate_expiry "$host"
        new_cert=$?
        if [[ $new_cert == 0 ]]; then
            echo "-- [SUCCESS] Certificate successfully renewed"
        else
            echo "-- [ERROR] Unable to renew certificate"
            HAD_ERRORS=1
        fi
    fi
done

if [[ $HAD_ERRORS != 0 ]]; then
    echo "[ERROR] One or more renewals had errors. See log above."
    exit 1
fi
