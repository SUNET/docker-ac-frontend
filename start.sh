#!/bin/sh

printenv

export HTTP_IP="127.0.0.1"
export HTTP_PORT="8080"
if [ "x${BACKEND_PORT}" != "x" ]; then
   HTTP_IP=`echo "${BACKEND_PORT}" | sed 's%/%%g' | awk -F: '{ print $2 }'`
   HTTP_PORT=`echo "${BACKEND_PORT}" | sed 's%/%%g' | awk -F: '{ print $3 }'`
fi

if [ "x${SP_HOSTNAME}" = "x" ]; then
   SP_HOSTNAME="`hostname`"
fi

if [ "x${SP_CONTACT}" = "x" ]; then
   SP_CONTACT="info@${SP_HOSTNAME}"
fi

if [ "x${SP_ABOUT}" = "x" ]; then
   SP_ABOUT="/about"
fi

if ["x${DEFAULT_LOGIN}" = "x" ]; then
   DEFAULT_LOGIN="md.nordu.net" 
fi

KEYDIR=/etc/ssl
mkdir -p $KEYDIR
export KEYDIR
if [ ! -f "$KEYDIR/private/shibsp.key" -o ! -f "$KEYDIR/certs/shibsp.crt" ]; then
   shib-keygen -o /tmp -h $SP_HOSTNAME 2>/dev/null
   mv /tmp/sp-key.pem "$KEYDIR/private/shibsp.key"
   mv /tmp/sp-cert.pem "$KEYDIR/certs/shibsp.crt"
fi

if [ ! -f "$KEYDIR/private/${SP_HOSTNAME}.key" -o ! -f "$KEYDIR/certs/${SP_HOSTNAME}.crt" ]; then
   make-ssl-cert generate-default-snakeoil --force-overwrite
   cp /etc/ssl/private/ssl-cert-snakeoil.key "$KEYDIR/private/${SP_HOSTNAME}.key"
   cp /etc/ssl/certs/ssl-cert-snakeoil.pem "$KEYDIR/certs/${SP_HOSTNAME}.crt"
fi

if [ ! -f "$KEYDIR/private/acp_api_secret.txt" ]; then
   base64 /dev/urandom | tr -d '/+' | dd bs=32 count=1 2>/dev/null > "$KEYDIR/private/acp_api_secret.txt"
fi
API_SECRET=$(cat $KEYDIR/private/acp_api_secret.txt)
export API_SECRET

CHAINSPEC=""
export CHAINSPEC
if [ -f "$KEYDIR/certs/${SP_HOSTNAME}.chain" ]; then
   CHAINSPEC="SSLCertificateChainFile $KEYDIR/certs/${SP_HOSTNAME}.chain"
elif [ -f "$KEYDIR/certs/${SP_HOSTNAME}-chain.crt" ]; then
   CHAINSPEC="SSLCertificateChainFile $KEYDIR/certs/${SP_HOSTNAME}-chain.crt"
elif [ -f "$KEYDIR/certs/${SP_HOSTNAME}.chain.crt" ]; then
   CHAINSPEC="SSLCertificateChainFile $KEYDIR/certs/${SP_HOSTNAME}.chain.crt"
elif [ -f "$KEYDIR/certs/chain.crt" ]; then
   CHAINSPEC="SSLCertificateChainFile $KEYDIR/certs/chain.crt"
elif [ -f "$KEYDIR/certs/chain.pem" ]; then
   CHAINSPEC="SSLCertificateChainFile $KEYDIR/certs/chain.pem"
fi


