#!/bin/sh
#
# SYNOPSIS
# jcreate.sh <template.conf>
#
# DESCRIPTION
# This script will aid in the development of an jail.conf.d config file.
# The though process is that you create a template or a flavor directory
# for each jail you want -e.g. Plex, Git, Emby, etc. and you run this
# script with the path to that config file and it will:
#       1. Make a directory in the jails/containers directory.
#       2. Extract the userland (the media).
#       3. Write the <jail_name>.conf file to the /etc/jail.conf.d/ directory.
#       4. Copy in an optional jail configuration script and execute it.
#       5. Copy files into jail; relative to `/usr/local/`.
#
# Using this script to generate the <jail>.conf file should aid in the
# updating maintenance process. -i.e. When the jail needs to be updated,
# it can instead be destroyed and remade with a new userland instead
# of trying to upgrade each jail.
#
# NOTE
# Because this script only creates a very minimal conf file (saves on
# having duplicate information for each jail configuration), this
# script expects default jail options placed in `/etc/jail.conf` which
# look something like (your needs may vary slighlty):
#
# EXAMPLE (from the handbook)
#        ---->% JAIL.CONF
#        # DEFAULT OPTIONS
#        # (COMMON TO ALL JAILS)
#
#        # STARTUP/LOGGING
#        exec.start = "/bin/sh /etc/rc";
#        exec.stop  = "/bin/sh /etc/rc.shutdown";
#        exec.consolelog = "/var/log/jail_console_${name}.log";
#
#        # PERMISSIONS
#        allow.raw_sockets;
#        exec.clean;
#
#        # PATH/HOSTNAME
#        path = "/usr/local/jails/containers/${name}";
#        host.hostname = "${name}";
#
#        # VNET/VIMAGE
#        vnet;
#        vnet.interface = "${epair}b";
#
#        # NETWORKS/INTERFACES
#        $ip             =   "192.168.0.${id}/24";
#        $epair          =   "epair${id}";
#        $gateway        =   "192.168.0.1";
#        $bridge         =   "bridge0";
#
#        # ADD TO bridge INTERFACE
#        exec.prestart   =   "/sbin/ifconfig ${epair} create up";
#        exec.prestart   +=  "/sbin/ifconfig ${epair}a up descr jail:${name}";
#        exec.prestart   +=  "/sbin/ifconfig ${bridge} addm ${epair}a up";
#        exec.start      +=  "/sbin/ifconfig ${epair}b ${ip} up";
#        exec.start      +=  "/sbin/route add default ${gateway}";
#        exec.poststop   =   "/sbin/ifconfig ${bridge} deletem ${epair}a";
#        exec.poststop   +=  "/sbin/ifconfig ${epair}a destroy";
#
#       .include "/etc/jail.conf.d/*.conf";
#        ---->% JAIL.CONF
#
# With only the required template variables, this script will create a
# minimal jail.config file like below, in the `/etc/jail.conf.d/` directory.
#
#        ---->% PLEX.CONF
#        plex {
#            # NETWORKS/INTERFACES
#            $id = "210";
#
#            # MOUNTS
#            mount += "<source>  <dest> ...;
#        }
#        ---->% PLEX.CONF
#
# or even as small as:
#        ---->% CLASSIC.CONF
#        classic {
#           # NETWORKS/INTERFACES
#           $id = "63";
#         }
#        ---->% CLASSIC.CONF
#
# Creating a template/flavor should look like this:
#
# At a spot of your choosing (like: $(HOME)/jail-configuations/):
#
# Mytemplate
#    |
#    +-- mytemplate.conf
#    |
#    +-- mytemplate.sh
#
#        ---->% mytemplate.conf
#        # jail name
#        jail.name=mytemplate
#        # jail epair ID
#        jail.epairid=64
#        # jail setup script.
#        jail.config=mytemplate.sh
#        # items to copy into jail.
#        jail.copyin=mytemplate.d
#
#        ---->% mytemplate.sh
#        # Things to setup my jail.
#        echo "Installing \"DOAS\".
#        pkg install -y doas
#        ...
#

##
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
	bailout "This script must be run as root or else jail will fail to be created."
    fi
}

# config_read_file ---
#    Read a file and look for a value.
# XXX:
# 1. Return 0 instead of string.
config_read_file() {
    (grep -E "${2}=" -m 1 "${1}" 2>/dev/null || echo "VAR=__UNDEFINED__") | head -n 1 | cut -d '=' -f 2-;
}

# cofig_get ---
#   A wrapper. Call `config_read_file` and set the variable value.
config_get() {
   val="$(config_read_file "${2}" "${1}")";
   printf -- "%s" "${val}";
}

# XXX:
# 1. Preform numeric compairison and exit.
#		EG: err=$?; [[ $err -ne 0 ]] && exit $err
# assert ---
#   Assert value has been set, otherwise exit.
## assert() {
## #   val=$1
##    if [ "${1}" = __UNDEFINED__ ]; then
##       # if we've not found a value, then exit.
##       bailout "**ERROR** \"$vall\" value not found in jconfig.conf"
##    fi
## }
# }}}

