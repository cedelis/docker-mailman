#!/bin/sh -e

if [ -n "$EX4DEBUG" ]; then
  echo "now debugging $0 $@"
  set -x
fi

DIR=/etc/exim4
CERT=$DIR/exim.crt
KEY=$DIR/exim.key

# This exim binary was built with GnuTLS which does not support dhparams
# from a file. See /usr/share/doc/exim4-base/README.Debian.gz
#DH=$DIR/exim.dhparam

if ! which openssl > /dev/null ;then
	echo "$0: openssl is not installed, exiting" 1>&2
	exit 1
fi

# valid for three years
DAYS=1095

if [ "$1" != "--force" ] && [ -f $CERT ] && [ -f $KEY ]; then
  echo "[*] $CERT and $KEY exists!"
  echo "    Use \"$0 --force\" to force generation!"
  exit 0
fi

if [ "$1" = "--force" ]; then
  shift
fi     

#SSLEAY=/tmp/exim.ssleay.$$.cnf
SSLEAY="$(tempfile -m600 -pexi)"

cat > $SSLEAY <<EOM
[ req ]
prompt = no
default_bits = 2048
default_keyfile = exim.key
distinguished_name = req_distinguished_name
[ req_distinguished_name ]
countryName = US
stateOrProvinceName = Illinois
localityName = Champaign
organizationName = CARLI
commonName = carli.illinois.edu
emailAddress = support@carli.illinois.edu
EOM

echo "[*] Creating a self signed SSL certificate for Exim!"
echo "    This may be sufficient to establish encrypted connections but for"
echo "    secure identification you need to buy a real certificate!"
echo "    "
echo "    Please enter the hostname of your MTA at the Common Name (CN) prompt!"
echo "    "

openssl req -config $SSLEAY -x509 -newkey rsa:2048 -keyout $KEY -out $CERT -days $DAYS -nodes
#see README.Debian.gz*# openssl dhparam -check -text -5 512 -out $DH
rm -f $SSLEAY

chown root:Debian-exim $KEY $CERT $DH
chmod 640 $KEY $CERT $DH

echo "[*] Done generating self signed certificates for exim!"
echo "    Refer to the documentation and example configuration files"
echo "    over at /usr/share/doc/exim4-base/ for an idea on how to enable TLS"
echo "    support in your mail transfer agent."
