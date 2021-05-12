#!/bin/sh
set -eux

for file in $(ls /var/log/exim4/deferred_email/); do 
  if [ $(echo $file | egrep "\.old$") ]; then
    echo "skipping already-processed file..."
  else
    action=$(echo $file | cut -d_ -f1)
    cat /var/log/exim4/deferred_email/${file} |  \
     /usr/local/bin/rt-mailgate \
      --action ${action} \
      --queue " Support at CARLI" \
      --url http://carli-rt-service.rt.svc.cluster.local
    mv "$file" "${file}.old"
  fi
done

