Adobe Connect Frontend
======================

* shibboleth enabled for federated id
* apache 2.4+ubuntu 14
* support for keepalived loadbalancing
* automatic detection/reconfiguration of AC appservers

Building
-------

```bash
  # docker build -t docker-ac-frontend .
```

Running
-------

Make sure to install <public hostname>.key in /etc/ssl/private and <public hostname>.crt in /etc/ssl/certs. If you need to send a certificat chain, create that as /etc/ssl/certs/chain.crt. If this isn't done properly, the docker image will generate snake-oil certificates. If you already have a shibboleth SP key install that as /etc/ssl/private/shibsp.key and /etc/ssl/certs/shibsp.crt (these will also be generated if missing).

```bash
  # docker run -p 80:80 -p 443:443 -v /var/log:/var/log \
        -v /etc/ssl:/etc/ssl -e DEFAULT_LOGIN="md.nordu.net|sunet.se|kalmar2.org|idp.feide.no|haka.funet.fi" -e SP_HOSTNAME="<public hostname>" 
        -e APPSERVERS="appserver1 appserver2 appserver ..." docker-ac-frontend
```

Note that if you pull the image from a registry the name of the image (tag) may be different (eg registry.example.org/docker-ac-frontend). Setting the DEFAULT_LOGIN env variable selects the default session initiator to be used. A number of common DS and IdPs are available including feide, swamid, haka.

Keepalived config
-----------------

keepalived+ipvs doesn't play well inside docker so install keepalived and ipvs on the docker container host and run the following 

On frontend #1:

```bash
  # update-keepalived-conf -l <frontend-1-ip> -r <frontend-2-ip> \
       -v <virtual ip> -p <something random> -h <public hostname> -m
```

On frontend #2:

```bash
  # update-keepalived-conf -l <frontend-1-ip> -r <frontend-2-ip> \
       -v <virtual ip> -p <something random> -h <public hostname>
```

Remember to use the same random secret which is used for VRRP authentication. Afterwards (or if re-run) restart keepalived. 

