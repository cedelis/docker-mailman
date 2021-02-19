#!/bin/bash
# By Fer Uría <fauria@gmail.com>
# See: http://www.exim.org/howto/mailman21.html
# and: https://help.ubuntu.com/community/Mailman
# and: https://debian-administration.org/article/718/DKIM-signing_outgoing_mail_with_exim4

# read ENV variables from mountpoint (more secure that way):
URL_FQDN=`cat /mailman-env/URL_FQDN`
EMAIL_FQDN=`cat /mailman-env/EMAIL_FQDN`
MASTER_PASSWORD=`cat /mailman-env/MASTER_PASSWORD`
LIST_ADMIN=`cat /mailman-env/LIST_ADMIN`
DEBUG_CONTAINER=`cat /mailman-env/DEBUG_CONTAINER`
SMTPHOST=`cat /mailman-env/SMTPHOST`
SMTPPORT=`cat /mailman-env/SMTPPORT`
SMTP_AUTH=`cat /mailman-env/SMTP_AUTH`
SMTP_USE_TLS=`cat /mailman-env/SMTP_USE_TLS`
SMTP_USER=`cat /mailman-env/SMTP_USER`
SMTP_PASSWD=`cat /mailman-env/SMTP_PASSWD`
EXIM4_SMARTHOST=`cat /mailman-env/EXIM4_SMARTHOST`
EXIM4_OTHER_HOSTNAMES=`cat /mailman-env/EXIM4_OTHER_HOSTNAMES`
EXIM4_LOCAL_INTERFACES=`cat /mailman-env/EXIM4_LOCAL_INTERFACES`

if [ $DEBUG_CONTAINER == 'true' ]; then
	outfile='/dev/console'
else
	outfile='/dev/null'
fi

mailmancfg='/etc/mailman/mm_cfg.py'

cat << EOB

    ***********************************************
    *                                             *
    *   Docker image: fauria/mailman              *
    *   https://github.com/fauria/docker-mailman  *
    *                                             *
    ***********************************************

EOB

# Fill debconf files with proper runtime values:
/bin/sed -i "s/lists\.example\.com/${EMAIL_FQDN}/" /exim4-config.cfg
if [ $LIST_LANGUAGE_CODE != "en" ]; then
	/bin/sed -i "s/default_server_language\ select\ en\ (English)/default_server_language\ select\ ${LIST_LANGUAGE_CODE}\ (${LIST_LANGUAGE_NAME})/" /mailman-config.cfg
	/bin/sed -i "/^mailman mailman\/site_languages/ s/$/\,\ ${LIST_LANGUAGE_CODE}\ \(${LIST_LANGUAGE_NAME}\)/" /mailman-config.cfg
fi
# set up campus relay (which sends outoing email via smarthost to our Cloud Emailer)
/bin/sed -i "s/dc_other_hostnames string/dc_other_hostnames string ${EXIM4_OTHER_HOSTNAMES}/" /exim4-config.cfg
/bin/sed -i "s/dc_smarthost string/dc_smarthost string ${EXIM4_SMARTHOST}/" /exim4-config.cfg
/bin/sed -i "s/dc_local_interfaces string/dc_local_interfaces string ${EXIM4_LOCAL_INTERFACES}/" /exim4-config.cfg

# Set debconf values and reconfigure Exim and Mailman. For some reason, dpkg-reconfigure exim4-config does not seem to work.
echo -n "Setting up Exim..."
{
	apt-get update
	apt-get remove --purge -y exim4 exim4-base exim4-config exim4-daemon-light

	debconf-set-selections /exim4-config.cfg
	echo ${EMAIL_FQDN} > /etc/mailname
	apt-get install -y exim4-daemon-heavy

	# smarthost credentials
	cat << EOA >> /etc/exim4/passwd.client
${SMTPHOST}:${SMTP_USER}:${SMTP_PASSWD}
EOA

} &>$outfile
echo ' Done.'

echo -n "Setting up Mailman..."
{
	debconf-set-selections /mailman-config.cfg
	dpkg-reconfigure mailman
} &>$outfile
echo ' Done.'

# Replace default hostnames with runtime values:
/bin/sed -i "s/lists\.example\.com/${EMAIL_FQDN}/" /etc/exim4/conf.d/main/00_local_macros
/bin/sed -i "s/lists\.example\.com/${EMAIL_FQDN}/" /etc/exim4/conf.d/main/04_exim4-config_mailman
/bin/sed -i "s/lists\.example\.com/${URL_FQDN}/" /etc/apache2/sites-available/mailman.conf
/bin/sed -i "s/DEFAULT_EMAIL_HOST.*\=.*/DEFAULT_EMAIL_HOST\ \=\ \'${EMAIL_FQDN}\'/" $mailmancfg
/bin/sed -i "s/DEFAULT_URL_HOST.*\=.*/DEFAULT_URL_HOST\ \=\ \'${URL_FQDN}\'/" $mailmancfg
/bin/sed -i "s/DEFAULT_SERVER_LANGUAGE.*\=.*/DEFAULT_SERVER_LANGUAGE\ \=\ \'${LIST_LANGUAGE_CODE}\'/" $mailmancfg

