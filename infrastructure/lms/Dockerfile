FROM php:8.3-cli-alpine

RUN apk add --no-cache bash curl git unzip sqlite-dev \
    && docker-php-ext-install pdo_sqlite

COPY --from=composer:2.7 /usr/bin/composer /usr/bin/composer

WORKDIR /workspace/example-lms-client/lms-laravel

COPY entrypoint.sh /usr/local/bin/lms-entrypoint
RUN chmod +x /usr/local/bin/lms-entrypoint

CMD ["/usr/local/bin/lms-entrypoint"]
