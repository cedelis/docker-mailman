FROM debian:buster-slim
MAINTAINER Fer Uria <fauria@gmail.com>

ENV URL_FQDN lists.example.com
ENV EMAIL_FQDN lists.example.com
ENV MASTER_PASSWORD example
ENV SMTPHOST localhost
ENV SMTPPORT 0
ENV LIST_LANGUAGE_CODE en
ENV LIST_LANGUAGE_NAME English
ENV LIST_ADMIN admin@lists.example.com
ENV DEBUG_CONTAINER false
ENV SMTP_AUTH False
ENV SMTP_USE_TLS False

ENV DEBIAN_FRONTEND noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN true

RUN apt update
RUN apt -y upgrade
RUN apt install -y \
  mailman \
  apache2 \
  exim4-daemon-heavy \
  # this is so we can run rt-mailgate perl script
  libtest-lwp-useragent-perl

COPY 00_local_macros /etc/exim4/conf.d/main/
COPY 04_exim4-config_mailman /etc/exim4/conf.d/main/
COPY 04_exim4-config_rt /etc/exim4/conf.d/main/
COPY 30_exim4-config_auth /etc/exim4/conf.d/auth/
COPY 40_exim4-config_mailman /etc/exim4/conf.d/transport/
COPY 40_exim4-config_rt /etc/exim4/conf.d/transport/
COPY 40_exim4-config_rtstore /etc/exim4/conf.d/transport/
COPY 101_exim4-config_mailman /etc/exim4/conf.d/router/
COPY 101_exim4-config_rt /etc/exim4/conf.d/router/
COPY 101_exim4-config_rtstore /etc/exim4/conf.d/router/

COPY mailman.conf /etc/apache2/sites-available/
COPY etc_initd_mailman /etc/init.d/mailman

COPY exim4-config.cfg /
COPY mailman-config.cfg /
COPY exim-adduser /
COPY run.sh /
COPY set-exim4-update-conf /
COPY aliases_for_migration /
COPY rt-mailgate /usr/local/bin/
COPY rt-mailstore /usr/local/bin/
COPY flush_queue /usr/local/bin/
COPY delete_all_queue /usr/local/bin/

RUN chmod +x /run.sh
RUN chmod +x /set-exim4-update-conf
RUN chmod +x /etc/init.d/mailman
RUN chmod +x /usr/local/bin/rt-mailgate
RUN chmod +x /usr/local/bin/rt-mailstore
RUN chmod +x /usr/local/bin/flush_queue
RUN chmod +x /usr/local/bin/delete_all_queue

VOLUME /var/log/mailman
VOLUME /var/log/exim4
VOLUME /var/spool/exim4
VOLUME /var/log/apache2
VOLUME /var/lib/mailman/archives
VOLUME /var/lib/mailman/lists
VOLUME /etc/exim4/tls.d
VOLUME /etc/exim4/exim.crt
VOLUME /etc/exim4/exim.key
VOLUME /etc/exim4/passwd

EXPOSE 25 80

CMD ["/run.sh"]
