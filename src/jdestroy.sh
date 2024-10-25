#!/bin/sh

## Support Functions
# {{{
# Bail out if we don't have root privileges.
test_root() {
		if [ $(id -u) -ne 0 ]; then
				bailout "This script must be run as root."
		fi
}

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
# }}}

# Environment sanity check
test_root

jailname=$1

_jcreate_conf=$(find /usr/local/etc/ -type f -name 'jcreate.conf')

_container_path=$(config_get containers.path ${_jcreate_conf})
if assert ${_container_path} && validate ${_container_path}; then
		# stop the jail
		service jail stop ${jailname}
		# Remove flags.
		chflags -R 0 ${_container_path}/${jailname}
		# Delete directory
		rm -rf ${_container_path}/${jailname}
fi

_container_conf=$(config_get containers.conf ${_jcreate_conf})
if assert ${_container_conf} && validate ${_container_conf}; then
		rm ${_container_conf}/${jailname}.conf
fi
