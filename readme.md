<!--------------------------------------------*- MARKDOWN -*------
File Last Updated: 12.11.24 19:52:30

Author:  John Kaul <john.kaul@outlook.com>
------------------------------------------------------------------>

# jcreate / jdestroy / jlist / script-writer

## BRIEF

jcreate configfile

jdestroy jailname

jlist

script-writer.sh adduser JOHN ABC123

## DESCRIPTION

A few shell scripts to create/destroy classic jails in FreeBSD with a
`jail.conf` file located in `/etc/jail.conf.d/`.

These scripts are not very robust and/but should offer a very
simplistic jail creation tool. The jail configurations are done with a
user supplied script which is copied in and run.

Jail creating configutation is done with a few simple config files;
1. for the userland location (where to get and extract the userland from/to)
2. another for the jail type (name of jail, mount points, etc.)

## BASIC JAIL CONFIGURATION
We first need to establish some defaults in the `jail.conf` file in `/etc/`.

The `/etc/jail.conf` should look something like (your needs may very slightly):
```script
    # DEFAULT OPTIONS
    # (COMMON TO ALL JAILS)

    # STARTUP/LOGGING
    exec.start = "/bin/sh /etc/rc";
    exec.stop  = "/bin/sh /etc/rc.shutdown";
    exec.consolelog = "/var/log/jail_console_${name}.log";

    # PERMISSIONS
    allow.raw_sockets;
    exec.clean;
    #mount.devfs;
    #devfs_ruleset = 5;

    # PATH/HOSTNAME
    path = "/usr/local/jails/containers/${name}";
    host.hostname = "${name}";

    # VNET/VIMAGE
    vnet;
    vnet.interface = "${epair}b";

    # NETWORKS/INTERFACES
    $ip             =   "192.168.0.${id}/24";
    $epair          =   "epair${id}";
    $gateway        =   "192.168.0.1";
    $bridge         =   "bridge0";

    # ADD TO bridge INTERFACE
    exec.prestart   =   "/sbin/ifconfig ${epair} create up";
    exec.prestart   +=  "/sbin/ifconfig ${epair}a up descr jail:${name}";
    exec.prestart   +=  "/sbin/ifconfig ${bridge} addm ${epair}a up";
    exec.start      +=  "/sbin/ifconfig ${epair}b ${ip} up";
    exec.start      +=  "/sbin/route add default ${gateway}";
    exec.poststop   =   "/sbin/ifconfig ${bridge} deletem ${epair}a";
    exec.poststop   +=  "/sbin/ifconfig ${epair}a destroy";

    .include "/etc/jail.conf.d/*.conf";
```

## JCREATE CONFIGURATION
Configuration for `jcreate` is only so the script knows where to
find the userland and where to extract it to.

The default `jcreate.conf` confuration file should contain the following variables.

* `media.path` (REQUIRED) - A location to where the userland.
* `containers.path` (REQUIRED) - A location where to extract the userland (where the jail will reside)
* `containers.conf` (REQUIRED) - A location where to store the jail configuration files.

## TEMPLATE CONFIGURATION
To create a jail, `jcreate` needs a few more variables and these are specific to each jail.

* `jail.name` (REQUIRED) - The name of the jail
* `jail.epairid` (REQUIRED) - This is the last few digits of the jails IP address.
* `jail.packages` (OPTIONAL) - A file with a list of packages to be istalled via the host system.
* `jail.mounts` (OPTIONAL) - The file which contains the mount locations.
* `jail.config` (OPTIONAL) - The configuration script to be copied into the jail and executed.
* `jail.mlock=1` (OPTIONAL) - Allow jail to mlock.
* `jail.systemv=1` (OPTIONAL) - Allow all three `sysvmsg`, `sysvsem`, and `sysvshm` options.
* `jail.sysvmsg=new` (OPTIONAL) - Allow access to SYSV IPC message primitives.  If set to “inherit”, all IPC objects on the system are visible to this jail, whether they were created by the jail itself, the base system, or other jails.  If set to “new”, the jail will have its own key namespace, and can only see the objects that it has created; the system (or parent jail) has access to the jail's objects, but not to its keys.  If set to “disable”, the jail cannot perform any sysvmsg-related system calls.
* `jail.sysvsem=new` (OPTIONAL) - Allow access to SYSV IPC semaphore and shared memory primitives, in the same manner as sysvmsg.
* `jail.sysvshm=new` (OPTIONAL) - Allow access to SYSV IPC semaphore and shared memory primitives, in the same manner as sysvmsg.
* `jail.poststart` (OPTIONAL) - Command(s) to run in the system environment after a jail is created, and after any exec.start commands have completed.
* `jail.prestop` (OPTIONAL) - Command(s) to run in the system environment before a jail is removed.

