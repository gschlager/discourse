# Generator image for phpBB schema fixtures. The PHP version is a build arg
# because phpBB's legacy DB drivers don't run on modern PHP — each phpBB release
# needs a compatible interpreter (see generate.sh for the matrix). Used only to
# (re)generate the committed fixtures, never in CI or the test path.
ARG PHP_VERSION=7.4
FROM php:${PHP_VERSION}-cli

# `mysqli` + `pgsql` so phpBB's db_tools can materialize into both backends;
# `git`/`unzip` for composer. (The schema dumps run inside the DB containers, so
# this image needs no MySQL/Postgres client.)
#
# The older PHP images are built on EOL Debian (e.g. 7.1 on buster), whose apt
# repos have moved to archive.debian.org — repoint at the archive before
# installing.
RUN set -eux; \
    for f in /etc/apt/sources.list /etc/apt/sources.list.d/*.list; do \
      [ -f "$f" ] || continue; \
      sed -i -e 's|http://deb.debian.org/debian|http://archive.debian.org/debian|g' \
             -e 's|http://security.debian.org/debian-security|http://archive.debian.org/debian-security|g' \
             -e 's|http://deb.debian.org/debian-security|http://archive.debian.org/debian-security|g' \
             -e '/-updates/d' "$f"; \
    done; \
    printf 'Acquire::Check-Valid-Until "false";\n' > /etc/apt/apt.conf.d/99archive; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl git unzip libpq-dev; \
    docker-php-ext-install mysqli pdo_mysql pgsql pdo_pgsql; \
    rm -rf /var/lib/apt/lists/*

# Composer 2.2 LTS is the last line supporting PHP 7.1 (which phpBB 3.0/3.1
# need); it also runs on 7.4/8.x, so it covers the whole version matrix.
COPY --from=composer:2.2 /usr/bin/composer /usr/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1

WORKDIR /work
COPY materialize.php /work/materialize.php
