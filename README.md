# docker-php82-fpm

Shared PHP 8.4 FPM image based on `serversideup/php`. The repository name is historical.

Current release: `princeamd/php84-fpm:8.4.27-r2`.

This release uses PHP 8.4.27 and disables session upload progress at startup via
`/usr/local/etc/php/conf.d/zz-session-security.ini` to mitigate CVE-2026-115560.
Ordinary file uploads remain enabled. Retain this setting until upgrading to a
PHP release that fixes the issue.

```sh
docker build -t princeamd/php84-fpm:8.4.27-r2 .
docker push princeamd/php84-fpm:8.4.27-r2
```

Pin application Dockerfiles and CI images to the release tag. Rebuild derived
application images and recreate running containers to apply the update.
