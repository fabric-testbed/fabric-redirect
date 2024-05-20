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

The script is set to make a renewal atempt if a Let's Encrypt certificate is found to be expiring within the next 15 or fewer days.

The script can be run manually or using a tool like `cron`

### Run script manually

```console
./renew-certs.sh
```

Example:

```console
$ ./renew-certs.sh
Run at: Mon May 20 14:43:30 UTC 2024
#############
### Checking certificate expiry for redirect.fabric-testbed.net ###
issuer=C = US, O = Internet2, CN = InCommon RSA Server CA 2
subject=C = US, ST = Kentucky, O = University of Kentucky, CN = redirect.fabric-testbed.net
notBefore=Feb  5 00:00:00 2024 GMT
notAfter=Feb  4 23:59:59 2025 GMT
-- [0] is_lets_encrypt
-- [0] time_to_renew
-- Renew Cert? No
### Checking certificate expiry for dev.fabric-testbed.net ###
issuer=C = US, O = Let's Encrypt, CN = R3
subject=CN = dev.fabric-testbed.net
notBefore=May 17 12:40:32 2024 GMT
notAfter=Aug 15 12:40:31 2024 GMT
-- [1] is_lets_encrypt
-- [0] time_to_renew
-- Renew Cert? No
### Checking certificate expiry for www.fabric-testbed.net ###
issuer=C = US, O = Let's Encrypt, CN = R3
subject=CN = www.fabric-testbed.net
notBefore=May 17 12:41:13 2024 GMT
notAfter=Aug 15 12:41:12 2024 GMT
-- [1] is_lets_encrypt
-- [0] time_to_renew
-- Renew Cert? No
### Checking certificate expiry for fabric-testbed.net ###
issuer=C = US, O = Let's Encrypt, CN = R3
subject=CN = fabric-testbed.net
notBefore=May 17 12:41:58 2024 GMT
notAfter=Aug 15 12:41:57 2024 GMT
-- [1] is_lets_encrypt
-- [0] time_to_renew
-- Renew Cert? No
### Checking certificate expiry for whatisfabric.net ###
issuer=C = US, O = Let's Encrypt, CN = R3
subject=CN = whatisfabric.net
notBefore=Mar 11 17:04:18 2024 GMT
notAfter=Jun  9 17:04:17 2024 GMT
-- [1] is_lets_encrypt
-- [0] time_to_renew
-- Renew Cert? No
```

### Run script using `cron`

Using `crontab` setup a cron job to check the renewal status of Let's Encrypt certificates daily at 1 am

```console
# Check renewal status of Let's Encrypt certificates at 1 am each day
0 1 * * * cd /home/nrig-service/fabric-redirect/scripts/; ./renew-certs.sh 2>&1 | tee -a /home/nrig-service/fabric-redirect.log
```

This will run using the `cron` service daily at 1 am and log the output to a file named `fabric-redirect.log`.
