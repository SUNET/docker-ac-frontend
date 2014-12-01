#!/bin/sh -x

printenv

export HTTP_IP="127.0.0.1"
export HTTP_PORT="8080"
if [ "x${BACKEND_PORT}" != "x" ]; then
   HTTP_IP=`echo "${BACKEND_PORT}" | sed 's%/%%g' | awk -F: '{ print $2 }'`
   HTTP_PORT=`echo "${BACKEND_PORT}" | sed 's%/%%g' | awk -F: '{ print $3 }'`
fi

if [ "x$SP_HOSTNAME" = "x" ]; then
   SP_HOSTNAME="`hostname`"
fi

if [ "x$SP_CONTACT" = "x" ]; then
   SP_CONTACT="info@$SP_CONTACT"
fi

if [ "x$SP_ABOUT" = "x" ]; then
   SP_ABOUT="/about"
fi

KEYDIR=/etc/ssl
mkdir -p $KEYDIR
export KEYDIR
if [ ! -f "$KEYDIR/private/shibsp.key" -o ! -f "$KEYDIR/certs/shibsp.crt" ]; then
   shib-keygen -o /tmp -h $SP_HOSTNAME 2>/dev/null
   mv /tmp/sp-key.pem "$KEYDIR/private/shibsp.key"
   mv /tmp/sp-cert.pem "$KEYDIR/certs/shibsp.crt"
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

            <SessionInitiator type="Chaining" Location="/DS/nordu.net" id="nordunet" relayState="cookie">
                <SessionInitiator type="SAML2" defaultACSIndex="1" acsByIndex="false" template="bindingTemplate.html"/>
                <SessionInitiator type="Shib1" defaultACSIndex="5"/>
                <SessionInitiator type="SAMLDS" URL="http://md.nordu.net/role/idp.ds"/>
            </SessionInitiator>

            <SessionInitiator type="Chaining" Location="/DS/kalmar2" id="kalmar2" relayState="cookie">
                <SessionInitiator type="SAML2" defaultACSIndex="1" acsByIndex="false" template="bindingTemplate.html"/>
                <SessionInitiator type="Shib1" defaultACSIndex="5"/>
                <SessionInitiator type="SAMLDS" URL="https://kalmar2.org/simplesaml/module.php/discopower/disco.php"/>
            </SessionInitiator>
 
            <SessionInitiator type="Chaining" Location="/Login/feide" id="feide" relayState="cookie" entityID="https://idp.feide.no">
                <SessionInitiator type="SAML2" defaultACSIndex="1" acsByIndex="false" template="bindingTemplate.html"/>
            </SessionInitiator>

            <SessionInitiator type="Chaining" Location="/DS/haka.funet.fi" id="haka" relayState="cookie">
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

cat>/etc/apache2/sites-available/default-ssl.conf<<EOF
<VirtualHost *:443>
        ServerName ${SP_HOSTNAME}
        SSLProtocol TLSv1 
        SSLEngine On
        SSLCertificateFile $KEYDIR/certs/${SP_HOSTNAME}.crt
        SSLCertificateChainFile $KEYDIR/certs/chain.crt
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
        RewriteRule ^(.*/)index.html$ $1 [L,R=301]

        ErrorLog /var/log/apache2/error.log
        # Possible values include: debug, info, notice, warn, error, crit,
        # alert, emerg.
        LogLevel warn
        CustomLog /var/log/apache2/access.log combined
        ServerSignature off

        AddDefaultCharset utf-8

        ProxyPass /balancer-manager !
        ProxyPass /Shibboleth.sso !
        ProxyPass /shibboleth-sp !
        ProxyPass /system/tenant !
        ProxyPass /secure !
        ProxyPass /errors !
	ProxyPass /_lvs.txt !

        ProxyPass / balancer://connect/ stickysession=BREEZESESSION|session
        ProxyPassReverse / balancer://connect/
        ProxyPreserveHost On
        <Proxy balancer://connect>
EOF
n=`echo $APPSERVERS | wc -w`
f=`expr 100 / $n`
for h in $APPSERVERS; do
   hn=`echo $h | awk -F. '{print $1}'`
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
           Allow from 83.227.179.169
           Allow from 127.0.0.1
        </Location> 

        <LocationMatch "^/(system/login|admin)$">
           AuthType shibboleth
           ShibRequireSession On
           require valid-user
           RequestHeader set X_REMOTE_USER %{eppn}e
           RequestHeader set EPPN %{eppn}e
           RequestHeader set GIVENNAME %{givenName}e
           RequestHeader set SN %{sn}e
           RequestHeader set MAIL %{mail}e
           RequestHeader set AFFILIATION %{affiliation}e
           RequestHeader set UNSCOPED_AFFILIATION %{unscoped_affiliation}e
        </LocationMatch>
        <LocationMatch "^/system/login-">
           AuthType shibboleth
           require shibboleth
           ShibRequireSession Off
           RequestHeader set X_REMOTE_USER %{eppn}e
           RequestHeader set EPPN %{eppn}e
           RequestHeader set GIVENNAME %{givenName}e
           RequestHeader set SN %{sn}e
           RequestHeader set MAIL %{mail}e
           RequestHeader set AFFILIATION %{affiliation}e
           RequestHeader set UNSCOPED_AFFILIATION %{unscoped_affiliation}e
        </LocationMatch>

        <Location /favicon.ico>
           Satisfy any
           order deny,allow
           allow from all
        </Location>
</VirtualHost>
EOF

mkdir -p /var/www/system/tenant
cat>/var/www/system/tenant/logout.php<<EOF
<?php $session=$_COOKIE['BREEZESESSION']; setcookie("BREEZESESSION","",time()-3600,"/"); ?>
<html>
   <head><title>Logout</title></head>
   <body>
<?php
require_once 'HTTP/Client.php';
$c = new HTTP_Client();
$c->get("https://${SP_HOSTNAME}/api/xml?action=logout&session=".$session);
?>
   <script>
      location.href="https://${SP_HOSTNAME}/Shibboleth.sso/Logout"
   </script>
   </body>
</html>
EOF

adduser -- _shibd ssl-cert
mkdir -p /var/log/shibboleth
mkdir -p /var/log/apache2

echo "----"
cat /etc/shibboleth/shibboleth2.xml
echo "----"
cat /etc/apache2/sites-available/default.conf
cat /etc/apache2/sites-available/default-ssl.conf

a2ensite default
a2ensite default-ssl

service shibd start
service apache2 start
tail -f /var/log/apache2/error.log
