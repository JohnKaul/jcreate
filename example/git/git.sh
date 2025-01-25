#!/bin/sh
#
# git.sh --
#  This file does the setup of the jail.
#  -i.e. Creates user, setups ssh, installs packages, etc.

echo "Intalling packages"
pkg install -y git-tiny mdnsresponder

echo "Cleaning package installation"
pkg clean -y

# ==----------------------------------------------------------------==
# SSH access
# ==----------------------------------------------------------------==
echo "Setting up SSH access."
# {{{
echo "  Creating /etc/ssh/sshd_conf file."

cat <<_EOF_> /etc/ssh/sshd_config
# This is the sshd server system-wide configuration file.  See
# sshd_config(5) for more information.

# Note that some of FreeBSD's defaults differ from OpenBSD's, and
# FreeBSD has a few additional options.

# The default is to check both .ssh/authorized_keys and .ssh/authorized_keys2
# but this is overridden so installations will only check .ssh/authorized_keys
AuthorizedKeysFile  .ssh/authorized_keys

Protocol 2
HostKey /etc/ssh/ssh_host_ed25519_key

PasswordAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes

# override default of no subsystems
Subsystem   sftp    /usr/libexec/sftp-server

IgnoreUserKnownHosts no
# Don't read the user's ~/.rhosts and ~/.shosts files
IgnoreRhosts yes
_EOF_

echo "  Generate host keys"
/usr/bin/ssh-keygen -A                 # Generate all keys.
# }}}

# ------------------ USERSETUP -----------------
echo "Creating git user setup script."
# Mounts happen first before rc.d scripts are launched so, we create
# an rc.d script to setup git user and preform any extra things we
# need to do.
#{{{
cat <<_EOF_>/setup_gituser.sh
pw groupadd git -g 211
pw user add -n git  -c "Git Server" -d /var/db/git -u 211 -G wheel -G git -m -s /bin/sh -w yes

rm /var/db/git/.cshrc
rm /var/db/git/.login
rm /var/db/git/.login_conf
rm /var/db/git/.mail_aliases
rm /var/db/git/.mailrc
rm /var/db/git/.nexrc
rm /var/db/git/.profile
rm /var/db/git/.sh_history
rm /var/db/git/.shrc

mkdir -p /var/db/git/.ssh
if [ ! -f /var/db/git/.ssh/authorized_keys ]; then
   touch /var/db/git/.ssh/authorized_keys
   chmod go-w /var/db/git/.ssh/authorized_keys
   chown -R git:git /var/db/git/.ssh
fi

echo "StrictModes no" >> /etc/ssh/sshd_config
_EOF_
#}}}
chmod u+x /setup_gituser.sh
sysrc run_setup_path="/setup_gituser.sh"
sysrc run_setup_enable="YES"

# ==----------------------------------------------------------------==
# Services
# ==----------------------------------------------------------------==
#{{{
echo "  Enable SSHD"
sysrc sshd_enable="YES"
service sshd enable || true

echo "  Starting SSH"
service sshd start || true
service sshd restart || true

sysrc mdnsresponderposix_enable="YES"
sysrc mdnsresponderposix_flags="-n \$hostname"
#echo "mdnsresponderposix_flags=\"-n \$hostname\"" >> /etc/rc.conf
service mdnsresponderposix enable || true
service mdnsresponderposix start || true
#}}}