cat>/etc/shibboleth/shibboleth2.xml<<EOF
<SPConfig xmlns="urn:mace:shibboleth:2.0:native:sp:config"
    xmlns:conf="urn:mace:shibboleth:2.0:native:sp:config"
    xmlns:saml="urn:oasis:names:tc:SAML:2.0:assertion"
    xmlns:samlp="urn:oasis:names:tc:SAML:2.0:protocol"    
    xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata"
    clockSkew="180">

    <ApplicationDefaults entityID="https://${SP_HOSTNAME}/shibboleth"
                         REMOTE_USER="eppn persistent-id targeted-id">

        <Sessions lifetime="28800" timeout="3600" relayState="ss:mem"
                  checkAddress="false" handlerSSL="true" cookieProps="https">
            <Logout>SAML2 Local</Logout>
            <Handler type="MetadataGenerator" Location="/Metadata" signing="false"/>
            <Handler type="Status" Location="/Status" acl="127.0.0.1 ::1"/>
            <Handler type="Session" Location="/Session" showAttributeValues="false"/>
            <Handler type="DiscoveryFeed" Location="/DiscoFeed"/>

            <md:AssertionConsumerService Location="/SAML2/POST"
                                         index="1"
                                         Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
                                         conf:ignoreNoPassive="true" />

            <SessionInitiator type="Chaining" Location="/DS/nordu.net" id="md.nordu.net" relayState="cookie">
                <SessionInitiator type="SAML2" defaultACSIndex="1" acsByIndex="false" template="bindingTemplate.html"/>
                <SessionInitiator type="Shib1" defaultACSIndex="5"/>
                <SessionInitiator type="SAMLDS" URL="http://md.nordu.net/role/idp.ds"/>
            </SessionInitiator>

            <SessionInitiator type="Chaining" Location="/DS/nordu.net" id="nordu.net" relayState="cookie">
                <SessionInitiator type="SAML2" defaultACSIndex="1" acsByIndex="false" template="bindingTemplate.html"/>
                <SessionInitiator type="Shib1" defaultACSIndex="5"/>
                <SessionInitiator type="SAMLDS" URL="http://md.nordu.net/role/idp.ds"/>
            </SessionInitiator>

            <SessionInitiator type="Chaining" Location="/DS/ds.sunet.se" id="sunet.se" relayState="cookie">
                <SessionInitiator type="SAML2" defaultACSIndex="1" acsByIndex="false" template="bindingTemplate.html"/>
                <SessionInitiator type="Shib1" defaultACSIndex="5"/>
                <SessionInitiator type="SAMLDS" URL="http://md.nordu.net/swamid.ds"/>
            </SessionInitiator>

            <SessionInitiator type="Chaining" Location="/DS/kalmar2" id="kalmar2.org" relayState="cookie">
                <SessionInitiator type="SAML2" defaultACSIndex="1" acsByIndex="false" template="bindingTemplate.html"/>
                <SessionInitiator type="Shib1" defaultACSIndex="5"/>
                <SessionInitiator type="SAMLDS" URL="https://kalmar2.org/simplesaml/module.php/discopower/disco.php"/>
            </SessionInitiator>
 
            <SessionInitiator type="Chaining" Location="/Login/feide" id="idp.feide.no" relayState="cookie" entityID="https://idp.feide.no">
                <SessionInitiator type="SAML2" defaultACSIndex="1" acsByIndex="false" template="bindingTemplate.html"/>
            </SessionInitiator>

            <SessionInitiator type="Chaining" Location="/DS/haka.funet.fi" id="haka.funet.fi" relayState="cookie">
                <SessionInitiator type="SAML2" defaultACSIndex="1" acsByIndex="false" template="bindingTemplate.html"/>
                <SessionInitiator type="Shib1" defaultACSIndex="5"/>
                <SessionInitiator type="SAMLDS" URL="https://haka.funet.fi/shibboleth/WAYF"/>
            </SessionInitiator>

            <SessionInitiator type="Chaining" Location="/Login/idp.funet.fi" id="funet" 
                relayState="cookie" entityID="https://idp.funet.fi/esso">
                <SessionInitiator type="SAML2" acsIndex="1" template="bindingTemplate.html"/>
                <SessionInitiator type="Shib1" acsIndex="5"/>
            </SessionInitiator>
        </Sessions>

        <Errors supportContact="${SP_CONTACT}"
            helpLocation="${SP_ABOUT}"
            styleSheet="/shibboleth-sp/main.css"/>

        <Notify Channel="front" Location="https://${SP_HOSTNAME}/system/tenant/logout-notify.html" />

        <MetadataProvider type="XML" uri="http://md.nordu.net/role/idp.xml" backingFilePath="metadata.xml" reloadInterval="7200">
        </MetadataProvider>
        <AttributeExtractor type="XML" validate="true" reloadChanges="false" path="attribute-map.xml"/>
        <AttributeResolver type="Query" subjectMatch="true"/>
        <AttributeFilter type="XML" validate="true" path="attribute-policy.xml"/>
        <CredentialResolver type="File" key="$KEYDIR/private/shibsp.key" certificate="$KEYDIR/certs/shibsp.crt"/>
    </ApplicationDefaults>
    <SecurityPolicyProvider type="XML" validate="true" path="security-policy.xml"/>
    <ProtocolProvider type="XML" validate="true" reloadChanges="false" path="protocols.xml"/>
