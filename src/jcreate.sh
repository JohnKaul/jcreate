#!/bin/sh

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
#       5. Copy files into jail; relative to `/usr/`.
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
#        # A script or command to run on host
#        # after jail is created.
#        host.config=run_after.sh
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
}
#}}}

# get_file_contents_without_comments --
#   Return the contents of a file without comments.
#   File's comments can be either simple conf style
#   -i.e. hash (#) or c-style (/* */).
# EX
#  (get_file_contents_without_comments "${1}" | grep -E "VALUE" -m 1 2>/dev/null)
get_file_contents_without_comments() {          #{{{
        (grep -v -e '#' -e '/\*' -e '*' -e '\*/' "${1}")
}
#}}}

# config_read_file --
#    Read a file and look for a value.
config_read_file() {        #{{{
        (get_file_contents_without_comments "${1}" | \
                grep -e "${2}*=*" -m 1 2>/dev/null) | \
                head -n 1 | cut -d '=' -f 2-;
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
#   simple wrapper to extract the userland.
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
#   This function will copy files from one directory to another
#   but make sure both source and destination exist before doing
#   so, otherwise error.
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
    ##  err "Directory to copy files from does not exist."
    ##     exit 1
    ## fi

    ## if ! validate "$_dest"; then
    ##  err "Directory to copy files into does not exist."
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

# run_setup_scripts_from_stdin --
#   This function will read lines from STDIN, locate the listed file,
#   copy it into the jail container, and execute it.
run_setup_scripts_from_stdin() {        #{{{
        while read -r fileline ; do
        	case "$fileline" in
        	\#*|'')                         # ignore lines that begin with a hash
        		;;
        	*)
                        scriptline="$(find ${_template_conf%/*} -type f -name "${fileline}")"
                        scriptline="$(readlink -f ${scriptline})"
                        if ! validate ${scriptline}; then
                                err "Specified jail setup script is not valid: ${fileline}"
                                exit 1
                        fi
                        cp "${scriptline}" "${_jail_path}/${fileline}"
                        chown root:wheel "${_jail_path}/${fileline}"
                        jexec ${jail_name} "/${fileline}"
        		;;
        	esac
        done
}
#}}}

# run_setup_script --
#   This function will copy the setup script into the jail and run
#   it if the argument is a script file. This function will call the
#   `run_setup_scripts_from_stdin()` if the argument is a file with
#   a list of scripts.
# EX
#   run_setup_script ${jail_setup_script} "${_container_path}/${jail_name}"
run_setup_script() {    #{{{
        local _script
        local _jail_path
        _script=$1
        _jail_path=$2

        if assert ${_script} \
                && validate ${_script} \
                && assert ${_jail_path} \
                && validate ${_jail_path}; then
                        service jail start ${jail_name}

                        # LOGIC (why this is here): the assumption is
                        #  that normal scripts will contain the pkg
                        #  installs but since the directive was given
                        #  to install packages from the base system, I
                        #  have to assume these packages will be needed
                        #  for the setup script supplied and should
                        #  then be installed.
                        if assert ${jail_packages}; then
                                # Run 'pkg install' from the host system for
                                # any packages found in the `jail.packages` file.
                                pkg -j ${jail_name} install -y \
                                        $(get_file_contents_without_comments ${jail_packages})
                        fi

                        if [ "${_script##*.}" == "sh" ]; then
                                echo "Copying in the setup script"
                                cp "${_script}" "${_jail_path}/jailsetup.sh"
                                chown root:wheel "${_jail_path}/jailsetup.sh"

                                echo "Configuring jail"
                                jexec ${jail_name} '/jailsetup.sh'
                        fi
                        if ! [ "${_script##*.}" == "sh" ]; then
                                run_setup_scripts_from_stdin < "${_script}"
                        fi
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
   while IFS= read -r line; do
        echo "  $line" >> "${_where}"
   done < "${_mounts}"
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

# Support a "dry-run" option for this script.
DRY_RUN=0
while getopts ":n" opt; do
  case $opt in
    n) DRY_RUN=1 ;;
    \?) echo "Invalid option: -$OPTARG"; exit 1 ;;
  esac
