FROM ubuntu
MAINTAINER leifj@sunet.se
RUN apt-get update
RUN apt-get -y install apache2 libapache2-mod-shib2 ssl-cert augeas-tools php-http libapache2-mod-php5
RUN a2enmod rewrite
RUN a2enmod ssl
RUN a2enmod shib2
RUN a2enmod proxy
RUN a2enmod proxy_http
RUN a2enmod proxy_balancer
RUN a2enmod lbmethod_byrequests
RUN a2enmod headers
ENV SP_HOSTNAME ac.example.com
ENV SP_CONTACT noc@nordu.net
ENV SP_ABOUT /about
ENV METADATA_SIGNER md-signer.crt
ENV APPSERVERS "app1.example.com app2.example.com"
RUN rm -f /etc/apache2/sites-available/*
RUN rm -f /etc/apache2/sites-enabled/*
ADD start.sh /start.sh
RUN chmod a+rx /start.sh
ADD md-signer.crt /etc/shibboleth/md-signer.crt
ADD attribute-map.xml /etc/shibboleth/attribute-map.xml
EXPOSE 443
EXPOSE 80
ENTRYPOINT ["/start.sh"]