# Environment sanity check
test_root

# Save current location.
cwd=$(pwd)

##
## Variables
# Locate our configuration file to find userland and container locations.
_jcreate_conf="$(find ~/bin/ -type f -name 'jcreate.conf')"

# Accept a template configuration file for jail parameters.
_template_conf=$1

# Get the Userland and Conatainer locations
userland_media_path="$(config_get media.path $_jcreate_conf)"
container_path="$(config_get containers.path $_jcreate_conf)"

# Get variables from the template.conf file.
jail_name="$(config_get jail.name $_template_conf)"
jail_epairid="$(config_get jail.epairid $_template_conf)"

# jail.config --
# This file will list all the different components we need to
# configure the jail.
jail_setup_script=`basename "$(config_get jail.config $_template_conf)"`
_setup_script="$(find  ${_template_conf%/*} -type f -name "${jail_setup_script}")"

# jail.mlock --
# Used to enable `mlock` on the jail. -i.e. a setting in the
# `jail.conf` file.
jail_mlock="$(config_get jail.mlock $_template_conf)"

# jail.mounts --
# Used to create mount points inside the jail.
jail_mounts=`basename "$(config_get jail.mounts $_template_conf)"`
_mounts="$(find  ${_template_conf%/*} -type f -name "${jail_mounts}")"

# jail.copyin --
# This is used to copy in configuration files for the setup script
jail_copyin="$(config_get jail.copyin $_template_conf)"
if [ "${jail_copyin}" != __UNDEFINED__ ]; then
   _copyin="${_template_conf%/*}/`basename $jail_copyin`"
fi

# jail.copypost --
# Used to copy in some post jail configuration files after the jail
# has been created and configured. -e.g. A `plexdata` folder.
jail_copypost="$(config_get jail.copypost $_template_conf)"
if [ "${jail_copyin}" != __UNDEFINED__ ]; then
   _copypost="${_template_conf%/*}/`basename $jail_copypost`"
fi

#jail_preconfig="$(config_get jail.preconfig $_template_conf)"

# jail.msg --
# This is used to display a message after the jail has been setup.
# -e.g. An activation key or further setup instructions.
jail_msg=`basename "$(config_get jail.msg $_template_conf)"`
_message="$(find  ${_template_conf%/*} -type f -name "${jail_msg}")"

#adminuser="$(config_get jail.adminuser $_template_conf)"
#adminpswd="$(config_get jail.adminpswd $_template_conf)"

##
## Assertions
# Assert the variables we need are defined, otherwise exit script.
#{{{
#assert TTTuserland_media_path
#assert "container_path"

if [ "${userland_media_path}" = __UNDEFINED__ ]; then
   # if we've not found a value, then exit.
   echo "**ERROR** \"media.path\" value not found in jconfig.ini"
   exit 1
fi

if [ "${container_path}" = __UNDEFINED__ ]; then
   # if we've not found a value, then exit.
   echo "**ERROR** \"container.path\" value not found in jconfig.ini"
   exit 1
fi

if [ "${jail_name}" = __UNDEFINED__ ]; then
   # if we've not found a value, then exit.
   echo "**ERROR** \"jail.name\" value not found in jconfig.ini"
   exit 1
fi

if [ "${jail_epairid}" = __UNDEFINED__ ]; then
   # if we've not found a value, then exit.
   echo "**ERROR** \"jail.epairid\" value not found in jconfig.ini"
   exit 1
fi
# }}}

echo "Creating the jail: \"$jail_name\""

# Create a variable to save typing this over and over again.
_jail_conf_file=/etc/jail.conf.d/${jail_name}.conf

echo "Extracting userland."
# Create the jail directory.
mkdir -p $container_path/$jail_name

# Extract the userland base.
tar -xf $userland_media_path -C $container_path/$jail_name --unlink

echo "Copying DNS server information"
# Copy DNS server.
cp /etc/resolv.conf $container_path/$jail_name/etc/resolv.conf

# Copy timezone.
cp /etc/localtime $container_path/$jail_name/etc/localtime

# Update to latest patch.
# freebsd-update -b $container_path/ fetch install

## Run preconfiguration script if any.
#if [ "${jail_preconfig}" != __UNDEFINED__ ]; then
#        . "${jail_preconfig}"
#fi

# jail.copyin --
# Copy in the `copyin` directory.
if [ "${_copyin}" != "" ]; then
   echo "Copying in configurations"
   cd $_copyin/ ; tar cf - . | ( tar xf - -C $container_path/$jail_name/usr/local/ )
fi

# Ensure we are at the same location as we were when the script was called.
cd ${cwd}

