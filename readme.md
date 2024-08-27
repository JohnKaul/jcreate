<!--------------------------------------------*- MARKDOWN -*------
File Last Updated: 08.24.24 16:40:03

Author:  John Kaul <john.kaul@outlook.com>
------------------------------------------------------------------>

# jcreate

## BRIEF

jcreate [configfile]
jdestroy [jailname]

## DESCRIPTION

A few shell scripts to create/destroy classic jails in FreeBSD with a
`jail.conf` file located in `/etc/jail.conf.d/`.

These scripts are not very robust and/but should offer a very
simplistic jail manager. The jail configurations are done with a
user supplied script which is copied in and run. 

Configutation is done with a few simple config files; 1. for the
userland location 2. another for the "jailname" type.  The location of
the `jcreate.conf` file (userland location) is located at the same
location as the installation directory.

## BASIC JAIL CONFIGURATION
We first need to establish some defaults in the `jail.conf` file in `/etc/`.

The `/etc/jail.conf/` should look something like (your needs may very slightly):
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
Configuration for `jcreate.sh` is only so the script knows where to
find the userland.

The default `jcreate.conf` confuration file should contain the following variables.  

-media.path
A location to where the userland.

-containers.path
A location where to extract the userland (where the jail will reside)

## TEMPLATE CONFIGURATION
To create a jail, `jcreate` needs a few more variables and these are specific to each jail.

-jail.name REQUIRED
The name of the jail

-jail.epairid REQUIRED
This is the last few digits of the jails IP address.

-jail.mounts OPTIONAL
The file which contains the mount locations.

-jail.config OPTIONAL
The configuration script to be copied into the jail and executed.

A template with only the required vaiables, `jcreate` will create a conf file that will look as simple as:
```
myjail {
    # NETWORKS/INTERFACES
    $id = "63";
}
```

## BUILD INSTRUCTIONS 

The default location for this script is: `~/bin/` but you can also run a
simple `configure` script to change that location.

```bash
$ cd jcreate
$ make install
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
Created for personal use.

## AUTHOR
* John Kaul - john.kaul@outlook.com
