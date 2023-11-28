#!/bin/bash

# shellcheck disable=SC1091
source "/etc/os-release"

case "${ID}" in
  debian|ubuntu|pop|kubuntu|edubuntu)
    opensc_pkcs11_lib='opensc_pkcs11_lib_ubuntu'
    test_opensc_status='test_opensc_status_ubuntu'
    install_open_sc='install_open_sc_ubuntu'
  ;;
  arch)
    opensc_pkcs11_lib='opensc_pkcs11_lib_arch'
    test_opensc_status='test_opensc_status_arch'
    install_open_sc='install_open_sc_arch'
  ;;
  centos|rhel|fedora)
    opensc_pkcs11_lib='opensc_pkcs11_lib_centos'
    test_opensc_status='test_opensc_status_centos'
    install_open_sc='install_open_sc_centos'
  ;;
  *)
  echo 'Your distro is not yet "supported"... should be easy to add your update certs command'
  exit 3;
esac

install_open_sc_ubuntu() {
  apt-get update;
  DEBIAN_FRONTEND="noninteractive" apt-get install -y opensc
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

install_open_sc_arch() {
  pacman -Sy --noconfirm opensc
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

install_open_sc_centos() {
  yum install -y opensc
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
  echo -e "OpenSC is already installed";
  opensc-tool --info
else
  $install_open_sc

  if $opensc_pkcs11_lib >/dev/null; then
      echo -e "Successfully installed OpenSC $($opensc_pkcs11_lib)";
  else
      echo -e "Failed to install OpenSC; exiting." 1>&2;
      exit 1;
  fi;
fi