</SPConfig>
EOF

augtool -s --noautoload --noload <<EOF
set /augeas/load/xml/lens "Xml.lns"
set /augeas/load/xml/incl "/etc/shibboleth/shibboleth2.xml"
load
defvar si /files/etc/shibboleth/shibboleth2.xml/SPConfig/ApplicationDefaults/Sessions/SessionInitiator[#attribute/id="$DEFAULT_LOGIN"]
set \$si/#attribute/isDefault "true"
EOF

cat>/etc/apache2/sites-available/default.conf<<EOF
<VirtualHost *:80>
       ServerAdmin noc@sunet.se
       ServerName ${SP_HOSTNAME}
       DocumentRoot /var/www/

       RewriteEngine On
       RewriteCond %{HTTPS} off
       RewriteRule !_lvs.txt$ https://%{HTTP_HOST}%{REQUEST_URI}
</VirtualHost>
EOF

echo "connect" > /var/www/_lvs.txt

cat>/etc/apache2/sites-available/default-ssl.conf<<EOF
ServerName ${SP_HOSTNAME}
<VirtualHost *:443>
        ServerName ${SP_HOSTNAME}
        SSLProtocol All -SSLv2 -SSLv3
        SSLCompression Off
        SSLCipherSuite "EECDH+ECDSA+AESGCM EECDH+aRSA+AESGCM EECDH+ECDSA+SHA384 EECDH+ECDSA+SHA256 EECDH+aRSA+SHA384 EECDH+aRSA+SHA256 EECDH+AESGCM EECDH EDH+AESGCM EDH+aRSA HIGH !MEDIUM !LOW !aNULL !eNULL !LOW !RC4 !MD5 !EXP !PSK !SRP !DSS"
        SSLEngine On
        SSLCertificateFile $KEYDIR/certs/${SP_HOSTNAME}.crt
        ${CHAINSPEC}
        SSLCertificateKeyFile $KEYDIR/private/${SP_HOSTNAME}.key
        DocumentRoot /var/www/
        
        Alias /shibboleth-sp/ /usr/share/shibboleth/

        ServerName ${SP_HOSTNAME}
        ServerAdmin noc@nordu.net

        ProxyRequests On
 
        AddDefaultCharset utf-8

        RewriteEngine On
        #RewriteLog "/tmp/rewrite.log"
        #RewriteLogLevel 10
        RewriteCond %{HTTP_REFERER} !^$ [NC]
        RewriteRule ^/system/logout https://%{HTTP_HOST}/system/tenant/logout.php [R]

        HostnameLookups Off
        ErrorLog /proc/self/fd/2
        LogLevel warn
        LogFormat "%v:%p %h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" vhost_combined
        LogFormat "%h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\"" combined
        LogFormat "%h %l %u %t \"%r\" %>s %O" common
        LogFormat "%{Referer}i -> %U" referer
        LogFormat "%{User-agent}i" agent

        CustomLog /proc/self/fd/1 combined

        ServerSignature off

        AddDefaultCharset utf-8

        ProxyPass /balancer-manager !
        ProxyPass /Shibboleth.sso !
        ProxyPass /shibboleth-sp !
        ProxyPass /system/tenant !
        ProxyPass /secure !
        ProxyPass /errors !
        ProxyPass /login.html !
	ProxyPass /_lvs.txt !

        ProxyTimeout 60
        ProxyPass / balancer://connect/
        ProxyPassReverse / balancer://connect/
        ProxyPreserveHost On
        <Proxy balancer://connect>
EOF
n=`echo $APPSERVERS | wc -w`
f=`expr 100 / $n`
for h in $APPSERVERS; do
   hn=`echo $h | awk -F. '{print $1}'`
   echo "$h" | grep -q "[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}"
   hn=`[ $? -eq 0 ] && echo $h | awk -F. '{print $4}' || echo "$hn"`
   echo "           BalancerMember http://$h:8443 route=$hn loadfactor=$f" >> /etc/apache2/sites-available/default-ssl.conf
done

cat>>/etc/apache2/sites-available/default-ssl.conf<<EOF
           Order deny,allow
           #Deny from all
           Allow from all
        </Proxy>

        <Location /balancer-manager>
           SetHandler balancer-manager

           Order Deny,Allow
           Deny from all
           Allow from 109.105.104.0/24
           Allow from 193.11.3.30
           Allow from 62.102.145.131
           Allow from 127.0.0.1
        </Location> 

        <Location /secure>
           AuthType shibboleth
           ShibRequireSession On
           require valid-user
           Options +ExecCGI
           AddHandler cgi-script .cgi
        </Location>

        <LocationMatch "^/(system/login|admin)$">
           AuthType shibboleth
           ShibRequireSession On
           require valid-user
           RequestHeader set X-API-Token "${API_SECRET}"
           RequestHeader set X_REMOTE_USER %{eppn}e
           RequestHeader set EPPN %{eppn}e
           RequestHeader set GIVENNAME %{givenName}e
           RequestHeader set DISPLAYNAME %{displayName}e
           RequestHeader set SN %{sn}e
           RequestHeader set MAIL %{mail}e
           RequestHeader set AFFILIATION %{affiliation}e
           RequestHeader set UNSCOPED_AFFILIATION %{unscoped_affiliation}e
           RequestHeader set UNSCOPED_AFFILIATION %{unscoped-affiliation}e
        </LocationMatch>
        <LocationMatch "^/system/login-">
           AuthType shibboleth
           require shibboleth
           ShibRequireSession Off
           RequestHeader set X-API-Token "${API_SECRET}"
           RequestHeader set X_REMOTE_USER %{eppn}e
           RequestHeader set EPPN %{eppn}e
           RequestHeader set GIVENNAME %{givenName}e
           RequestHeader set DISPLAYNAME %{displayName}e
           RequestHeader set SN %{sn}e
           RequestHeader set MAIL %{mail}e
           RequestHeader set AFFILIATION %{affiliation}e
           RequestHeader set UNSCOPED_AFFILIATION %{unscoped_affiliation}e
           RequestHeader set UNSCOPED_AFFILIATION %{unscoped-affiliation}e
        </LocationMatch>

        <Location /favicon.ico>
           Satisfy any
           order deny,allow
           allow from all
        </Location>
</VirtualHost>
EOF

mkdir -p /var/www/system/tenant

cat>/var/www/login.html<<EOF
<html>
  <body>
     <h1>Login Test</h1>
     <ul>
        <li><a href="/Shibboleth.sso/DS/nordu.net?target=https://${SP_HOSTNAME}/">NORDUnet IdP Selector</a></li>
        <li><a href="/Shibboleth.sso/DS/ds.sunet.se?target=https://${SP_HOSTNAME}/">SWAMID (SUNET) IdP Selector</a></li>
        <li><a href="/Shibboleth.sso/DS/kalmar2?target=https://${SP_HOSTNAME}/">Kalmar2 IdP Selector</a></li>
        <li><a href="/Shibboleth.sso/Login/feide?target=https://${SP_HOSTNAME}/">Feide</a></li>
        <li><a href="/Shibboleth.sso/DS/haka.funet.fi?target=https://${SP_HOSTNAME}/">Haka (FUNET) IdP Selector</a></li>
        <li><a href="/Shibboleth.sso/Login/idp.funet.fi?target=https://${SP_HOSTNAME}/">FUNET Guest IdP</a></li>
     </ul>
  </body>
</html>
EOF

cat>/var/www/system/tenant/logout.html<<EOF
<!DOCTYPE html>
<html>
  <head>
    <title>Logout Adobe Connect</title>
  </head>
  <body>
    <script>
      var redirect = function redirect() {
        location.href="https://${SP_HOSTNAME}/Shibboleth.sso/Logout";
      };

      var xhr = new XMLHttpRequest();
      xhr.addEventListener("load",redirect);
      xhr.addEventListener("timeout", redirect);
      xhr.open("GET", "https://${SP_HOSTNAME}/api/xml?action=logout");
      xhr.timeout = 5000; //5s anything slower and it doesn't make sense
      xhr.send();
    </script>
  </body>
</html>
EOF

cat>/var/www/system/tenant/logout-notify.html<<EOF
<!DOCTYPE html>
<html>
  <head>
    <title>Logout Adobe Connect</title>
  </head>
  <body>
    <script>
      var redirect = function redirect() {
        var reg = /[?&]return=([^&#]*)/i
        var result = reg.exec(location.href)
        if (result) {
          location.href=decodeURIComponent(result[1])
        }
      };

      var xhr = new XMLHttpRequest();
      xhr.addEventListener("load",redirect);
      xhr.addEventListener("timeout", redirect);
      xhr.open("GET", "https://${SP_HOSTNAME}/api/xml?action=logout");
      xhr.timeout = 5000; //5s anything slower and it doesn't make sense
      xhr.send();
    </script>
  </body>
</html>
EOF
adduser -- _shibd ssl-cert
mkdir -p /var/log/shibboleth
mkdir -p /var/log/apache2 /var/lock/apache2

echo "----"
cat /etc/shibboleth/shibboleth2.xml
echo "----"
cat /etc/apache2/sites-available/default.conf
cat /etc/apache2/sites-available/default-ssl.conf

a2ensite default
a2ensite default-ssl

[ "x${SERVER_LIMIT}" == "x" ] && SERVER_LIMIT=930
if [ "${SERVER_LIMIT}" -ne 930 ]; then
  sed -i -e "/MaxRequestWorkers/s/16/${SERVER_LIMIT}/" -e "/ServerLimit/s/930/${SERVER_LIMIT}/" /etc/apache2/apache2.conf
else
  # Calculate MaxRequestWorkers 16 is the mem usage per thread
  MAX_CLIENTS=$(expr  $(expr $(free -m | grep Mem | awk '{print $2}') - 512 ) / 16)
  [ $MAX_CLIENTS -gt 16 ] && sed -i -e "/MaxRequestWorkers/s/16/$MAX_CLIENTS/" /etc/apache2/apache2.conf
fi

service shibd start
rm -f /var/run/apache2/apache2.pid

env APACHE_LOCK_DIR=/var/lock/apache2 APACHE_RUN_DIR=/var/run/apache2 APACHE_PID_FILE=/var/run/apache2/apache2.pid APACHE_RUN_USER=www-data APACHE_RUN_GROUP=www-data APACHE_LOG_DIR=/var/log/apache2 apache2 -DFOREGROUND
