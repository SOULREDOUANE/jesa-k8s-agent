#!/bin/bash
set -e

# Update package list and install dependencies
apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates apt-transport-https lsb-release curl wget git jq libicu-dev unzip gosu \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Add PHP repository (SURY) for latest PHP versions
curl -fsSL https://packages.sury.org/php/apt.gpg | tee /etc/apt/trusted.gpg.d/php.gpg > /dev/null
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/php.list

# Install PHP and required extensions
apt-get update && apt-get install -y --no-install-recommends \
    php-cli php-mbstring php-xml php-zip php-curl php-bcmath php-json php-mysql \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Verify PHP installation
php -v

# Install Composer
curl -sS https://getcomposer.org/installer | php \
    && mv composer.phar /usr/local/bin/composer \
    && chmod +x /usr/local/bin/composer

# Install Java
wget https://download.oracle.com/java/21/latest/jdk-21_linux-x64_bin.deb \
    && dpkg -i jdk-21_linux-x64_bin.deb \
    && rm -f jdk-21_linux-x64_bin.deb  # Remove installer to save space

# Install Kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm -f kubectl  # Remove installer

echo "All dependencies installed successfully!"
