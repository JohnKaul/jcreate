---------------------------------------------------------------------
author: John
date:   Aug 17 2024
---------------------------------------------------------------------

# plex
This is a example plex template for the `jcreate.sh` script.

## NOTES
1. This jail allows for admin access via ssh.
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
        Host plex
                User admin
                Hostname 192.168.0.212
                IdentityFile ~/.ssh/id_ed25519
```
