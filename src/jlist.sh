#!/bin/sh

# This tool will create a list of running jails like the `jls` tool.
#
# Since VNET the `jls` tool does not display the IP address of the
# jails, and if the example in the FreeBSD handbook, and the `jcreate`
# manpage, is followed the `jls` list will not have IPs.

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

ip=$(config_get \$ip /etc/jail.conf)
ip=$(echo $ip | awk -F"." '{print $1"."$2"."$3}' | cut -d '"' -f 2-)

printf "   JID NAME\tIP\t\tHOSTNAME\tOS RELEASE\tPATH\n"
/usr/sbin/jls name host.hostname osrelease jid path | while read name hostname osrelease jid path
do
        # pull the ID from the jail's config file.
        id=$(config_get \$id /etc/jail.conf.d/$name.conf)
        # strip the semi-colon.
        id=$(echo $id | awk -F";" '{print $1}')
        printf "   $jid  $name\t$ip.$id\t$hostname\t\t$osrelease\t$path\n"
done
