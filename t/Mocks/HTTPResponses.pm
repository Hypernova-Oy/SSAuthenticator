package t::Mocks::HTTPResponses;

sub SSStatus400 {
    return <<RESPONSE;
HTTP/1.1 400 Bad Request
Connection: close
Date: Wed, 30 Dec 2020 11:13:15 GMT
Server: Apache
Vary: User-Agent
Content-Length: 87
Content-Type: application/json;charset=UTF-8
Client-Date: Wed, 30 Dec 2020 11:13:15 GMT
Client-Peer: 127.0.0.1
Client-Response-Num: 1
Client-SSL-Cert-Issuer: /C=US/ST=Arizona/L=Scottsdale/O=GoDaddy.com, Inc./OU=http://certs.godaddy.com/repository//CN=Go Daddy Secure Certificate Authority - G2
Client-SSL-Cert-Subject: /OU=Domain Control Validated/CN=example.com
Client-SSL-Cipher: ECDHE-RSA-AES256-GCM-SHA384
Client-SSL-Socket-Class: IO::Socket::SSL
Content-Secure-Policy: default-src self;
Strict-Transport-Security: max-age=31536000

{"errors":[{"message":"Expected string - got null.","path":"\/password"}],"status":400}
RESPONSE
}

sub SSStatus200True {
    return <<RESPONSE;
HTTP/1.1 200 OK
Connection: close
Date: Wed, 30 Dec 2020 07:30:16 GMT
Server: Apache
Vary: User-Agent
Content-Length: 19
Content-Type: application/json;charset=UTF-8
Client-Date: Wed, 30 Dec 2020 07:30:16 GMT
Client-Peer: 127.0.0.1
Client-Response-Num: 1
Client-SSL-Cert-Issuer: /C=US/ST=Arizona/L=Scottsdale/O=GoDaddy.com, Inc./OU=http://certs.godaddy.com/reposi
Client-SSL-Cert-Subject: /OU=Domain Control Validated/CN=example.com
Client-SSL-Cipher: ECDHE-RSA-AES256-GCM-SHA384
Client-SSL-Socket-Class: IO::Socket::SSL
Content-Secure-Policy: default-src self;
Set-Cookie: CGISESSID=3c29;HttpOnly;Secure
Strict-Transport-Security: max-age=31536000

{"permission":true}
RESPONSE
}

sub SSStatus200False {
    return <<RESPONSE;
HTTP/1.1 200 OK
Connection: close
Date: Thu, 19 Nov 2020 09:24:29 GMT
Server: Apache
Vary: User-Agent
Content-Length: 59
Content-Type: application/json;charset=UTF-8
Client-Date: Thu, 19 Nov 2020 09:24:30 GMT
Client-Peer: 127.0.0.1
Client-Response-Num: 1
Client-SSL-Cert-Issuer: /C=US/O=DigiCert Inc/CN=DigiCert TLS RSA SHA256 2020 CA1
Client-SSL-Cert-Subject: /C=FI/L=Mikkeli/O=Mikkelin Kaupunki/CN=example.com
Client-SSL-Cipher: ECDHE-RSA-AES256-SHA
Client-SSL-Socket-Class: IO::Socket::SSL
Content-Secure-Policy: default-src self;
Set-Cookie: CGISESSID=04fe;HttpOnly;Secure
Strict-Transport-Security: max-age=31536000

{"error":"Koha::Exception::SelfService","permission":false}
RESPONSE
}

sub SSStatus401Unauthenticated {
    return <<RESPONSE;
HTTP/1.1 401 Unauthorized
Connection: close
Date: Thu, 31 Dec 2020 13:45:16 GMT
Server: Apache/2.4.29 (Ubuntu)
Vary: User-Agent
Content-Length: 128
Content-Type: application/json; charset=utf8
Client-Date: Thu, 31 Dec 2020 13:45:16 GMT
Client-Peer: 95.216.159.164:443
Client-Response-Num: 1
Client-SSL-Cert-Issuer: /C=US/O=Let's Encrypt/CN=Let's Encrypt Authority X3
Client-SSL-Cert-Subject: /CN=demo1.intra.koha-helsinki-2.hypernova.fi
Client-SSL-Cipher: TLS_AES_256_GCM_SHA384
Client-SSL-Socket-Class: IO::Socket::SSL
Client-Warning: Missing Authenticate header

{"error":"Koha::Patrons->cast():> Cannot find an existing Koha::Patron from userid|cardnumber|borrowernumber '4321|4321|4321'."}
RESPONSE
}

