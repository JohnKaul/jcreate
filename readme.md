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
* `jail.epairid` REQUIRED - This is the last few digits of the jails IP address.
* `jail.mounts` (OPTIONAL) - The file which contains the mount locations.
* `jail.config` (OPTIONAL) - The configuration script to be copied into the jail and executed.
* `jail.mlock=1` (OPTIONAL) - Allow jail to mlock.
* `jail.systemv=1` (OPTIONAL) - Allow all three `sysvmsg`, `sysvsem`, and `sysvshm` options.
* `jail.sysvmsg=new` (OPTIONAL) - Allow access to SYSV IPC message primitives.  If set to “inherit”, all IPC objects on the system are visible to this jail, whether they were created by the jail itself, the base system, or other jails.  If set to “new”, the jail will have its own key namespace, and can only see the objects that it has created; the system (or parent jail) has access to the jail's objects, but not to its keys.  If set to “disable”, the jail cannot perform any sysvmsg-related system calls.
* `jail.sysvsem=new` (OPTIONAL) - Allow access to SYSV IPC semaphore and shared memory primitives, in the same manner as sysvmsg.
* `jail.sysvshm=new` (OPTIONAL) - Allow access to SYSV IPC semaphore and shared memory primitives, in the same manner as sysvmsg.

A template with only the required vaiables, `jcreate` will create a conf file that will look as simple as:
```
myjail {
    # NETWORKS/INTERFACES
    $id = "63";
}
```

## INSTALL INSTRUCTIONS 

### DEFAULT LOCATIONS
Run `configure` to change locations.

| FILE          | LOCATION                    |
| ------------- | --------------------------- |
| jcreate       | /usr/local/bin              |
| jcreate.conf  | /usr/local/etc              |
| jcreate.7     | /usr/local/share/man/man7   |

```bash
$ cd jcreate
$ doas make install
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
