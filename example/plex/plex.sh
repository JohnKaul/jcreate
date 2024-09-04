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

# We are mounting the `plexdata` directory so just in case, let's make
# the directory.
mv /usr/local/plexdata /usr/local/plexdata.orig         # Backup origional `plexdata` directory
mkdir -p /usr/local/plexdata                            # Make a `plexdata` directory for mounting
chown plex:plex /usr/local/plexdata                     # Make ownership of directory `plex` user.

# Create a `mediaserver` group
# -On the NAS some of the directories are owned by `mediaserver` to
#  allow for multiple media server apps to access the files.
echo "Adding mediaserver group."
pw groupadd mediaserver -g 989
pw usermod -n plex -G mediaserver

echo "Clean package installation"
pkg clean -y

# --------------- BEGIN USERSETUP --------------

# Network tuning.
echo "Tuning network options."
# {{{
echo "
# Load the H-TCP algorithm. It has a more aggressive ramp-up to max
# bandwidth, and is optimized for high-speed, high-latency connections.
cc_htcp_load=\"YES\"

# accept filters allow the kernel to buffer certain incoming connections
# until a complete request is received (such as HTTP headers). This can
# reduce the number of context switches required by the CPU.
accf_http_load=\"YES\"
accf_data_load=\"YES\"
accf_dns_load=\"YES\"

# The hostcache is used to \"grade\" the throughput of previous connections.
# Calomel says that disabling it can increase throughput on connections
# incorrectly marked as slow. I didn't notice much difference either way.
net.inet.tcp.hostcache.cachelimit=\"0\"

# This is the network interface queue length. According to this commit,
# the default value of 50 is far too low. Calomel recommends 2x the value
# of hw.igb.txd, which has worked well for me.
net.link.ifqmaxlen=\"2048\"

# Enables a faster but possibly buggy implementation of soreceive. I
# haven't had any problems with it.
net.inet.tcp.soreceive_stream=\"1\"

# FreeBSD sets an artificial limit on the number of packets an Intel card
# can process per interrupt cycle (default 100). This is almost totally
# useless on modern hardware. -1 means no limit.
hw.igb.rx_process_limit=\"-1\"
" >> /boot/loader.conf

echo "
# soacceptqueue is the kernel's backlog queue depth for accepting new TCP
# connections. A larger value should prevent clients from being dropped
# during sudden bursty periods at the expense of more RAM and CPU load.
#kern.ipc.soacceptqueue=1024  # (default 128)

# maxsockbuf is the max amount of memory that can be allocated to a socket.
# In practice, this value determines the TCP window scaling factor - the
# number of bytes that can be transmitted without requiring an ACK. If our
# server is not under heavy load, we want a large scaling factor, because
# we can transmit packets as fast as the receiver can process them.
#
# The default maxsockbuf value (2MB) will result in a scaling factor of 6,
# which is ideal for a low-latency gigabit network.
#
# However, my server is on the west coast, on a gigabit connection with
# 100ms of latency to my hometown on the east coast. A scaling factor of 8:
#
#     2^8 x 65,535-byte IP packet size = 16,776,960 bytes
#
# happens to saturates my connection:
#
#   16,776,960 bytes * 8 / .1 sec latency / 10^9 = 1.3421568 Gbps
#
# You remember Bandwidth Delay Product from networking class, right? :-)
#
# A maxsockbuf value of 8MB will yield a scaling factor of 8. To see
# how this is derived, you can check /sys/netinet/tcp_syncache.c.
#
#kern.ipc.maxsockbuf=8388608

# sendspace and recvspace are the network buffer sizes *initially* allocated
# to each TCP connection. Bandwidth can be improved by increasing the buffer
# size at the cost of using more kernel memory per connection. Saturating my
# gigabit connection with 100ms latency would require:
#
#  1000 megabits * .1 sec / 8 bits = 12.5 MB 
#
# However, just 80 simultaneous connections would immediately consume a
# GIGABYTE of RAM! Most of the traffic to my server is for small, static
# HTML pages and some SSH connections, so I've set a smaller default size:
#
#   256 KB = 256 * 1024 bytes = 262,144 bytes
#
# The kernel will allocate more memory as needed (at a very slight
# performance hit) for the occasional full-throttle transfer of large
# files.
#
#net.inet.tcp.sendspace=262144  # (default 32768)
#net.inet.tcp.recvspace=262144  # (default 65536)

# sendbuf_max and recvbuf_max control the maximum send and recv buffer sizes
# the kernel will ever allocate for a single TCP connection. I set mine to
# 16 MB, which is slightly higher than the 12.5 MB I calculated above. This 
# should let me to saturate my 100ms connection, as well as leave some
# wiggle room to saturate even higher-latency clients.
#
# You should probably make sure these values are at least as large as
# maxsockbuf.
#
#net.inet.tcp.sendbuf_max=16777216
#net.inet.tcp.recvbuf_max=16777216

# sendbuf_inc and recvbuf_inc control the increments by which the kernel
# increases sendspace and recvspace to sendbuf_max and recvbuf_max,
# respectively. Higher values will cause fewer memory allocations, but may
# result in wasted buffer space.
#
net.inet.tcp.sendbuf_inc=32768  # (default 8192)
# net.inet.tcp.recvbuf_inc=65536  # (default 16384)

# increase the localhost buffer space, which may help localhost-only servers
# more efficiently move data to network buffers.
#net.local.stream.sendspace=16384  # default (8192)
#net.local.stream.recvspace=16384  # default (8192)

# increase the raw IP datagram buffers to the MTU for the localhost
# interface (2^14 bytes = 16384). Thanks, Calomel!
#net.inet.raw.maxdgram=16384
#net.inet.raw.recvspace=16384


