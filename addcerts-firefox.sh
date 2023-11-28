#!/bin/bash

ff_profile=$(dirname ~/.mozilla/firefox/*/cert*.db)
cert_dir=/usr/local/share/ca-certificates/dod

for crt in "${cert_dir}"/*; do
  name=$(openssl x509 -text -noout -in "${crt}" \
    -certopt no_version,no_signame,no_validity,no_pubkey,no_extensions,no_sigdump \
    | grep "Subject" | cut -d ',' -f5 | cut -d'=' -f2 | sed 's/^ //g' | sed 's/[ -]/_/g')

  certutil -A -n "${name}" -t "TCu,Cuw,Tuw" -i "${crt}" -d "${ff_profile}"

done
