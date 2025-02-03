#!/bin/sh

# Update package list
apk update

# Install PHP and required extensions
apk add --no-cache \
    curl \
    libgcc \
    libstdc++ \
    icu-libs \
    gcompat \
    jq \
    bash \
    git \
    php83 \
    php83-curl \
    php83-openssl \
    php83-iconv \
    php83-mbstring \
    php83-phar \
    php83-dom \
    php83-tokenizer \
    php83-xml \
    php83-xmlwriter \
    libc6-compat \
    libffi-dev \
    build-base \

# Install Java 21
apk add --no-cache openjdk21
#--repository=http://dl-cdn.alpinelinux.org/alpine/edge/community/

# Install Composer
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

curl -fsSL https://unofficial-builds.nodejs.org/download/release/v20.10.0/node-v20.10.0-linux-x64-musl.tar.gz | tar -xz

mv node-v20.10.0-linux-x64-musl /usr/local/nodejs
ln -s /usr/local/nodejs/bin/node /usr/bin/node
ln -s /usr/local/nodejs/bin/npm /usr/bin/npm

# Verify installations
echo "\nChecking installed versions:"
php -v
java -version
composer --version
