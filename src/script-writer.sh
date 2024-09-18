#!/bin/sh
# --------------------------------------------------------------------
#: script-writer
# This script will aid in the creation of jail setup scripts. 
# Pass this script some arguments and it will print out the commands
# necessary to complete those tasks.
#
# This script is NOT meant to be perfect or exhaustive, it's only goal
# is to offer a starting point from which futher, more fine grained
# additions, can be made.
#
# USAGE
# script-writer.sh help
#
# EXAMPLE
# $ ./script-writer.sh adduser JOHN ABC123 
# will output:
#       #!/bin/sh
#       # ------------------------------------------------
#       
#       # Bail out if we don't have root privileges.
#       if [ $(id -u) -ne 0 ]; then
#          echo "This script must be run as root."
#          exit 1
#       fi
#       
#       # Adding user: JOHN
#       # NOTE: user will have a password set the same as their username.
#       echo "Making user: JOHN"
#       pw user add -n JOHN -d /home/JOHN -G wheel -m -s /bin/tcsh -w yes
#       chmod 754 /home/JOHN
#       
#       # Adding user SSH key
#       # Create the directory, file and set the proper
#       # permissions as well as adding the key.
#       echo "Adding users public key."
#       mkdir -p /home/JOHN/.ssh
#       touch /home/JOHN/.ssh/authorized_keys
#       echo "ABC123" > /home/JOHN/.ssh/authorized_keys
#       chown -R JOHN:JOHN /home/JOHN/.ssh
#       chmod 700 /home/JOHN/.ssh
#       chmod 600 /home/JOHN/.ssh/authorized_keys
# 
# Since these scripts need to be maintained every once and an while it
# may be easier to create a "master script" to call the script-writer
# script:
#
# EXAMPLE
# jailsetup_ACME.sh (which, when called will generate the output
# helper setup script that can be installed into the jail to run):
#       #!/bin/sh
#       script-writer.sh \
#               install ACME \
#               install ACME2 \
#               adduser JOHN ABC123 \
#               start ACME \
#               makedir /var/db \
#               start ACME2 \
#               > ACME.sh
# --------------------------------------------------------------------

# FLAGS
#
_pkg_bootstraped="False"                                           # Bootstrap pkg repo only once.
_test_root="False"                                                 # Add root check.
_add_header="False"                                                # Add document header.

