FROM pkpofficial/ojs:stable-3_5_0

USER root

COPY php-custom.ini /usr/local/etc/php/conf.d/99-ojs-custom.ini
COPY ojs-start-readonly.sh /usr/local/bin/ojs-start-readonly
COPY pkp-pre-start-readonly.sh /usr/local/bin/pkp-pre-start

RUN mkdir -p /var/www/files \
    && chown www-data:www-data /var/www/files \
    && printf '%s\n' 'SetEnvIf X-Forwarded-Proto "^https$" HTTPS=on' > /etc/apache2/conf-enabled/zzz-ojs-proxy-https.conf \
    && chmod 0755 /usr/local/bin/ojs-start-readonly /usr/local/bin/pkp-pre-start \
    && rm -f /var/www/html/config.inc.php \
    && ln -s /run/ojs/config.inc.php /var/www/html/config.inc.php \
    && chown -h www-data:www-data /var/www/html/config.inc.php

USER www-data