# important! make sure it's SSL
/bin/sed -i "s/DEFAULT_URL_PATTERN.*\=.*/DEFAULT_URL_PATTERN\ \=\ \'https:\/\/%s\/cgi-bin\/mailman\/\'/" $mailmancfg


# Add some directives to Mailman config:
echo "MTA = None" >> $mailmancfg
echo 'DELIVERY_MODULE = "SMTPDirect"' >> $mailmancfg
echo 'SMTP_MAX_RCPTS = 500' >> $mailmancfg
echo 'MAX_DELIVERY_THREADS = 0' >> $mailmancfg
echo "SMTPHOST = \"${SMTPHOST}\"" >> $mailmancfg
echo "SMTPPORT = ${SMTPPORT}" >> $mailmancfg
echo 'OWNERS_CAN_DELETE_THEIR_OWN_LISTS = Yes' >> $mailmancfg

# Outgoing mail Cloud emailer
echo "SMTP_AUTH = ${SMTP_AUTH}" >> $mailmancfg
echo "SMTP_USE_TLS = ${SMTP_USE_TLS}" >> $mailmancfg 
echo "SMTP_USER = \"${SMTP_USER}\"" >> $mailmancfg
echo "SMTP_PASSWD = \"${SMTP_PASSWD}\"" >> $mailmancfg

# remove mm_cfg.pyc, to ensure the new values are picked up
rm -f "${mailmancfg}c"
rm -f "/var/lib/mailman/Mailman/mm_cfg.pyc"

###### NOT necessary since we are assuming mailman lists have already been established
######echo -n "Initializing mailing lists..."
######{
	######/usr/sbin/mmsitepass ${MASTER_PASSWORD}
	######/usr/sbin/newlist -q -l ${LIST_LANGUAGE_CODE} mailman ${LIST_ADMIN} ${MASTER_PASSWORD}
######} &>$outfile
######echo ' Done.'

# Addaliases and update them:
#cat << EOA >> /etc/aliases
#mailman:              "|/var/lib/mailman/mail/mailman post mailman"
#mailman-admin:        "|/var/lib/mailman/mail/mailman admin mailman"
#mailman-bounces:      "|/var/lib/mailman/mail/mailman bounces mailman"
#mailman-confirm:      "|/var/lib/mailman/mail/mailman confirm mailman"
#mailman-join:         "|/var/lib/mailman/mail/mailman join mailman"
#mailman-leave:        "|/var/lib/mailman/mail/mailman leave mailman"
#mailman-owner:        "|/var/lib/mailman/mail/mailman owner mailman"
#mailman-request:      "|/var/lib/mailman/mail/mailman request mailman"
#mailman-subscribe:    "|/var/lib/mailman/mail/mailman subscribe mailman"
#mailman-unsubscribe:  "|/var/lib/mailman/mail/mailman unsubscribe mailman"
#EOA
#/usr/bin/newaliases

#cho -n "Setting up Apache web server..."
{
	a2enmod cgi
	a2ensite mailman.conf
} &>$outfile

echo -n "Setting up RSA keys for DKIM..."
{
	if [ ! -f /etc/exim4/tls.d/private.pem ]; then
		mkdir -p /etc/exim4/tls.d
		openssl genrsa -out /etc/exim4/tls.d/private.pem 2048 -outform PEM
		openssl rsa -in /etc/exim4/tls.d/private.pem -out /etc/exim4/tls.d/public.pem -pubout -outform PEM
	fi
	chgrp -R Debian-exim /etc/exim4
} &>$outfile
echo ' Done.'

key=$(sed -e '/^-/d' /etc/exim4/tls.d/public.pem|paste -sd '' -)
ts=$(date +%Y%m%d)

echo -n "Fixing permissons and finishing setup..."
{
	update-exim4.conf
	#/usr/lib/mailman/bin/check_perms -f
} &>$outfile
echo ' Done.'

echo -n "Starting up services..."
{
	/etc/init.d/exim4 start
	/etc/init.d/mailman start
} &>$outfile
echo ' Done.'

cat << EOB

    ***********************************************
    *                                             *
    *   TO COMPLETE DKIM SETUP, COPY THE          *
    *   FOLLOWING CODE INTO A NEW TXT RECORD      *
    *   IN YOUR DNS SERVER:                       *
    *                                             *
    ***********************************************

EOB
echo "${ts}._domainkey.${EMAIL_FQDN} IN TXT \"k=rsa; p=$key\""
echo
echo
echo '------------- CONTAINER UP AND RUNNING! -------------'

apachectl -DFOREGROUND -k start