# SUPPORT FUNCTIONS
#
add_header() {  #{{{
  # add_header
  # Add a document header
  if [ "${_add_header}" = "False" ]; then
     print_it "#!/bin/sh"
     print_it "# ------------------------------------------------"
     echo ""
     _add_header="True"
  fi
}
#}}}
test_root() {   #{{{
  # test_root
  # Add root guard
  if [ "${_test_root}" = "False" ] ; then
     add_header
     print_it "# Bail out if we don't have root privileges."
     print_it "if [ \$(id -u) -ne 0 ]; then"
     print_it "   echo \"This script must be run as root.\""
     print_it "   exit 1"
     print_it "fi"
     echo ""
     _test_root="True"
  fi
}
#}}}
print_it() {  #{{{
  # print_it
  # print something
  local _what="$1"

  if [ "${_what}" != "" ]; then
     echo "${_what}"
  fi
}
#}}}
make_dir() {  #{{{
  # make_dir
  # Make a directory
  local _where="$1"

  if [ "${_where}" != "" ]; then
#     print_it "# Make a directory ${_where}"
     print_it "echo \"Making Directory: ${_where}\""
     print_it "mkdir -p \"${_where}\""
     echo ""
  fi
}
#}}}
create_user() { #{{{
   # create_user
   # Creates a user.
   # NOTE: user will have a password the same as their login.
   local _usr="$1"
   if [ "${_usr}" != "" ]; then
     print_it "# Adding user: ${_usr}"
     print_it "# NOTE: user will have a password set the same as their username."
     print_it "echo \"Making user: ${_usr}\""
     print_it "pw user add -n ${_usr} -d /home/${_usr} -G wheel -m -s /bin/tcsh -w yes"
     print_it "chmod 754 /home/${_usr}"
     echo ""
   fi
}
#}}}
add_key() { #{{{
  # add_key
  # Add a public key for a user
  local _usr="$1"
  local _key="$2"

  if [ "${_usr}" != "" ]; then
     print_it "# Adding user SSH key"
     print_it "# Create the directory, file and set the proper"
     print_it "# permissions as well as adding the key."
     print_it "echo \"Adding users public key.\""
     print_it "mkdir -p /home/${_usr}/.ssh"
     print_it "touch /home/${_usr}/.ssh/authorized_keys"
     print_it "echo \"${_key}\" > /home/${_usr}/.ssh/authorized_keys"
     print_it "chown -R ${_usr}:${_usr} /home/${_usr}/.ssh"
     print_it "chmod 700 /home/${_usr}/.ssh"
     print_it "chmod 600 /home/${_usr}/.ssh/authorized_keys"
     echo ""
  fi
}
#}}}
service_start() {  #{{{
   # service_start
   # Enable and start a service.
   local _srv="$1"
   if [ "${_srv}" != "" ]; then
     print_it "echo \"Starting service: ${_srv}\""
     print_it "sysrc ${_srv}_enable=\"YES\""
     print_it "service ${_srv} onestart"
     echo ""
   fi
}
#}}}
service_disable() { #{{{
   # service_disable
   # Disable a service.
   # EG:
   #  service_disable sendmail
   local _srv="$1"
   if [ "${_srv}" != "" ]; then
     print_it "echo \"Disabling service: ${_srv}\""
     print_it "service ${_srv} onedisable || true"
     echo ""
   fi
}
#}}}
pkg_bootstrap() { #{{{
  # pkg_bootstrap
  # Bootstrap the pkg repository
  # NOTE: there does not seem to be a reason for this section but I am
  #       leaving it in for any future needs (to be uncommented if a
  #       need arises).
  if [ "${_pkg_bootstraped}" = "False" ] ; then
     print_it "echo \"Bootstrap package repo\""
     print_it "mkdir -p /usr/local/etc/pkg/repos"
     print_it "test -e /usr/local/etc/pkg/repos/FreeBSD.conf || \ "
     print_it "   echo 'FreeBSD: { url: \"pkg+http://pkg.FreeBSD.org/${ABI}/quarterly\" }' \ "
     print_it "       >/usr/local/etc/pkg/repos/FreeBSD.conf"
     print_it "ASSUME_ALWAYS_YES=yes pkg bootstrap"
     echo ""
     _pkg_bootstraped="True"
  fi
}
#}}}
pkg_install() { #{{{
   # pkg_install
   # Install a package
   local _pkg="$1"

   if [ "${_pkg}" != "" ]; then                         # Assert: do we have something to install.
#     pkg_bootstrap                                      # Make sure we can install pakages.
     print_it "echo \"Installing package: ${_pkg}\""
     print_it "pkg install -y ${_pkg}"
     echo ""
   fi
}
#}}}
chmod() { #{{{ file
   # chmod
   # Change mode of a file
   local _file="$1"

   if [ "${_file}" != "" ]; then
     print_it "echo \"change mode of file: ${_file}\""
     print_it "chmod u+x ${_file}"
     echo ""
   fi
}
#}}}
chown() { #{{{ who dir
   # chown
   # Change owernership
   local _who="$1"
   local _dir="$2"

   if [ "${_dir}" != "" ]; then
     print_it "echo \"change ownership for: ${_dir}\""
     print_it "chown -R ${_who} ${_dir}"
     echo ""
   fi
}
#}}}
fetch() { #{{{ remote
   # chown
   # Change owernership
   local _remote="$1"
#   local _local="$1"

   if [ "${_remote}" != "" ]; then
     print_it "echo \"fetching: ${_remote}\""
     print_it "fetch -o `basename ${_remote}` ${_remote}"
#     print_it "fetch -o ${_local} ${_remote}"
     echo ""
   fi
}
#}}}
chdir() { #{{{ dir
   # ch
   # Change directory
   local _dir="$1"

   if [ "${_dir}" != "" ]; then
     print_it "echo \"changing directory: ${_dir}\""
     print_it "cd ${_dir}"
     echo ""
   fi
}
#}}}

# MAIN
#
for item in "$@"
do
   case "$item" in
     adduser | createuser) {
             test_root;
             create_user $2;
             add_key $2 $3;
             shift; } ;;
     start | servicestart) {
             test_root;
             service_start $2;
             shift; } ;;
     stop | servicestop) {
             test_root;
             service_disable $2;
             shift; } ;;
     install | pkginstall | pkg) {
             test_root;
             pkg_install $2;
             shift; } ;;
     makedir | mkdir) {
             test_root;
             make_dir $2;
             shift; } ;;
     chown) {
             test_root;
             chown $2 $3;
             shift; } ;;
     chmod) {
             test_root;
             chmod $2;
             shift; } ;;
     fetch) {
             test_root;
             fetch $2;
             shift; } ;;
     chdir | cd) {
             test_root;
             chdir $2;
             shift; } ;;
     help | -h | --help) {
             echo "`basename $0` USAGE:";
             echo "  adduser <username> <public-key>";
             echo "  start <service-name>";
             echo "  stop <service-name>";
             echo "  install <package-name>";
             echo "  makedir <directory>";
             echo "  chdir | cd <directory>";
             echo "  chown <who> <directory>";
             echo "  chmod <directory>";
             echo "  fetch <remote>";
             shift; } ;;
     *) shift ;;
   esac
done
