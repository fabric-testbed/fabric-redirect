# FABRIC Redirect

Redirect traffic from legacy FABRIC sites to portal using Nginx

## Legacy sites and redirect targets

All `http` traffic (port 80) is first redirected to `https` (port 443), then redirects occur as denoted below.

### redirect.fabric-testbed.net

- [https://redirect.fabric-testbed.net]() --> [https://portal.fabric-testbed.net]()

### dev.fabric-testbed.net

- [https://dev.fabric-testbed.net]() --> [https://portal.fabric-testbed.net]()
- [https://dev.fabric-testbed.net/events]() --> [https://learn.fabric-testbed.net/article-categories/events]()

### www.fabric-testbed.net

- [https://www.fabric-testbed.net]() --> [https://portal.fabric-testbed.net]()
- [https://www.fabric-testbed.net/events]() --> [https://learn.fabric-testbed.net/article-categories/events]()

### fabric-testbed.net

- [https://fabric-testbed.net]() --> [https://portal.fabric-testbed.net]()
- [https://fabric-testbed.net/events]() --> [https://learn.fabric-testbed.net/article-categories/events]()

### whatisfabric.net

- [https://whatisfabric.net]() --> [https://portal.fabric-testbed.net/about/about-fabric]()
- [https://whatisfabric.net/events]() --> [https://learn.fabric-testbed.net/article-categories/events]()


## Renew Let's Encrypt certificates

Many of the certificates are managed by Let's Encrypt, and as such are checked regularly for renewal.

A certificate renewal script named `renew-certs.sh` is in the `scripts/` directory and should be run periodically to check certificate status.

The script is set to make a renewal attempt if a Let's Encrypt certificate is found to be expiring within the next 15 or fewer days.

The script can be run manually or using a tool like `cron`.

### Safety features

- **Lock file** — prevents concurrent runs (`/tmp/fabric-redirect-renew.lock`)
- **Docker preflight check** — exits with a clear error if the Docker daemon is unavailable
- **Port conflict detection** — verifies `redirect-nginx` is stopped and port 80 is free before attempting renewal
- **Unreachable host detection** — warns and skips hosts when the certificate check returns empty output
- **Non-zero exit code on failure** — exits `1` if any renewal fails, enabling cron alerting

### Run script manually

```console
./renew-certs.sh
```

Example:

```console
$ ./renew-certs.sh
Run at: Sat Feb 28 21:39:58 UTC 2026
#############
### Checking certificate expiry for redirect.fabric-testbed.net ###
issuer=C = US, O = Internet2, CN = InCommon RSA Server CA 2
subject=C = US, ST = Kentucky, O = University of Kentucky, CN = fabric-other-services.fabric-testbed.net
notBefore=Sep 23 00:00:00 2025 GMT
notAfter=Sep 15 23:59:59 2026 GMT
-- [0] is_lets_encrypt
-- [0] time_to_renew
-- Renew Cert? No
### Checking certificate expiry for dev.fabric-testbed.net ###
issuer=C = US, O = Let's Encrypt, CN = E7
subject=CN = dev.fabric-testbed.net
notBefore=Feb 20 15:16:04 2026 GMT
notAfter=May 21 15:16:03 2026 GMT
-- [1] is_lets_encrypt
-- [0] time_to_renew
-- Renew Cert? No
### Checking certificate expiry for www.fabric-testbed.net ###
issuer=C = US, O = Let's Encrypt, CN = E8
subject=CN = www.fabric-testbed.net
notBefore=Feb 20 15:16:25 2026 GMT
notAfter=May 21 15:16:24 2026 GMT
-- [1] is_lets_encrypt
-- [0] time_to_renew
-- Renew Cert? No
### Checking certificate expiry for fabric-testbed.net ###
issuer=C = US, O = Let's Encrypt, CN = E8
subject=CN = fabric-testbed.net
notBefore=Feb 20 15:15:41 2026 GMT
notAfter=May 21 15:15:40 2026 GMT
-- [1] is_lets_encrypt
-- [0] time_to_renew
-- Renew Cert? No
### Checking certificate expiry for whatisfabric.net ###
issuer=C = US, O = Let's Encrypt, CN = E7
subject=CN = whatisfabric.net
notBefore=Feb 20 15:13:55 2026 GMT
notAfter=May 21 15:13:54 2026 GMT
-- [1] is_lets_encrypt
-- [0] time_to_renew
-- Renew Cert? No
```

### Run script using `cron`

Using `crontab -e`, set up a cron job to check the renewal status of Let's Encrypt certificates daily at midnight EST (5:00 UTC). Output is logged to a file, and a Slack notification is sent if any renewal fails.

```console
0 5 * * * /home/nrig-service/fabric-redirect/scripts/renew-certs.sh >> /home/nrig-service/fabric-redirect/scripts/fabric-redirect.log 2>&1 || curl -X POST -H 'Content-type: application/json' --data '{"text":"[FABRIC] Cert renewal failed — check logs"}' https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

> **Note:** The cron entry must be a single line. The `||` ensures the `curl` command only runs when the script exits with a non-zero status.

Alternatively, to receive email alerts instead of Slack notifications, add a `MAILTO` line above the cron entry:

```console
MAILTO=your@email.com
0 5 * * * /home/nrig-service/fabric-redirect/scripts/renew-certs.sh >> /home/nrig-service/fabric-redirect/scripts/fabric-redirect.log 2>&1
```