done
shift "$((OPTIND-1))"

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
        if assert ${jail_mounts}; then
                # locate file and validate
                jail_mounts="$(find ${_template_conf%/*} -type f -name "${jail_mounts}")"
                jail_mounts="$(readlink -f ${jail_mounts})"
        else
                prompt "Specified jail mounts file is not valid"
        fi

        jail_copyin="$(config_get jail.copyin ${_template_conf})"
        # check variable, locate file and validate
        if assert ${jail_copyin}; then
                jail_copyin="$(find ${_template_conf%/*} -type d -name "${jail_copyin}")"
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

        # Packages can be installed from the host system
        # from in the jail via the setup script; this section looks
        # for any packages that need to be installed from the host
        # system.
        jail_packages="$(config_get jail.packages ${_template_conf})"
        if assert ${jail_packages}; then
                jail_packages="$(find ${_template_conf%/*} -type f -name "${jail_packages}")"
                jail_packages="$(readlink -f ${jail_packages})"
        fi

        jail_poststart="$(config_get jail.poststart ${_template_conf})"
        jail_prestop="$(config_get jail.prestop ${_template_conf})"

        # host.config --
        # The script or command to run on the host after the jail is created.
        # This can be used to set meta data in the jail.conf file.
        # EX
        #       jail -m ... meta="tag=value" env="configuration"
        host_post_script="$(config_get host.config ${_template_conf})"
        # check variable, locate file and validate
        if assert ${host_post_script}; then
                if [ "${host_post_script##*.}" == "sh" ]; then
                        host_post_script="$(find ${_template_conf%/*} -type f -name "${host_post_script}")"
                        host_post_script="$(readlink -f ${host_post_script})"
                        if ! validate ${host_post_script}; then
                                err "Specified host post jail setup script is not valid"
                                exit 1
                        fi
                fi
        fi

##
## Jail Creating.
##  At this point in the script all the variables should be asserted
##  and validated, so we can start calling our helper functions to
##  create the userland copy in the script and etc..

# Name of configuration file to create.
_jail_conf_file=${_container_conf}/${jail_name}.conf

# The logfile which keep information for later reference.
logfile=/var/log/jail_create_${jail_name}.log
echo "----------------------------------------x- $(date +'%Y-%m-%d %H:%M:%S') -x------" >> ${logfile}

##
## Begin Dry-run option
##  if the dry run option is given, execeute the following and exit the script.


# Check if dry-run flag is set

if [ $DRY_RUN -eq 1 ]; then
  # Print jail.conf file to stdout
  
  ip=$(config_get \$ip /etc/jail.conf)
  ip=$(echo $ip | awk -F"." '{print $1"."$2"."$3}' | cut -d '"' -f 2-)

  cat <<_EOF_ >&1
-- DRY-RUN: REPORT --
(the infomation this script knows about based on the configuration file)

Media path                        : ${_userland_path}
Container path                    : ${_container_path}/${jail_name}
Container config                  : ${_jail_conf_file}
System Jail name                  : ${jail_name}
System Jail epairid               : ${jail_epairid}
System Jail IP                    : ${ip}.${jail_epairid}
Specified Jail config             : ${_jail_conf_file}
Specified Jail setup script       : ${jail_setup_script}
Specified Jail mount config       : ${jail_mounts}
Specified Jail copy-in dir        : ${jail_copyin}
Specified Jail message file       : ${jail_msg}
Specified Jail package file       : ${jail_packages}
Specified Jail poststart          : ${jail_poststart}
Specified Jail prestop            : ${jail_prestop}
Specified Hoost post creat script : ${host_post_script}

