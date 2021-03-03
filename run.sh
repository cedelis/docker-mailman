#!/bin/bash
set -e

# (Originally) By Fer Uría <fauria@gmail.com>
# Heavily modified by Chris Delis <cedelis@uillinois.edu>
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

# Set debconf values and reconfigure Exim and Mailman. For some reason, dpkg-reconfigure exim4-config does not seem to work.
opts=(
  dc_local_interfaces "${EXIM4_LOCAL_INTERFACES}"
  dc_other_hostnames "${EXIM4_OTHER_HOSTNAMES}"
  dc_relay_nets ''
  dc_use_split_config 'true'
  dc_eximconfig_configtype 'smarthost'
  dc_smarthost "${SMTPHOST}::${SMTPPORT}"
)
/set-exim4-update-conf "${opts[@]}"
echo "mailname='${EMAIL_FQDN}'" >> /etc/exim4/update-exim4.conf.conf

echo "${SMTPHOST}:$SMTP_USER:$SMTP_PASSWD" > /etc/exim4/passwd.client
echo ${EMAIL_FQDN} > /etc/mailname

update-exim4.conf

echo "Setting up Mailman..."
mailmancfg='/etc/mailman/mm_cfg.py'
# Replace default hostnames with runtime values:
/bin/sed -i "s/lists\.example\.com/${EMAIL_FQDN}/" /etc/exim4/conf.d/main/00_local_macros
/bin/sed -i "s/lists\.example\.com/${EMAIL_FQDN}/" /etc/exim4/conf.d/main/04_exim4-config_mailman
/bin/sed -i "s/lists\.example\.com/${EMAIL_FQDN}/" /etc/exim4/conf.d/main/04_exim4-config_rt
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

# Outgoing mail Cloud mailer
echo "SMTP_AUTH = ${SMTP_AUTH}" >> $mailmancfg
echo "SMTP_USE_TLS = ${SMTP_USE_TLS}" >> $mailmancfg 
echo "SMTP_USER = \"${SMTP_USER}\"" >> $mailmancfg
echo "SMTP_PASSWD = \"${SMTP_PASSWD}\"" >> $mailmancfg

# set from_is_list to "Munge From" so that DMARC satisfied for Cloud mailer
echo "DEFAULT_FROM_IS_LIST = 1" >> $mailmancfg

debconf-set-selections /mailman-config.cfg
dpkg-reconfigure mailman

# remove mm_cfg.pyc, to ensure the new values are picked up
rm -f "${mailmancfg}c"
rm -f "/var/lib/mailman/Mailman/mm_cfg.pyc"

###### NOT necessary since we are assuming mailman lists have already been established
######/usr/sbin/mmsitepass ${MASTER_PASSWORD}
######/usr/sbin/newlist -q -l ${LIST_LANGUAGE_CODE} mailman ${LIST_ADMIN} ${MASTER_PASSWORD}

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

# TAKES WAY TOO LONG! If necessary, run this interactively via shell
#/usr/lib/mailman/bin/check_perms -f


echo "Setting up Apache web server..."
a2enmod cgi
a2ensite mailman.conf

echo "Starting up services..."
/etc/init.d/mailman start
/etc/init.d/exim4 start

echo "Starting up apache..."
apachectl -DFOREGROUND -k start
