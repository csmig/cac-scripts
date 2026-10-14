#!/bin/bash

# Configures the Flathub Chromium (org.chromium.Chromium) to use a PIV/CAC.
#
# The Flatpak runtime ships neither OpenSC nor pcsc-lite, so the host's copies
# are staged inside the app's data dir and loaded via LD_LIBRARY_PATH, and the
# sandbox is given access to the host pcscd socket. Flatpak Chromium shares the
# host's ~/.pki/nssdb, so the "CAC Module" registered there points at the staged
# library, which loads both inside the sandbox and in native Chromium/Brave.
#
# Run install-cac-linux.sh first. Re-run this after OpenSC is upgraded on the host.
# No sudo required.

app_id=org.chromium.Chromium
lib_dir=/usr/lib/x86_64-linux-gnu
cac_lib_dir="${HOME}/.var/app/${app_id}/cac-lib"
nssdb="sql:${HOME}/.pki/nssdb"

if ! flatpak info "${app_id}" >/dev/null 2>&1; then
  echo "${app_id} is not installed as a Flatpak; exiting." 1>&2
  exit 1
fi

if [[ ! -e "${lib_dir}/opensc-pkcs11.so" ]]; then
  echo "OpenSC is not installed run install-cac-linux.sh" 1>&2
  exit 1
fi

if ! command -v modutil >/dev/null; then
  echo "modutil not found; install libnss3-tools" 1>&2
  exit 1
fi

echo "Staging OpenSC libraries in ${cac_lib_dir}"
mkdir -p "${cac_lib_dir}"
for lib in opensc-pkcs11.so libopensc.so.11 libeac.so.3 libpcsclite.so.1; do
  cp -L "${lib_dir}/${lib}" "${cac_lib_dir}/" || { echo "Failed to copy ${lib}; exiting." 1>&2; exit 1; }
done

# Keep the app's own LD_LIBRARY_PATH and append the staged libs
app_ld_path=$(flatpak info -m "${app_id}" | sed -n 's/^LD_LIBRARY_PATH=//p')
echo "Granting ${app_id} access to pcscd"
flatpak override --user --socket=pcsc \
  --env=LD_LIBRARY_PATH="${app_ld_path:+${app_ld_path}:}${cac_lib_dir}" "${app_id}"

mkdir -p "${HOME}/.pki/nssdb"
if modutil -dbdir "${nssdb}" -list | grep -q "CAC Module"; then
  echo "Replacing existing 'CAC Module' in ${nssdb}"
  modutil -force -dbdir "${nssdb}" -delete "CAC Module"
fi
modutil -force -dbdir "${nssdb}" -add "CAC Module" -libfile "${cac_lib_dir}/opensc-pkcs11.so"
modutil -dbdir "${nssdb}" -list "CAC Module"

echo "Done. Fully quit and restart Chromium."
