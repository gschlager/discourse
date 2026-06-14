# Generator image for phpBB schema fixtures. The PHP version is a build arg
# because phpBB's legacy DB drivers don't run on modern PHP — each phpBB release
# needs a compatible interpreter (see generate.sh for the matrix). Used only to
# (re)generate the committed fixtures, never in CI or the test path.
ARG PHP_VERSION=7.4
FROM php:${PHP_VERSION}-cli

# `mysqli` + `pgsql` so phpBB's db_tools can materialize into both backends;
# `git`/`unzip` for composer.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends git unzip libpq-dev default-mysql-client postgresql-client; \
    docker-php-ext-install mysqli pdo_mysql pgsql pdo_pgsql; \
    rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1

WORKDIR /work
COPY materialize.php /work/materialize.php
