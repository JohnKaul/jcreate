#!/bin/sh
#
# plexsetup.sh --
#  This file does the setup of the jail.
#  -i.e. Creates user, setups ssh, installs packages, etc.

# -------------- BEGIN PACKAGE SETUP -------------
# {{{
echo "Bootstrap package repo"
mkdir -p /usr/local/etc/pkg/repos
# only modify repo if not already done in base image
# shellcheck disable=SC2016
test -e /usr/local/etc/pkg/repos/FreeBSD.conf || \
  echo 'FreeBSD: { url: "pkg+http://pkg.FreeBSD.org/${ABI}/quarterly" }' \
    >/usr/local/etc/pkg/repos/FreeBSD.conf
ASSUME_ALWAYS_YES=yes pkg bootstrap

echo "Touch /etc/rc.conf"
touch /etc/rc.conf

echo "Disable sendmail"
service sendmail onedisable || true

echo "Create /usr/local/etc/rc.d"
mkdir -p /usr/local/etc/rc.d
# }}}

echo "Install package rsync"
# used to sync possible update scripts or other misc.
# `fetch` could also be used so this may not be necessary.
pkg install -y rsync

echo "Intall git-tiny"
# used to pull possible update scripts or other misc.
# `fetch` could also be used so this may not be necessary.
pkg install -y git-tiny

echo "Install package openssh"
# This is used to allow for admin user to SSH into jail.
pkg install -y openssh-portable

# Plexmediaserver install
echo "Install package Plexmediaserver"
pkg install -y plexmediaserver
sysrc plexmediaserver_enable="YES"
service plexmediaserver start || true

# Create a `mediaserver` group
echo "Adding mediaserver group."
pw groupadd mediaserver -g 989
pw usermod -n plex -G mediaserver

echo "Clean package installation"
pkg clean -y

# --------------- BEGIN USERSETUP --------------

# Users
echo "Setting up admin user."
# {{{
echo "  Creating user"
# {{{
pw user add -n admin -d /home/admin -G wheel -m -s /bin/csh -w yes
chmod 754 /home/admin
# }}}
# Setup .nexrc
# {{{
echo "
\" Show line numbers
set nu

\" Show matching brackets
set showmatch
set matchchars='()[]{}<>'

\" Rename the window to the current filename.
set windowname

\" Break lines automatically
set wraplen=76

\" Define the point at which lines wrap in vanilla mode
\" set wrapmargin=74

\" Autoindent
set autoindent

\" Show current mode in status line
set verbose showmode

\" Set TAB width
set tabstop=4

set backup=N%~
\" If this option is set, it specifies a pathname used as a backup
\" file, and, whenever a file is written, the file's current
\" contents are copied to it. The pathname is \"#\", \"%\" and \"!\"
\" expanded.
\" 
\" If the first character of the pathname is \"N\", a version number
\" is appended to the pathname (and the \"N\" character is then
\" discarded). Version numbers are always incremented, and each
\" backup file will have a version number one greater than the
\" highest version number currently found in the directory.
\" 
\" Backup files must be regular files, owned by the real user ID of
\" the user running the editor, and not accessible by any other
\" user. 
\" 
\" How those \"#\", \"%\" and \"!\" are expanded?
\" 
\"         # Alternate filename
\"         % Current filename
\"         ! Shell expansion -- pooly explained in the documentation,
\"                              IMHO. Seems to work as for double-quote
\"                              interpreted strings in the shell.
\" An example of shell expansion:
\" 
\" :set backup=%.\$(date^V|sed\ 's/\ /\\&/g')
\" 
\" (Alter the \$(...) syntax depending on your shell.)
\" 
\" The ^V needs to be a real ctrl-v character produced by
\" pressing ctrl-v ctrl-v: you can't cut and paste the line
\" above. This is to prevent the \`\|\' from being seen as the end
\" of the :set command.
\" 
\" Setting \`backup\' to the above appends the date to the
\" current filename to create the backup name. Spaces need to
\" be escaped, hence the backslashes and the work with sed.

\" --------------------------
\" MACROS
\"
\" NOTE: The \`^M\` characters below are \`returns\`. You make them by
\"       typing: \`CTRL-v\` then \`RETURN\`.
\" --------------------------
\" Invoke \`fmt\` to format the paragraph
map Q !}fmt

\" Quit the file
map ,q :quit

\" Save (write) the file
map ,w :write

\" Delete the rest of the line
map D d$