# *** these two settings gave me the most drastic improvement: ***

# TCP Slow Start gradually ramps up the data transmission rate until the
# throughput on the network path has been determined. TCP Appropriate Byte
# Counting (ABC) allows the kernel to increase the window size
# exponentially. According to Calomel, with maxseg set to the default of
# 1460 bytes, setting abc_l_var to 44 allows an increase of about 64 KB per
# echo, which happens to be the receive buffer size of most hosts that don't
# support window scaling.
#
net.inet.tcp.abc_l_var=44          # (default 2)

# The TCP initial congestion window determines the *initial* amount of data
# that can be sent over the network before requiring an ACK from the other
# side. The Slow Start algorithm will improve this value over time. A larger
# initcwnd will speed up short, bursty connections. Google recommends 16,
# but according to Calomel, you should also test 44.
net.inet.tcp.initcwnd_segments=44  # (default 10)

# Maximum Segment Size (MSS) specifies the largest amount of data that can
# be placed in a single IPv4 TCP segment. This value is usually equal to:
#
#   MTU (usually 1500) - 20 byte IPv4 header - 20 byte TCP header = 1460
#
# If you have net.inet.tcp.rfc1323 enabled (it is by default on FreeBSD),
# then TCP hosts can negotiate timestamps which increases the TCP headers
# by 12 bytes. So in the case we'll use 1460 - 12  = 1448 bytes.
#
net.inet.tcp.mssdflt=1448  # (default 536)

# The Minimum MSS specifies the smallest amount of data we will send in a
# single IPv4 TCP segment. RFC 6691 requires a minimum value of 576 bytes.
# Subtracting a 20 byte IP header and 20 (or 32, see above) byte TCP header
# gives us:
#
#  576 (minimum MTU) - 20 byte IPv4 header - 32 byte TCP header = 524 bytes.
#
net.inet.tcp.minmss=524  # (default 216)

# use the H-TCP algorithm that we enabled in /boot/loader.conf above.
# net.inet.tcp.cc.algorithm=htcp

# Enable H-TCP's adaptive backoff optimization, which increases buffer
# efficiency along the network path.
#net.inet.tcp.cc.htcp.adaptive_backoff=1

# Enable H-TCP's RTT scaling optimization, which increases fairness between
# flows with different RTTs.
#net.inet.tcp.cc.htcp.rtt_scaling=1

# RFC 6675 improves TCP Fast Recovery when combined with SACK (which is
# enabled by default on FreeBSD - net.inet.tcp.sack.enable)
#net.inet.tcp.rfc6675_pipe=1

# Disabling syncookies will give us more TCP features like window scale and
# timestamps at the expense of making us more vulnerable to DoS attacks.
net.inet.tcp.syncookies=0

# disable the TIME_WAIT state for the localhost interface, this should
# result in localhost sockets being freed more quickly.
net.inet.tcp.nolocaltimewait=1

# TSO (and LRO) should be disabled on machines that forward packets. I use
# OpenVPN, sometimes, so I've disabled TSO here. These options can also be
# disabled in /etc/rc.conf using the \`-tso -lro\` options.
net.inet.tcp.tso=0

# these two values control the number of frames the NIC will accept before
# firing an interrupt. If the queue fills up and the machine is overloaded,
# packets will be dropped. Increasing this value should mitigate packet loss
# in case of a storm of short, bursty packets, but if
# net.inet.ip.intr_queue_drops remains greater than 0, you probably just
# need better hardware.
#
#net.inet.ip.intr_queue_maxlen=2048  # (default 256)
#net.route.netisr_maxqlen=2048       # (default 256)
" >> /etc/sysctl.conf

sysctl -f /etc/sysctl.conf
# }}}

# Users
echo "Setting up admin user."
# {{{
echo "  Creating user"
# {{{
pw user add -n admin -d /home/admin -G wheel -m -s /bin/csh -w yes
#pw usermod -n admin -u 501
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

# Slim down jail (optional echo; delete section if not necessary).
# Stolen from BSDPot-git-nomad potluck
echo "Sliming binaries"
# {{{

export PATH=/usr/local/bin:$PATH

dirs="/usr/share/bsdconfig /usr/share/doc /usr/share/dtrace /usr/share/examples /usr/share/man /usr/share/openssl /usr/share/sendmail /usr/share/pc-sysinstall /usr/libexec/bsdinstall /usr/libexec/bsdconfig /rescue /usr/tests /usr/lib32 /usr/lib/clang /usr/include /var/db/freebsd-update /var/db/etcupdate /boot"
usr_bin="c++ c++filt c89 c99 cc CC cpp clang clang-cpp clang-tblgen clang++ gdb gdbtui gdbserver ld ld.bfd ld.lld lldb llvm-objdump llvm-tblgen nm objcopy objdump strings strip"
usr_bin_glob="svnlite yp"

usr_sbin="dtrace"
usr_sbin_glob="bhyve boot yp"
rm -f /usr/lib/*.a
## Remove pkg stuff
rm -rf /var/db/pkg/*
rm -rf /usr/sbin/pkg
rm -rf /usr/local/sbin/pkg

for d in $dirs ; do
	rm -rf "$d"
done
(
	cd /usr/bin || exit 1
	for f in $usr_bin ; do
		rm -f "$f"
	done
	for g in $usr_bin_glob ; do
		rm -rf "$g"*
	done
)
(
	cd /usr/sbin || exit 1
	for g in $usr_sbin_glob ; do
		rm -rf "$g"*
	done
	rm -f $usr_sbin
)

# }}}

# ---------------- END USER SETUP ---------------
