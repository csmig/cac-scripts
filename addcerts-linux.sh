#!/bin/bash

cert_tmp_template=dod-certs-XXX
cert_bundle_url=https://dl.dod.cyber.mil/wp-content/uploads/pki-pke/zip/unclass-certificates_pkcs7_DoD.zip
dod_signed="https://afrcdesktops.us.af.mil"

tmp_dir=$(mktemp -d -t "${cert_tmp_template}")

# shellcheck disable=SC1091
source "/etc/os-release"

case "${ID}" in
  debian|ubuntu|pop|kubuntu|edubuntu)
  cert_dir=/usr/local/share/ca-certificates/dod
  update_certs_cmd='update_debian_certs'
  ;;
  arch|centos|rhel|fedora)
  cert_dir=/usr/local/share/ca-certificates/dod
  update_certs_cmd='update_trust_anchor_certs'
  ;;
  *)
  echo 'Your distro is not yet supported... should be easy to add your update certs command'
  exit 3;
esac

update_debian_certs() {
  sudo update-ca-certificates --verbose --fresh
}

update_trust_anchor_certs() {
  for cert in "${cert_dir}"/*; do
    sudo trust anchor --store "${cert}";
  done
}

download_certs() {
  # will download insecure because ca certs are likely not loaded yet
  curl -k -o "${1}" "${2}"
}

verify_cert_contents() {
  openssl smime -verify -in "${1}"/*.sha256 -inform DER -CAfile ./*.pem | \
    while IFS= read -r line; do
      echo "${line%$'\r'}" | sha256sum -c || (echo "Failed checksum Exiting..." && exit 1;);
    done
}

convert_pem_p7b() {
  local p7b_file
  local pem_file

  p7b_file="${1}"
  pem_file="${2}"
  echo "Converting ${p7b_file} to pem"

  openssl pkcs7 \
          -in "${p7b_file}" \
          -print_certs \
          -out "${pem_file}" || { echo -e "Failed to convert ${p7b_file} to ${pem_file}; exiting." 1>&2; return 1; }
}

convert_der_p7b() {
  local p7b_file
  local der_file

  p7b_file="${1}"
  der_file="${2}"

  echo "Converting ${p7b_file} to pem"

  openssl \
      pkcs7 \
      -in "${p7b_file}" \
      -inform DER \
      -print_certs \
      -out "${der_file}";

}

split_pem_file() {
  local indiv_certs;

  while read -r line; do
 	  if [[ "${line}" =~ END.*CERTIFICATE ]]; then
	      cert_lines+=( "${line}" );
        : > "${2}/${indiv_certs[ -1]}.crt";
	      for cert_line in "${cert_lines[@]}"; do
	         echo "${cert_line}" >> "${2}/${indiv_certs[ -1]}.crt";
        done;
 	      cert_lines=( );
 	  elif [[ "${line}" =~ ^[[:space:]]*subject=.* ]]; then
	       indiv_certs+=( "${BASH_REMATCH[0]//*CN = /}" );
 	       cert_lines+=( "${line}" );
 	  elif [[ "${line}" =~ ^[[:space:]]*$ ]]; then
      :;
 	  else
 	    cert_lines+=( "${line}" );
 	  fi;
 	done < "${1}";
  echo "$(IFS=$'\n'; echo "${indiv_certs[*]}")"
}
orig_dir="${PWD}"
cd "${tmp_dir}" || (echo "${tmp_dir} Does not exist Exiting..." && exit 1)
download_certs dod.zip "${cert_bundle_url}";
unzip -o dod.zip -d bundle-zip/;
cd bundle-zip/* || (echo "dod/ does not exit Exiting..." && exit 1);

verify_cert_contents "${PWD}"

sudo mkdir -p ${cert_dir} || (echo "Failed to create ${cert_dir}" && exit 1);

declare -a individual_certs=()

indiv_certs_dir="individual_certs";
mkdir "${indiv_certs_dir}";

# Convert p7b to PEM and split
for p7b_file in $(ls *.pem.p7b); do
  pem_file="${p7b_file//.p7b/}"
  convert_pem_p7b "${p7b_file}" "${pem_file}" || exit 1;
  pem_certs=$(split_pem_file "${pem_file}" "${indiv_certs_dir}") || exit 1;

  IFS=$'\n'
  for cert in ${pem_certs}; do
    individual_certs+=("${cert}")
  done;
  IFS=' '
done;

# Convert der.p7b to PEM and split
for p7b_file in $(ls *_der.p7b); do
  der_file="${p7b_file//.p7b/}"
  convert_der_p7b "${p7b_file}" "${der_file}"
 	der_pem_certs=$(split_pem_file "${der_file}" "${indiv_certs_dir}") || exit 1;

  IFS=$'\n'
  for cert in ${der_pem_certs}; do
    individual_certs+=("${cert}")
  done;
  IFS=' '
done

declare -A uniq_certs;

for individual_cert in "${individual_certs[@]}"; do
    uniq_certs["$individual_cert"]="${individual_cert}";
done
echo "Found a total of ${#uniq_certs[@]} unique certs inside of CA bundles."

echo "Copying certs to ${cert_dir}"

total_staged=0
for staged_file in "${indiv_certs_dir}"/*; do
    sudo cp "${staged_file}" "${cert_dir}/";
    total_staged="$((total_staged+1))";
done;

echo "Copied ${total_staged} certs"

echo "Updating global cert store"
$update_certs_cmd
echo "Testing if wget to ${dod_signed}"
wget -S --spider --timeout 10 "${dod_signed}"

cd "${orig_dir}" || exit 2
rm -r "${tmp_dir}"
