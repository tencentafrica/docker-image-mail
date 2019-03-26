#!/bin/sh

# Ensure configuration is correct.
if [[ "$DOMAIN" = "" ]]; then
    echo "Bad configuration encountered. \$DOMAIN is required."
    exit 1
fi

if [[ "$RELAY" = true ]]; then
    if [[ "$RELAY_HOST" = "" ]] || [[ "$RELAY_PORT" = "0" ]]; then
        echo "Bad relay configuration encountered."
        exit 1
    fi
fi

postconf -e mydomain="${DOMAIN}"

# Configure relaying.
postconf -e relayhost=
echo -n '' > /etc/postfix/sasl_password
if [[ "$RELAY" = true ]]; then
    postconf -e relayhost="[${RELAY_HOST}]:${RELAY_PORT}"
    echo "[${RELAY_HOST}]:${RELAY_PORT} ${RELAY_USERNAME}:${RELAY_PASSWORD}" > /etc/postfix/sasl_password
fi

# Configure sender mapping.
echo -n '' > /etc/postfix/sender_canonical_maps
for sender in ${ALLOWED_SENDERS}; do
    if [[ "$sender" = "" ]]; then continue; fi
    echo "/${sender}/ ${sender}" >> /etc/postfix/sender_canonical_maps
done
echo "/(.*)@.*/ ${DEFAULT_SENDER:-no-reply}@${DOMAIN}" >> /etc/postfix/sender_canonical_maps

# Format allowed recipients
echo -n '' > /etc/postfix/transport_maps
if [[ "$ALLOWED_RECIPIENTS" != "" ]]; then
    for recipient in ${ALLOWED_RECIPIENTS}; do echo "${recipient} :" >> /etc/postfix/transport_maps; done
    echo "* discard:recipient not in list of allowed recipients" >> /etc/postfix/transport_maps
fi

# Index files
newaliases
postmap /etc/postfix/sasl_password /etc/postfix/transport_maps

# Start services.
rsyslogd
postfix start

# Wait for background processes.
syslog_pid="$(cat /var/run/rsyslogd.pid)"
postfix_pid="$(cat /var/spool/postfix/pid/master.pid)"

while kill -0 ${syslog_pid} ${postfix_pid}; do usleep 500000; done
