#!/bin/bash

# shellcheck disable=SC1091
source "/etc/os-release"

case "${ID}" in
  debian|ubuntu|pop|kubuntu|edubuntu)
    opensc_pkcs11_lib='opensc_pkcs11_lib_ubuntu'
    test_opensc_status='test_opensc_status_ubuntu'
    install_nss_tools='install_nss_tools_ubuntu'
  ;;
  arch)
    opensc_pkcs11_lib='opensc_pkcs11_lib_arch'
    test_opensc_status='test_opensc_status_arch'
    install_nss_tools='install_nss_tools_arch'
  ;;
  centos|rhel|fedora)
    opensc_pkcs11_lib='opensc_pkcs11_lib_centos'
    test_opensc_status='test_opensc_status_centos'
    install_nss_tools='install_nss_tools_centos'
  ;;
  *)
  echo 'Your distro is not yet "supported"... should be easy to add your update certs command'
  exit 3;
esac

install_nss_tools_ubuntu() {
  sudo apt-get update;
  DEBIAN_FRONTEND="noninteractive" sudo apt-get install -y libnss3-tools
  return $?
}

test_opensc_status_ubuntu() {
  dpkg -l opensc
  return $?
}

opensc_pkcs11_lib_ubuntu() {
  dpkg -L opensc-pkcs11 | grep 'opensc-pkcs11.so' | awk '{ print length(), $0 | "sort -n" }' | head -n1 | cut -f2 -d' '
  return $?
}

install_nss_tools_arch() {
  pacman -Sy --noconfirm nss
  return $?
}

test_opensc_status_arch() {
  pacman -Qi opensc
  return $?
}

opensc_pkcs11_lib_arch() {
  pacman -Ql opensc | grep "opensc-pkcs11.so" | awk '{ print length(), $0 | "sort -n" }' | head -n1 | cut -f3 -d' '
  return $?
}

install_nss_tools_centos() {
  command -v certutil
  return $?
}

test_opensc_status_centos() {
  rpm -qi opensc
  return $?
}

opensc_pkcs11_lib_centos() {
  rpm -ql opensc | grep "opensc-pkcs11.so" | awk '{ print length(), $0 | "sort -n" }' | head -n1 | cut -f2 -d' '
  return $?
}

if $test_opensc_status >/dev/null; then
  echo -e "OpenSC is installed";

  if ! command -v certutil;
  then
    $install_nss_tools
  fi
  profile_dir=$(dirname "${HOME}"/.mozilla/firefox/*/cert9.db)

  if modutil -dbdir "$profile_dir" -list | grep "CAC Module";
  then
    echo "'CAC Module' already installed";
    exit 0
  fi
  profile_dir=$(dirname "${HOME}"/.mozilla/firefox/*/cert9.db)
  echo "Adding CAC Module libs to ${profile_dir}"
  # Add OpenSC as a new PKCS #11 library to the security database
  modutil -dbdir "$profile_dir" -add "CAC Module" -libfile "$($opensc_pkcs11_lib)"

  # Check that "CAC Module" appears in the device list
  modutil -dbdir "$profile_dir" -list

  # Check that DoD and CAC certificates are loaded and cac certs show up
  certutil -L -d "$profile_dir" -h all
else
  echo "OpenSC is not installed run install-cac-linux.sh"
fi
