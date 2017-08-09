# Build frontend assets
FROM node as frontend
WORKDIR /app

COPY package.json package-lock.json webpack.mix.js /app/
RUN npm install

COPY resources/assets /app/resources/assets
RUN npm run production

# Build backend source
FROM composer as backend
WORKDIR /app

COPY composer.json composer.lock /app/
RUN composer install  \
    --ignore-platform-reqs \
    --no-ansi --no-autoloader \
    --no-dev \
    --no-interaction \
    --no-scripts

COPY . /app/
RUN composer dump-autoload --optimize --classmap-authoritative

# Build app image
FROM php:apache as app
LABEL maintainer "Joel Shepherd"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        # apt-get packages here
    && rm -rf /var/lib/apt/lists/*

RUN docker-php-ext-install \
    mbstring \
    opcache \
    pdo_mysql
RUN pecl install -o -f redis \
    && rm -rf /tmp/pear \
    && docker-php-ext-enable redis

RUN a2enmod rewrite

ADD .docker/php.ini ${PHP_INI_DIR}/conf.d/99-overrides.ini
ADD .docker/apache2.conf /etc/apache2/sites-available/000-default.conf

WORKDIR /app
COPY --from=backend /app /app
COPY --from=frontend /app/public/dist /app/public/dist
RUN chgrp -R www-data /app/storage /app/bootstrap/cache && chmod -R ug+rwx /app/storage /app/bootstrap/cache