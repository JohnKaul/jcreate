---------------------------------------------------------------------
author: John
date:   Aug 29 2024
---------------------------------------------------------------------

# emby
This is a example emby template for the `jcreate.sh` script.

This configuration will install packages from the host system and slim
the jail down (remove some binaries, example files, pkg, compiler,
etc.). Because of this, all package maintence should be run from host
system.

Example:
```
    $ doas pkg -j emby install -y <package>
```
## NOTES
1. This jail also allows for admin access via ssh.
```
    user: admin
    pass: admin
```

2. SSH settings set by this example script:
```
    SSH Keys:   ed25519
    SSH Port:   22
```

## PASSWORDLESS LOGIN
To enable passwordless login, public key(s) should be uploaded to this server. From remote machine:

1. Copy public key up to the server.
```
        ssh-copy-id -i ~/.ssh/id_ed25519.pub 192.168.0.212
```
2. Crete an entry in '~/.ssh/config'.
```
        Host emby
                User admin
                Hostname 192.168.0.212
                IdentityFile ~/.ssh/id_ed25519
```