\" Jump to the beginning of the line
map H ^0

\" Encapsulates current line with C comment marks
\"map \ I\* \A *\\

\" Add a pound symbol (#) to the beginning of the line
map \ I#

\"
\" Classic vi user community macros for completion 
\" based on previous or next instances of a word
\" in the current buffer that matches the current 
\" substring
map!  a. hbmmi?\<2h\"zdt.@zywmx\`mP xi
map!  a. hbmmi/\<2h\"zdt.@zywmx\`mP xi

\"
\" --------------------------
\"
\" Abbreviations
ab het the
ab teh the
ab dont don't
ab couldnt couldn't
ab alos also
ab aslo also
ab charcter character
ab charcters characters
ab exmaple example
ab shoudl should
ab seperate separate
ab teh the
ab wnat want
ab yuo you
ab dont don't
ab thoughtfull thoughtful
ab couldnt couldn't
ab certian certain
ab catagory category
ab approx approximately

\"
\" --------------------------
\"
" > /home/admin/.nexrc

chown admin:admin /home/admin/.nexrc
chmod 644 /home/admin/.nexrc
# }}}
echo "  Adding empty authorized key file"
# {{{
mkdir -p /home/admin/.ssh
touch /home/admin/.ssh/authorized_keys

chown -R admin:admin /home/admin/.ssh
chmod 700 /home/admin/.ssh
chmod 600 /home/admin/.ssh/authorized_keys
# }}}
echo "  Adding .cshrc" 
# {{{
echo "# csh initialization

alias df	df -k
alias du	du -k
alias f		finger
alias h		'history -r | more'
alias j		jobs -l
# The 'ls' family (this assumes you use the GNU ls)
# alias la	ls -a
alias lf	ls -FA
alias ll	ls -lsA
alias la        ls -Al                  # show hidden files
alias lx        ls -lXB                 # sort by extension
alias lk        ls -lSr                 # sort by size
alias lc        ls -lcr		        # sort by change time  
alias lu        ls -lur		        # sort by access time   
alias lr        ls -lR                  # recursive ls
alias lt        ls -ltr                 # sort by date
alias lm        'ls -al | more'         # pipe through 'more'
alias ls        ls -FAG                 # display a dir and exe
alias grep      'fgrep --exclude-dir .git --exclude-dir bin --exclude tags -I --line-number --recursive --no-messages --color=auto --context=2 --ignore-case'
#alias z		suspend
alias su        'su -m'                 # keep my shell when using SU.

# set path = (~/bin /bin /sbin /usr/{bin,sbin,X11R6/bin,local/bin,local/sbin,games})

if (\$?prompt) then
	# An interactive shell -- set some stuff up
	set filec
	set history = 1000
	set ignoreeof
	# set mail = (/var/mail/\$USER)
	set mch = \`hostname -s\`
	alias prompt 'set prompt = \"[\$mch:q\"\":\$cwd:t]\"'
	alias cd 'cd \\!*; prompt'
	alias chdir 'cd \\!*; prompt'
	alias popd 'popd \\!*; prompt'
	alias pushd 'pushd \\!*; prompt'
	cd .
	umask 22
endif
" > /home/admin/.cshrc

chown admin:admin /home/admin/.cshrc
chmod 644 /home/admin/.cshrc
# }}}
# }}}

# SSH
echo "Setting up SSH access."
# {{{
#touch /etc/local/etc/ssh/sshd_config
echo "  Creating /etc/ssh/sshd_conf file."
echo "#Port 2255        # Since we are using OpenSSH this value should go in '/usr/local/etc/ssh/sshd_config'.
Protocol 2
HostKey /etc/ssh/ssh_host_ed25519_key

PermitRootLogin no     # Off by default but put here as a reminder/flag.
StrictModes yes

PasswordAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes

IgnoreUserKnownHosts no
## Don't read the user's ~/.rhosts and ~/.shosts files
IgnoreRhosts yes

## override default of no subsystems
Subsystem	sftp	/usr/libexec/sftp-server

AllowUsers admin
" > /etc/ssh/sshd_config

echo "  Enable OpenSSH"
sysrc openssh_enable="YES"
service openssh enable || true

echo "  Generate host keys"
/usr/bin/ssh-keygen -A                 # Generate all keys.

echo "  Starting OpenSSH"
service openssh start || true
service openssh restart || true
# }}}

# ---------------- END USER SETUP ---------------
