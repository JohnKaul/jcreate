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
#            mount += "<source>  <dest> ...";
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

##
## Support procedures.

# err --
#   all error messages should be directed to `stderr`.
# EX
#   if ! do_something; then
#       err "unable to do_something"
#       exit 1
#   fi
err() {     #{{{
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] *ERROR*: $*" >&2
    return 0
}
#}}}

# Bail out if we don't have root privileges.
test_root() {           #{{{
        if [ $(id -u) -ne 0 ]; then
                err "This script must be run as root or else jail will fail to be created."
                exit 1
        fi
}
#}}}

# prompt --
#   Wrapper to print messages.
prompt() {     #{{{
#    printf -- "  %s\n" $1
#    printf " %-30s\n" $1
    echo "$*" >&2
}
#}}}

# validate --
#   validate a variable is either a directory or file (and is readable).
# EX
#   if ! _validate "$_source" ; then
#       exit 1
#   fi
validate() {        #{{{
   local _source
   _source=$1

   if [ -f "$_source" ] || [ -d "$_source" ]; then
       if [ ! -r "$_source" ]; then
           err "Source not readable: ${_source}"
           return 1
       fi
#       return 0
   else
       err "source not valid: $*"
       return 1
   fi
}
#}}}

# assert --
#   Assert a variable is NOT empty.
# EX
#   if _assert "$_sourcefile" ; then
#       do_something
#   else
#       err "Missing variable \"_sourcefile\""
#       exit 1
#   fi
assert() {      #{{{
   local _source
   _source=$1

   if [ -z $_source ]; then 
       return 1 
   fi
#   return 0
}
#}}}

# config_read_file --
#    Read a file and look for a value.
config_read_file() {        #{{{
    (grep -E "${2}=" -m 1 "${1}" 2>/dev/null) | head -n 1 | cut -d '=' -f 2-;
}
#}}}

# cofig_get --
#   A wrapper to call `config_read_file` and set the variable value.
# EX
#       config_variable=$(config_get some_variable "${_prefix}/some_config.cfg")
config_get() {      #{{{
   val="$(config_read_file "${2}" "${1}")";
   printf -- "%s" "${val}";
}
#}}}

# extract_userland --
#	simple wrapper to extract the userland.
# EX
#   extract_userland $userland_media_path $container_path/$jail_name 
extract_userland() {        #{{{
	local _what=$1
	local _where=$2

    # Create the jail directory.
	echo "Extracting the userland"
    mkdir -p $_where
	tar -xf $_what -C $_where --unlink
}
#}}}

# copyinto_userland --
#	This function will copy files from one directory to another
#	but make sure both source and destination exist before doing
#	so, otherwise error.
# EX
#   if assert $copyin; then
#       if validate $copyin; then
#           copyinto_userland $_prefix/$copyin "$_prefix/copyto"
#       fi
#   fi
copyinto_userland() {      #{{{
	local _cwd=$(pwd)
	local _source=$1
	local _dest=$2

	## if ! validate "$_source"; then
	## 	err "Directory to copy files from does not exist."
    ##     exit 1
	## fi

	## if ! validate "$_dest"; then
	## 	err "Directory to copy files into does not exist."
	## fi

	if assert $_source \
			&& validate $_source \
			&& assert $_dest \
			&& validate $_dest; then
				prompt "Copying in configurations"
				cd $_source/ ; tar cf - . | ( tar xf - -C $_dest ) ; cd $_cwd
	fi
}
#}}}

# run_setup_script --
#	This function will copy the setup script into the jail and run
#	it.
# EX
#	run_setup_script ${jail_setup_script} "${_container_path}/${jail_name}"
run_setup_script() {	#{{{
		local _script
		local _jail_path
		_script=$1
		_jail_path=$2

		if assert ${_script} \
				&& validate ${_script} \
				&& assert ${_jail_path} \
				&& validate ${_jail_path}; then
						echo "Copying in the setup script"
						cp "${_script}" "${_jail_path}/jailsetup.sh"
						chown root:wheel "${_jail_path}/jailsetup.sh"
						service jail start ${jail_name}
						echo "Configuring jail"
						jexec ${jail_name} '/jailsetup.sh'
						service jail stop ${jail_name}
		fi
}
#}}}

# check_sysv --
#       This function will check for sysv variables and echo them out
#       (to the jail.conf file we hope).
# EX
# check_sysv $_jail_conf_file
check_sysv() {          #{{{
   local _where=$2                      # where to write the config line to.

   if assert ${jail_systemv}; then
		   if [ ${jail_systemv} == "1" ]; then
				   #   echo "  exec.stop  = \"\";" >> $_where
				   echo "  allow.sysvipc = 1;" >> $_where
		   fi
   fi

   if assert ${jail_sysvmsg}; then
		   if [ ${jail_sysvmsg} == "new" ]; then
				   echo "  sysvmsg = new;" >> $_where
		   fi
   fi

   if assert ${jail_sysvsem}; then
		   if [ ${jail_sysvsem} == "new" ]; then
				   echo "  sysvsem = new;" >> $_where
		   fi
   fi

   if assert ${jail_sysvshm}; then
		   if [ ${jail_sysvshm} == "new" ]; then
				   echo "  sysvshm = new;" >> $_where
		   fi
   fi
}
#}}}

