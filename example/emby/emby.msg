
*This jail has been slimmed down*
This jail has had some binaries, example files, pkg, compilers, etc.
removed. All package maintence should be run from host system.

Example:
$ doas pkg -j emby install -y <package>


*How to use the Backup & Restore Plugin*

1. Be sure your Emby Premiere key is properly installed and validated.

2. Install the "Backup & Restore" plugin on the new Emby Server
   installation, then configure to backup folder to the same parent
   folder that contains your backups.

3. Click on a backup, you'll then be taken to the restore screen where
   you can run a restore.

Note: if previous backups do not show up correctly, check to make sure
      you have selected the parent folder and not the specific folder
      holding the backups.