# Create a minimal jail.conf file to start and configure the jail with the setup script.
#{{{
# Create the jail.conf file.
echo "
$jail_name {
  # NETWORKS/INTERFACES
  \$id = "${jail_epairid}";
}" > $_jail_conf_file
#}}}

# jail.conf --
# Run the jail configuration script
if [ "${_setup_script}" != "" ]; then
   echo "Configuring jail"
#   sed "s,adminuser,adminuser=\"${adminuser}\",g" $_setup_script
   cp $_setup_script $container_path/$jail_name/jailsetup.sh
   chown root:wheel $container_path/$jail_name/jailsetup.sh
   service jail start $jail_name
   jexec $jail_name '/jailsetup.sh'
   service jail stop $jail_name
fi

# Recreate the jail.conf file, for the configured jail, with the specified mountings.
echo "Creating the jail.conf file."
#{{{
# Create the jail.conf file.
echo "
# $jail_name
# The steps taken to create this jail:
#
# # Create the jail directory.
# mkdir -p $container_path/$jail_name
#
# # Extract the userland base.
# tar -xf $userland_media_path -C $container_path/$jail_name --unlink
#
# # Copy DNS server.
# cp /etc/resolv.conf $container_path/$jail_name/etc/resolv.conf
#
# # Copy timezone.
# cp /etc/localtime $container_path/$jail_name/etc/localtime
#
# # Update to latest patch.
# freebsd-update -b $container_path/ fetch install

$jail_name {
  # NETWORKS/INTERFACES
  \$id = "${jail_epairid}";
" > $_jail_conf_file

#echo "Jail Mlock: ${jail_mlock}"
if [ "${jail_mlock}" == "1" ]; then
   echo "  exec.stop  = \"\";" >> $_jail_conf_file
   echo "  allow.mlock;" >> $_jail_conf_file
fi

#echo "Jail mounts: ${_mounts}"
# Read any mountings
if [ "${_mounts}" != "" ]; then
   cat "${_mounts}" | while read line
    do
        echo "  $line" >> $_jail_conf_file
    done
fi
echo "}" >> $_jail_conf_file
#}}}

# jail.copypost --
# Copy in the `copypost` directory.
if [ "${_copypost}" != "" ]; then
   echo "Copying in configurations (post setup)"
   cd $_copypost/ ; tar cf - . | ( tar xf - -C $container_path/$jail_name/usr/local/ )
fi

## # set the admin user and admin password
## if [ "${adminusr}" -ne __UNDEFINED__] && [ "${adminpswd}" -ne __UNDEFINED__ ]; then
##         echo "Adding admin user: ${adminuser}"
##         echo "#!/bin/sh
##         pw user add -n $adminuser -d /home/$adminuser -G wheel -s /bin/csh
##         echo "${adminpswd}" | pw usermod -n $adminuser -h 0
##         chmod 754 /home/$adminuser
##         mkdir -p /home/$adminuser/.ssh
##         touch /home/$adminuser/.ssh/authorized_keys
##         chown -R $adminuser:$adminuser /home/$adminuser/.ssh
##         chmod 700 /home/$adminuser/.ssh
##         chmod 600 /home/$adminuser/.ssh/authorized_keys
##         #rm /jailsetup_user.sh
##         " >> $_setup_script $container_path/$jail_name/jailsetup_user.sh
##         chown root:wheel $container_path/$jail_name/jailsetup_user.sh
##         chmod u+x $container_path/$jail_name/jailsetup_user.sh
##         jexec $jail_name '/jailsetup_user.sh'
## fi

##
## Report results.
printf -- "\n -- Configuration --\n"
printf -- "Media path\t\t: %s\n" "${userland_media_path}"
printf -- "Container path\t\t: %s/%s\n" "${container_path}" "${jail_name}"
printf -- "Jail name\t\t: %s\n" "${jail_name}"
printf -- "Jail epairid\t\t: %s\n" "${jail_epairid}"
printf -- "Jail IP\t\t\t: 192.168.0.%s\n" "${jail_epairid}"
printf -- "Jail config\t\t: %s\n" "${_jail_conf_file}"
printf -- " -- Maintence --\n"
printf -- "To start the jail\t: doas service jail start %s\n" "${jail_name}"
printf -- "To execute the jail\t: doas jexec %s\n" "${jail_name}"
printf -- "To destroy the jail\t: doas jdestroy.sh %s\n" "${jail_name}"
## if [ "${adminusr}" -ne __UNDEFINED__] && [ "${adminpswd}" -ne __UNDEFINED__ ]; then
##         printf -- "To copy your public key to the new jail:\n"
##         printf -- "\tssh-copy-id -i ~/.ssh/id_ed25519.pub $adminuser@192.168.0.%s\n" "${jail_epairid}"
## fi

# jail.msg --
# Read the message file and echo the results
if [ "${_message}" != "" ]; then
   cat "${_message}" | while read line
    do
        echo "$line"
    done
fi