# check_mlock --
#       A function to check and see if we need the jail to have mlocking.
# EX
# check_mlock $jail_mlock $_jail_conf_file
check_mlock() {         #{{{
   local _var=$1                        # Varible to check
   local _where=$2                      # where to write the config line to.

   if assert ${_var}; then
		   if [ $_var == "1" ]; then
				   echo "  exec.stop  = \"\";" >> $_where
				   echo "  allow.mlock;" >> $_where
		   fi
   fi
}
#}}}

# check_mounts --
#
# EX
# check_mounts $jail_mounts $_jail_conf_file
check_mounts() {        #{{{
   local _mounts=$1
   local _where=$2

   # Read any mountings
   if ! assert ${_mounts}; then
		   cat "${_mounts}" | while read line
   do
		   echo "  $line" >> $_where
   done
   fi
}
#}}}

# mkidr --
#       simple wrapper to keep all directory making consistant.
# EX
# makedir "a/location"
makedir() {     #{{{
   local _where=$1                      # directory to create

   mkdir -p $_where
}
#}}}

##
## ENVIRONMENT CHECK

# Make sure we are run as root.
test_root
# Make sure we can at least find the /etc/jail.conf file. For
# simplicity, I assume it is set up.
if ! validate $(find /etc/ -type f -name 'jail.conf'); then
		err "Unable to locate \"/etc/jail.conf\" file. See docs."
		exit 1
fi

##
## SCRIPT VARIABLES
## These variables are necessary to run the script.

        # _template_conf --
        #       Template to pull jail variables from
        _template_conf=$1

        # jcreate.conf --
        #       Configuration file which holds the `media.path`
        #       and `containers.path`variables.
        _jcreate_conf=$(find /usr/local/etc/ -type f -name 'jcreate.conf')

##
## REQUIRED VARIABLES
## These variables are required; script should exit immediately if and are not found.

        _userland_path=$(config_get media.path ${_jcreate_conf})
        if ! assert ${_userland_path} || ! validate ${_userland_path}; then
                err "Userland path is required"
                exit 1
        fi

        _container_path=$(config_get containers.path ${_jcreate_conf})
        if ! assert ${_container_path} || ! validate ${_container_path}; then
                err "invalid jail container path"
                exit 1
        fi

        _container_conf=$(config_get containers.conf ${_jcreate_conf})
        if ! assert ${_container_conf} || ! validate ${_container_conf}; then
                err "invalid jail container configuration path"
                exit 1
        fi

        jail_name=$(config_get jail.name ${_template_conf})
        if ! assert ${jail_name}; then
                err "jail name not found in ${_template_conf}"
                exit 1
        fi

        # epair.id --
        jail_epairid=$(config_get jail.epairid ${_template_conf})
        if ! assert ${jail_epairid}; then
                err "jail epair ID not found in ${_template_conf}"
                exit 1
        fi

##
## OPTIONAL VARIABLES
## These variables define extra information that should be included in the jail.conf file.

        # jail.mlock --
        jail_mlock=$(config_get jail.mlock ${_template_conf})

        jail_systemv=$(config_get jail.systemv ${_template_conf})
        jail_sysvmsg=$(config_get jail.sysvmsg ${_template_conf})
        jail_sysvsem=$(config_get jail.sysvsem ${_template_conf})
        jail_sysvshm=$(config_get jail.sysvshm ${_template_conf})

        jail_setup_script="$(config_get jail.config ${_template_conf})"
		# check variable, locate file and validate
        if assert ${jail_setup_script}; then
                jail_setup_script="$(find ${_template_conf%/*} -type f -name "${jail_setup_script}")"
                jail_setup_script="$(readlink -f ${jail_setup_script})"
				if ! validate ${jail_setup_script}; then
						err "Specified jail setup script is not valid"
						exit 1
				fi
        fi
        
		jail_mounts="$(config_get jail.mounts ${_template_conf})"
		# check variable, locate file and validate
        if assert ${jail_mounts}; then
                jail_mounts="$(find ${_template_conf%/*} -type f -name "${jail_mounts}")"
                jail_mounts="$(readlink -f ${jail_mounts})"
        fi
       
		jail_copyin="$(config_get jail.copyin ${_template_conf})"
		# check variable, locate file and validate
        if assert ${jail_copyin}; then
                jail_copyin="$(find ${_template_conf%/*} -type f -name "${jail_copyin}")"
                jail_copyin="$(readlink -f $jail_copyin)"
				if ! validate ${jail_copyin}; then
						err "Spcified \"copy in directory\" is not valid"
						exit 1
				fi
        fi
        
		jail_msg="$(config_get jail.msg ${_template_conf})"
		# check variable, locate file and validate
        if assert ${jail_msg}; then
                jail_msg="$(find ${_template_conf%/*} -type f -name "${jail_msg}")"
                jail_msg="$(readlink -f ${jail_msg})"
				if ! validate ${jail_msg}; then
						err "Specified jail creation message is not valid"
						exit 1
				fi
        fi

