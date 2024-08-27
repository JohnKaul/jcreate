#!/bin/sh

## Support Functions
# {{{

PROGNAME=`basename $0`
# Bail out and exit.
bailout() {
    echo "**ERROR** $PROGNAME: $*" >&2
    exit 1
}

# Bail out if we don't have root privileges.
test_root() {
if [ $(id -u) -ne 0 ]; then
	bailout "This script must be run as root."
    fi
}
# }}}

# Environment sanity check
test_root

jailname=$1

if [ "$(find /etc/jail.conf.d/ -type f -name "${jailname}.conf")" = "" ]; then
	bailout "**ERROR** Cannot locate \"${jailname}\" configuration script."
fi

# stop the jail
service jail stop $jailname

# Remove flags.
chflags -R 0 /usr/local/jails/containers/$jailname

# Delete directory
rm -rf /usr/local/jails/containers/$jailname

# Delete the .conf file.
rm /etc/jail.conf.d/${jailname}.conf
