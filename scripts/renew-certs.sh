#!/usr/bin/env bash

### days before renew
DAYS_BEFORE_RENEW=15

### hostnames to check
HOSTNAMES_TO_CHECK=(
    "redirect.fabric-testbed.net,$(pwd)/cert/redirect"
    "dev.fabric-testbed.net,$(pwd)/cert/dev"
    "www.fabric-testbed.net,$(pwd)/cert/www"
    "fabric-testbed.net,$(pwd)/cert/base"
    "whatisfabric.net,$(pwd)/cert/whatisfabric"
)
#HOSTNAMES_TO_CHECK=( \
#    "redirect.fabric-testbed.net,/root/cert/redirect" \
#    "dev.fabric-testbed.net,/root/cert/dev" \
#    "www.fabric-testbed.net,/root/cert/www" \
#    "fabric-testbed.net,/root/cert/base" \
#    "whatisfabric.net,/root/cert/whatisfabric" \
#)

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
    # -- check cert format --
    # issuer=C=US, O=Internet2, CN=InCommon RSA Server CA 2
    # subject=C=US, ST=Kentucky, O=University of Kentucky, CN=redirect.fabric-testbed.net
    # notBefore=Feb  5 00:00:00 2024 GMT
    # notAfter=Feb  4 23:59:59 2025 GMT

    # issuer=C=US, O=Let's Encrypt, CN=R3
    # subject=CN=fabric-testbed.net
    # notBefore=Feb 20 20:47:02 2024 GMT
    # notAfter=May 20 20:47:01 2024 GMT

    is_lets_encrypt=0
    time_to_renew=0
    echo "### Checking certificate expiry for $1 ###"
    result="$(./ez_letsencrypt.sh -h "$1" -k)"
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
    ./ez_letsencrypt.sh -h "$1" \
        --certsdir "$2" \
        --webrootdir ./acme_challenge \
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
    if [[ "$renew_cert" == 1 ]]; then
        echo "-- Renew Cert? Yes"
    else
        echo "-- Renew Cert? No"
    fi
    if [[ $renew_cert == 1 ]]; then
        echo "-- Renewing certificate located at $cert_path"
        # stop redirect service
        echo "-- Stopping redirect service"
        cd ../ && docker compose stop && cd -
        # attempt to renew certificates
        echo "-- Renew Let's Encrypt certificate"
        renew_lets_encrypt_certificate "$host" "$cert_path"
        sleep 10s
        # restart redirect service
        echo "-- Restart redirect service"
        cd ../ && docker compose restart && cd -
        sleep 10s
        # verify new certificates
        echo "-- Verify new certificate"
        check_certificate_expiry "$host"
        new_cert=$?
        if [[ $new_cert != 0 ]]; then
            echo "-- [SUCCESS] Certificate successfully renewed"
        else
            echo "-- [ERROR] Unable to renew certificate"
        fi
    fi
done