##
## Jail Creating.
## 	At this point in the script all the variables should be asserted
##  and validated, so we can start calling our helper functions to
##  create the userland copy in the script and etc..

# Name of configuration file to create.
_jail_conf_file=${_container_conf}/${jail_name}.conf

echo "Creating the jail: \"${jail_name}\""
extract_userland ${_userland_path} ${_container_path}/${jail_name}

echo "Copying DNS server information"
# Copy DNS server.
cp /etc/resolv.conf ${_container_path}/${jail_name}/etc/resolv.conf

# Copy timezone.
echo "Copying timezone information"
cp /etc/localtime ${_container_path}/${jail_name}/etc/localtime

# Update to latest patch.
# freebsd-update -b ${_container_path}/ fetch install

# copy in the copy_in directory.
copyinto_userland ${jail_copyin} ${_container_path}/${jail_name}/usr/local/

# Create a minimal jail.conf file to start and configure the jail with the setup script.
#{{{
# Create the jail.conf file.
echo "
${jail_name} {
  # NETWORKS/INTERFACES
  \$id = "${jail_epairid}";
" > ${_jail_conf_file}

check_sysv ${_jail_conf_file}

echo "}" >> ${_jail_conf_file}
#}}}

# Run the jail configuration script
run_setup_script ${jail_setup_script} "${_container_path}/${jail_name}"

# Recreate the jail.conf file, for the configured jail, with the specified mountings.
echo "Creating the jail.conf file."
#{{{
# Create the jail.conf file.
echo "
# ${jail_name}
# The steps taken to create this jail:
#
# # Create the jail directory.
# mkdir -p ${_container_path}/${jail_name}
#
# # Extract the userland base.
# tar -xf ${_userland_path} -C ${_container_path}/${jail_name} --unlink
#
# # Copy DNS server.
# cp /etc/resolv.conf ${_container_path}/${jail_name}/etc/resolv.conf
#
# # Copy timezone.
# cp /etc/localtime ${_container_path}/${jail_name}/etc/localtime
#
# # Update to latest patch.
# freebsd-update -b ${_container_path}/ fetch install

${jail_name} {
  # NETWORKS/INTERFACES
  \$id = "${jail_epairid}";
" > ${_jail_conf_file}

check_sysv ${_jail_conf_file}
check_mlock ${jail_mlock} ${_jail_conf_file}
check_mounts ${jail_mounts} ${_jail_conf_file}

echo "}" >> ${_jail_conf_file}
#}}}

## Report results.
printf -- "\n -- CONFIGURATION --\n"
printf -- "Media path\t\t: %s\n" "${_userland_path}"
printf -- "Container path\t\t: %s/%s\n" "${_container_path}" "${jail_name}"
printf -- "Container config path\t: %s\n" "${_container_conf}"
printf -- "Jail name\t\t: %s\n" "${jail_name}"
printf -- "Jail epairid\t\t: %s\n" "${jail_epairid}"
printf -- "Jail IP\t\t\t: 192.168.0.%s\n" "${jail_epairid}"
printf -- "Jail config\t\t: %s\n" "${_jail_conf_file}"
printf -- "\n -- MAINTENCE --\n"
printf -- "To start the jail\t: doas service jail start %s\n" "${jail_name}"
printf -- "To execute the jail\t: doas jexec %s /bin/sh\n" "${jail_name}"
printf -- "To destroy the jail\t: doas jdestroy.sh %s\n" "${jail_name}"
printf -- "To manually destroy the jail:\n\t chflags -R 0 /usr/local/jails/containers/${jail_name}\n"
printf -- "\t rm -rf ${_container_path}/${jail_name}\n"
printf -- "\t rm ${_jail_conf_file}\n"
#printf -- "\n\nJail setup script\t: ${jail_setup_script}\n"
#if assert ${jail_copyin} && validate ${jail_copyin}; then
#        printf -- "Jail copy in\t: ${jail_copyin}\n"
#fi

# jail.msg --
# Read the message file and echo the results
if assert ${jail_msg} && validate ${jail_msg}; then
   printf -- "\n -- MESSAGE --"
   cat "${jail_msg}" | while read line
    do
        echo "$line"
    done
fi
