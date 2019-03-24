The power of ArchInstaller a little more in detail. Enjoy!

# Parameters

The script arch-install.sh supports several parameters to customize the
Archlinux installation. Some of the parameters are required but most of
them are optional.

## Required parameters

| Parameter | Explanation | Options | Example | 
|--- |--- |--- |--- | 
| -d | Target device.   | -         | sda | 
| -p | Partition layout. | brh / br  | brh: /boot, /root, /home
| | | | br:  /boot, /root
| -w | Root password, unencrypted. | - | brh: /boot, /root, /home


#. -d sda -p brh -w test-124 -b msdos -f xfs -e xfce -k de-latin1 -l en_US.UTF-8 -n arch001 -r desktop -t Europe/Berlin

## Optional parameters

| Parameter | Explanation | Options | Example | 
|--- |--- |--- |--- | 
| -b | Partition type. Default: msdos   | msdos / gpt | msdos | 
| -f | Filesystems to format the partitions. Default: ext4 | bfs / btrfs / ext2 / ext3 / ext4 / f2fs / jfs / nilfs / ntfs / reiserfs / xfs | xfs
| -c | NFS export to mount and used as pacman cache. | - | nas.local:/srv/pacman/cache
| -e | Desktop environment to install. Default: none | none / cinnamon / gnome / kde / lxde / mate / xfce | xfce
| -k | Keyboard mapping. Default: uk | See '/usr/share/kbd/keymaps/' for options. | de-latin1
| -l | System language. Default: en_GB.UTF-8 | See '/etc/locale.gen' for options. | en_US.UTF-8
| -n | Hostname, fully qualified. Default: arch.example.org | - | arch001.local
| -r | Computer role. Default: desktop | desktop / server | desktop
| -t | Timezone. Default: Europe/London | See '/usr/share/zoneinfo/' for options. | Europe/Berlin


## Example

The following command installs Archlinux with these attributes:

- Desktop system leveraging XFCE as desktop environment
- English as system language
- German keyboard layout
- German timezone
- Erase disk /dev/sda and format with a classical partitioning.
- Create three filesystems: /boot, /root and /home, the latter two
  formated with XFS, /boot is always ext2
- Simple root password, don't use it in your installation
- Set hostname to arch001.local
  
`./arch-install.sh -d sda -p brh -w test-123! -b msdos -f xfs -e xfce -k
de-latin1 -l en_US.UTF-8 -n arch001.local -r desktop -t Europe/Berlin`

# User provisioning

To provision users create a file in the following format to define user
accounts.

`
"username,password,comment,extra_groups"
`


