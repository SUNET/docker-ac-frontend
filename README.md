Adobe Connect Frontend
======================

* shibboleth enabled for federated id
* apache 2.4+ubuntu 14
* support for keepalived loadbalancing
* automatic detection/reconfiguration of AC appservers

Keepalived config
-----------------

keepalived+ipvs doesn't play well inside docker so install keepalived and ipvs on the docker container host and run the following 

On frontend #1:

  # update-keepalived-conf -l <frontend-1-ip> -r <frontend-2-ip> -v <virtual ip> -p <something random> -h <public hostname> -m

On frontend #2:

  # update-keepalived-conf -l <frontend-1-ip> -r <frontend-2-ip> -v <virtual ip> -p <something random> -h <public hostname>

Remember to use the same random secret which is used for VRRP authentication. Afterwards (or if re-run) restart keepalived. 
