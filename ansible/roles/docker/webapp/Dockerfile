FROM php:8.0-apache

# Copier le code Greenshop
COPY ansible/roles/webapp/files/ /var/www/html/

# Installer les extensions PHP nécessaires
RUN apt-get update \
 && apt-get install -y libzip-dev zip \
 && docker-php-ext-install pdo_mysql zip \
 && a2enmod rewrite

# Permissions
RUN chown -R www-data:www-data /var/www/html \
 && chmod -R 750 /var/www/html

EXPOSE 80
