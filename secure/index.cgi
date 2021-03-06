#!/usr/bin/perl
##
##  printenv -- demo CGI program which just prints its environment
##

use MIME::Base64;
use CGI qw/:standard *table *td *tr *ul/;
use utf8;
use encoding 'utf8';

print header(-type=>'text/html',-charset=>'utf-8'),
      start_html(-title=>'SWAMID Test SP',
                  -head=>meta({-http_equiv => 'Content-Type',
                               -content    => 'text/html; charset=utf-8'}) ),
      h1('Federation Authentication Information');

print h2('Attributes');

print <<EOH;
<table border='1'>
<p>
   These attributes were send from the Identity Provider ($ENV{Shib_Identity_Provider}). The 'eppn' attribute if present is often
   used as a permanent identifier for you.
</p>
EOH

foreach $var (sort(keys(%ENV))) {
    #next unless ($var =~ /^[a-z]/ || $var =~ /^Shib/);
    next unless $var =~ /^[a-z]/;
    $val = $ENV{$var};
    $val =~ s|\n|\\n|g;
    $val =~ s|"|\\"|g;
    print "<tr><td>$var</td><td>$val</td></tr>\n";
}
print "</table>\n";

print h2('See Also');
print<<EOH;
   <p>
     This information is mostly meant to be interesting for expert users. 
   </p>
   <ul>
      <li><a href="/Shibboleth.sso/Session">Session</a></li>
      <li><a href="/Shibboleth.sso/Metadata">Metadata</a></li>
      <li><a href="/Shibboleth.sso/Logout">Logout</a></li>
      <li><a href=\"/logs/\">shibboleth logs</a></li>
      <li><a href=\"/info\">server info</a></li>
      <li><a href=\"/status\">server status</a></li>
   </ul>
EOH
