# CAC scripts

A collection of scripts that install support for DoD PIV/CAC and the DoD root CA certificates in Linux. Supports distros using `dpkg` (debian|ubuntu|pop|kubuntu|edubuntu), `rpm` (centos|rhel|fedora) and `pacman` (arch|manjaro).

Sourced and modified from the (unmaintained) repo for [U.S. Air Force Desktop Anywhere](https://gitlab.com/a7277/desktop-anywhere)

## Prequisites

** The scripts require sudo**

You must have installed, enabled, and started the Smartcard reader driver `pcscd` for your distro.

For Ubuntu 22.04:
```
$ sudo apt install pcscd
```

For Arch-based distros:
```
$ sudo pacman -Sy ccid
```


## Script sequence

### Install PIV/CAC drivers

`install-cac-linux.sh` installs system drivers for the PIV/CAC chip on your smartcard

`install-cac-chrome.sh` configures the Chrome nssdb for the current user to use the system drivers.

`install-cac-firefox.sh` configures the Firefox certificate database for the current user to use the system drivers.

*** Firefox note: Ubuntu 22.04 installs Firefox as a snap. The script does not support this out of box. You will need to edit the script to use the correct profile directory found at `${HOME}/snap/firefox/common/.mozilla/firefox/` ***

### Install the root DoD CA certificates

`addcerts-linux.sh` fetches the current DER/PKCS#7 bundle from https://dl.dod.cyber.mil/wp-content/uploads/pki-pke/zip/unclass-certificates_pkcs7_DoD.zip, unbundles them into individual PEM files, and copies the PEM files to `/usr/local/share/ca-certificates/dod`. Then updates OS-level trust for these certs allowing use from command line tools such as openssl, wget, and curl.

`addcerts-chrome.sh` adds trust for the unbundled certs created by `addcerts-linux.sh` to the Chrome nssdb for the current user.

`addcerts-firefox.sh` adds trust for the unbundled certs created by `addcerts-linux.sh` to the Firefox certfiicate database for the current user.

*** Firefox note: Ubuntu 22.04 installs Firefox as a snap. the script currently does not support this out of box. See note above. ***