sub SSStatus404PageNotFound {
    return <<RESPONSE;
HTTP/1.1 404 Not Found
Connection: close
Content-Type: text/html; charset=UTF-8
Title: Koha â<U+0080>º Error 404

<!DOCTYPE html>
<!-- TEMPLATE FILE: errorpage.tt -->

<html lang="en">
  <title>Koha &rsaquo; Error 404</title>
</html>
RESPONSE
}

sub AuthPin201OK {
    return <<RESPONSE;
HTTP/1.1 201 Created
Connection: close
Date: Sat, 02 Jan 2021 15:48:40 GMT
Server: Apache/2.4.29 (Ubuntu)
Vary: User-Agent
Content-Length: 153
Content-Type: application/json;charset=UTF-8
Set-Cookie: CGISESSID=ad43
Set-Cookie: CGISESSID=5880; path=/

{"borrowernumber":3,"email":"","firstname":"Tanya","permissions":["auth","borrowers"],"sessionid":"5880","surname":"Daniels"}
RESPONSE
}

sub AuthPin201Wrong {
    return <<RESPONSE;
HTTP/1.1 401 Unauthorized
Connection: close
Date: Sat, 02 Jan 2021 15:55:48 GMT
Server: Apache/2.4.29 (Ubuntu)
Vary: User-Agent
Content-Length: 25
Content-Type: application/json;charset=UTF-8
Client-Warning: Missing Authenticate header
Set-Cookie: CGISESSID=a1c6

{"error":"Login failed."}
RESPONSE
}

sub ClientWarningConnectionRefused {
    return <<RESPONSE;
500 Can't connect to 127.0.0.1:120 (Connection refused)
Content-Type: text/plain
Client-Date: Wed, 30 Dec 2020 11:47:21 GMT
Client-Warning: Internal response

Can't connect to 127.0.0.1:120 (Connection refused)

Connection refused at /usr/local/share/perl/5.28.1/LWP/Protocol/http.pm line 50.
RESPONSE
}

sub ClientWarningConnectionTimeout {
    return <<RESPONSE;
500 Can't connect to 192.168.0.1:120 (Connection timed out)
Content-Type: text/plain
Client-Date: Wed, 30 Dec 2020 11:48:36 GMT
Client-Warning: Internal response

Can't connect to 192.168.0.1:120 (Connection timed out)

Connection timed out at /usr/local/share/perl/5.28.1/LWP/Protocol/http.pm line 50.
RESPONSE
}

sub PageNotFound {
return <<RESPONSE;
HTTP/1.1 404 Not Found
Connection: close
Date: Thu, 09 Jun 2022 15:49:30 GMT
Server: Apache
Vary: User-Agent
Content-Length: 1113
Content-Type: text/html;charset=UTF-8
Client-Date: Thu, 09 Jun 2022 15:49:30 GMT
Title: Page not found

<!DOCTYPE html>
<!-- Request ID: f72167f6 -->
<html>
<head>
<title>Page not found</title>
<style>
a img {
border: 0;
}
body {
background-color: #caecf6;
}
#noraptor {
left: 0%;
position: fixed;
top: 60%;
}
#notfound {
background: url(/mojo/notfound.png);
height: 62px;
left: 50%;
margin-left: -153px;
margin-top: -31px;
position:absolute;
top: 50%;
width: 306px;
}
</style>
</head>
<body>
<a href="https://lumme.koha-suomi.fi/">
<img alt="Bye!" id="noraptor" src="/mojo/noraptor.png">
</a>    <div id="notfound"></div>
</body>
</html>
RESPONSE
}

sub OpeningHours200 {
    return <<RESPONSE;
HTTP/1.1 200 OK
Connection: close
Date: Tue, 07 Jun 2022 02:22:33 GMT
Server: Apache/2.4.41 (Ubuntu)
Vary: User-Agent
Content-Length: 127
Content-Type: application/json;charset=UTF-8

[["06:47","11:47"],["06:47","11:47"],["06:47","11:47"],["06:47","11:47"],["06:47","11:47"],["06:47","11:47"],["06:47","11:47"]]
RESPONSE
}

1;