-- DRY-RUN: CONFIGURATION --
(this is how the jail's configuration file will be written)

_EOF_
  echo "${jail_name} {"
  echo "  # NETWORKS/INTERFACES"
  echo "  \$id = \"${jail_epairid}\";"

   if assert ${jail_systemv}; then
           if [ ${jail_systemv} == "1" ]; then
                   echo "  allow.sysvipc = 1;"
           fi
   fi

   if assert ${jail_sysvmsg}; then
           if [ ${jail_sysvmsg} == "new" ]; then
                   echo "  sysvmsg = new;"
           fi
   fi

   if assert ${jail_sysvsem}; then
           if [ ${jail_sysvsem} == "new" ]; then
                   echo "  sysvsem = new;"
           fi
   fi

   if assert ${jail_sysvshm}; then
           if [ ${jail_sysvshm} == "new" ]; then
                   echo "  sysvshm = new;"
           fi
   fi

   if assert ${jail_mlock}; then
           if [ $jail_mlock == "1" ]; then
                   echo "  exec.stop  = \"\";"
                   echo "  allow.mlock;"
           fi
   fi
  
  if assert ${jail_mounts}; then
          while IFS= read -r line; do
                  echo "  $line"
          done < "${jail_mounts}"
  fi

  if assert ${jail_poststart}; then
    echo "  exec.poststart += ${jail_poststart};"
  fi
  if assert ${jail_prestop}; then
    echo "  exec.prestop += ${jail_prestop};"
  fi

  echo "}"
  exit 0
fi

## End Dry-run
## 

# LOGIC:
# - If the userland already exists, skip extracting; this could be
#   the situation where a user wants to update the jail via a script.
if ! [ -d "${_container_path}/${jail_name}" ]; then
		echo "Creating the jail: \"${jail_name}\""
		extract_userland ${_userland_path} ${_container_path}/${jail_name}

		echo "Copying DNS server information"
		# Copy DNS server.
		cp /etc/resolv.conf ${_container_path}/${jail_name}/etc/resolv.conf

		# Copy timezone.
		echo "Copying timezone information"
		cp /etc/localtime ${_container_path}/${jail_name}/etc/localtime

                echo "hostname=\"${jail_name}\"" >> ${_container_path}/${jail_name}/etc/rc.conf

		# Update to latest patch.
		# freebsd-update -b ${_container_path}/ fetch install
fi

# copy in the copy_in directory.
copyinto_userland ${jail_copyin} ${_container_path}/${jail_name}/usr/

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

# Get the `ip` from the base jail.conf file and assemble an IP address to add
# to the <jailname>.conf file. This isn't necessary, but it won't hurt either;
# user can `cat` the <jailname>.conf file to get information and this will be
# a convenience.
ip=$(config_get \$ip /etc/jail.conf)
ip=$(echo $ip | awk -F"." '{print $1"."$2"."$3}' | cut -d '"' -f 2-)

# Recreate the jail.conf file, for the configured jail, with the specified mountings.
echo "Creating the jail.conf file."
#{{{
# Create the jail.conf file.
cat <<_EOF_ >${_jail_conf_file}
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
  \$id = ${jail_epairid};
_EOF_

check_sysv ${_jail_conf_file}
check_mlock ${jail_mlock} ${_jail_conf_file}
if [ -n "${jail_mounts}" ] && validate ${jail_mounts}; then
    check_mounts ${jail_mounts} ${_jail_conf_file}
fi

if assert ${jail_poststart}; then
        echo "exec.poststart += ${jail_poststart};"
fi

if assert ${jail_prestop}; then
        echo "exec.prestop += ${jail_prestop};"
fi

echo "}" >> ${_jail_conf_file}
#}}}

# Create a log file.
cat <<_EOF_ >>${logfile}
-- CONFIGURATION --
Media path              : ${_userland_path}
Container path          : ${_container_path} ${jail_name}
Container config path   : ${_container_conf}
Jail name               : ${jail_name}
Jail epairid            : ${jail_epairid}
Jail IP                 : ${ip}.${jail_epairid}
Jail config             : ${_jail_conf_file}
-- MAINTENCE --
To start the jail       : doas service jail start ${jail_name}
To execute the jail     : doas jexec ${jail_name} /bin/sh
To destroy the jail     : doas jdestroy ${jail_name}
To manually destroy the jail:
        doas chflags -R 0 ${_container_path}/${jail_name}
        doas rm -rf ${_container_path}/${jail_name}
        doas rm ${_jail_conf_file}

_EOF_

# Prompt the user as well.
cat <<_EOF_ >&1
-- CONFIGURATION --
Media path              : ${_userland_path}
Container path          : ${_container_path} ${jail_name}
Container config path   : ${_container_conf}
Jail name               : ${jail_name}
Jail epairid            : ${jail_epairid}
Jail IP                 : ${ip}.${jail_epairid}
Jail config             : ${_jail_conf_file}
-- MAINTENCE --
To start the jail       : doas service jail start ${jail_name}
To execute the jail     : doas jexec ${jail_name} /bin/sh
To destroy the jail     : doas jdestroy ${jail_name}
To manually destroy the jail:
        doas chflags -R 0 ${_container_path}/${jail_name}
        doas rm -rf ${_container_path}/${jail_name}
        doas rm ${_jail_conf_file}
_EOF_

# jail.msg --
# Read the message file and echo the results
if assert ${jail_msg} && validate ${jail_msg}; then
        printf -- "\n -- MESSAGE --"
        while IFS= read -r line; do
                echo "  $line"
                echo "  $line" >> ${logfile}
        done < "${jail_msg}"
fi

if assert ${host_post_script}; then
        exec ${host_post_script}
fi
