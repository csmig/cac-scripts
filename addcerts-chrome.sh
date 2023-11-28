#!/bin/bash

cert_dir=/usr/local/share/ca-certificates/dod

readlink -e "${HOME}/snap/chromium/current" > /dev/null
snap=$?

if [[ ${snap} -eq 0 ]]; then
  echo "Chromium is installed as a snap package. Smart Card readers are not supported by this configuration."
fi


for crt in "${cert_dir}"/*; do
  name=$(openssl x509 -text -noout -in "${crt}" \
    -certopt no_version,no_signame,no_validity,no_pubkey,no_extensions,no_sigdump \
    | grep "Subject" | cut -d ',' -f5 | cut -d'=' -f2 | sed 's/^ //g' | sed 's/[ -]/_/g')

  certutil -d "sql:${HOME}/.pki/nssdb" -A -n "${name}" -i "${crt}" -t "TCP,TCP,TCP"

done