A template with only the required vaiables, `jcreate` will create a conf file that will look as simple as:
```
myjail {
    # NETWORKS/INTERFACES
    $id = "63";
}
```

### EXAMPLES
Two (2) examples are in the `examples` folder.  Each example will set
up an admin user (`admin`) with a password of `admin` for ssh access.

* plex - A template which installs packages and jail setup up via a
  script file which is copied into the jail and run. See the `plex.sh`
  script.

* emby - A template which is slimmed down and packages are installed
  via the host system.

## INSTALL INSTRUCTIONS

### DEFAULT LOCATIONS
Run `configure` to change locations.

| FILE          | LOCATION                    |
| ------------- | --------------------------- |
| jcreate       | /usr/local/bin              |
| jdestroy      | /usr/local/bin              |
| jlist         | /usr/local/bin              |
| jcreate.conf  | /usr/local/etc              |
| jcreate.7     | /usr/local/share/man/man7   |

```bash
$ cd jcreate
$ doas make install
```

# JLIST DESCRIPTION
Because the base `jls` utility does not display the jail's IP if the
jail uses VNET, I have included an alternate script (`jlist`) to
display a list of jails that will also list a jails IP address.

The `jlist` will display jails like:
```script
   JID  NAME         IP               HOSTNAME         OS RELEASE       PATH
   1    emby         192.168.1.1      emby             14.1-RELEASE     /usr/local/jails/containers/emby
   2    plex         192.168.1.2      plex             14.1-RELEASE     /usr/local/jails/containers/plex
```

# SCRIPT-WRITER DESCRIPTION
A script is included which may aid in the creation of jail setup
scripts called `script-writer`. Pass this script some arguments and it
will print out the commands necessary to complete those tasks.

This script is NOT meant to be perfect or exhaustive, it's only goal
is to offer a starting point from which futher, more fine grained
additions, can be made.

## USAGE
```
	script-writer.sh help
```

## EXAMPLE
```script
	$ ./script-writer.sh adduser JOHN ABC123
```
will output:
```script
      #!/bin/sh
      # ------------------------------------------------

      # Bail out if we don't have root privileges.
      if [ $(id -u) -ne 0 ]; then
         echo "This script must be run as root."
         exit 1
      fi

      # Adding user: JOHN
      # NOTE: user will have a password set the same as their username.
      echo "Making user: JOHN"
      pw user add -n JOHN -d /home/JOHN -G wheel -m -s /bin/tcsh -w yes
      chmod 754 /home/JOHN

      # Adding user SSH key
      # Create the directory, file and set the proper
      # permissions as well as adding the key.
      echo "Adding users public key."
      mkdir -p /home/JOHN/.ssh
      touch /home/JOHN/.ssh/authorized_keys
      echo "ABC123" > /home/JOHN/.ssh/authorized_keys
      chown -R JOHN:JOHN /home/JOHN/.ssh
      chmod 700 /home/JOHN/.ssh
      chmod 600 /home/JOHN/.ssh/authorized_keys
```
Since these scripts need to be maintained every once and an while it
may be easier to create a "master script" to call the script-writer
script:

## EXAMPLE
`jailsetup_ACME.sh` (which, when called will generate the output
helper setup script that can be installed into the jail to run):

```script
      #!/bin/sh
      script-writer.sh \
              install ACME \
              install ACME2 \
              adduser JOHN ABC123 \
              start ACME \
              makedir /var/db \
              start ACME2 \
              > ACME.sh
```
## CONTRIBUTION GUIDELINES

### Git Standards

#### Commiting

1.  Commit each file as changes are made.
2.  Do not commit files in batch.
3.  Please prefix all commits with the file you are commiting.
4.  Separate subject from body with a blank line
5.  Limit the subject line to 50 characters
6.  Capitalize the subject line
7.  Do not end the subject line with a period
8.  Use the imperative mood in the subject line
9.  Wrap the body at 72 characters
10. Use the body to explain what and why vs. how

## HISTORY
Created for my personal use.

## AUTHOR
* John Kaul - john.kaul@outlook.com
