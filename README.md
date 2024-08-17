# Desinfec't PXE Boot
[Desinfec't](https://www.heise.de/suche?q=desinfect) is an offline virus and thread scanning tool provided by the German [Heise computer magazine c't](https://www.heise.de/ct).
It has the ability to be started with a PXE boot system.
Some prepatations not mentioned in the c't descriptions are nessesary, to get things done.
There are also some drawbacks which come with this solution (mentioned later)

## Requirements
- working PXE boot environment consisting of
  - DHCP server providing
    - `next-server` - IP of TFTP server
    - `filename` - name of PXE boot file (I use the iPXE files `ipxe.efi` for UEFI and `undionly.kpxe` for BIOS boots)
  - TFTP server running on `next-server` IP, providing
    - PXE boot files specified by `filename`
    - BOOT configuration file loaded by PXE boot file - this depends on the used PXE boot file - e.g.:
      - [Syslinux PXELINUX](https://wiki.syslinux.org/wiki/index.php?title=PXELINUX)
      - [iPXE](https://ipxe.org/howto/chainloading)
- NFS server providing shares for
  - Desinfec't system (ro)
  - Desinfec't AV signatures (rw)

## NFS server
### Desinfect System
- Export a share read only (e.g. `/pxeboot`)
- Create a folder for the OS (e.g. `/pxeboot/desinfect2024`)
- Copy the **content** of the Desinfec't ISO into this folder

### Desinfect Signatures
- Export a share read write (e.g. `/srv/shares/sigdesinfect`).
- Run the script `./sn_create_sig_desinfect%year%.sh -i` on the NFS server. The script will ask for the signature share, the year and some other stuff. It will:
  - create the year folder, e.g.: `/srv/shares/sigdesinfect/2024`
  - create the signature folders for the scanners including the `.syncme` file
  - create the hidden .desinfect%year%00 file e.g.: `/srv/shares/sigdesinfect/2024/.desifect202400`
  - create the folder /deb e.g.: `/srv/shares/sigdesinfect/2024/deb`
  - copy the content of `%year%_deb` to above folder - this can be used to install own packages e.g. `openssh-server`
  - create a `userinit.sh` script which will be executed at boot by Desinfec't

The `userinit.sh` script is nessesary to workaround the mount of the signatures share with NFSv3 and `local_locks` enabled. This is nessesary for WithSecure to work. Additionally it sets a password for the User `desinfect` (default `a` - can be changed).

## TFTP Boot Config
This is only an example. Please adapt to your needs. The example uses:
- IP of NFS server: `10.0.0.1`
- NFS OS share: `/pxeboot/desinfect2024`
- NFS SIG share: `/srv/shares/sigdesinfect/2024`
- TFTP: `tftproot/desinfect2024` containing kernel `vmliniz` and initrd `initrd.lz` copied from ISO directory `/casper`

### PXELINUX
```
LABEL desinfect2024
MENU LABEL Desinfec't 2024
LINUX desinfect2024/vmlinuz
APPEND initrd=desinfect2024/initrd.lz nfssigs=10.0.0.1:/srv/shares/sigdesinfect/2024 ip=dhcp root=/dev/nfs boot=casper xfce file=/desinfect/preseed/ubuntu.seed netboot=nfs nfsroot=10.0.0.1:/pxeboot/desinfect2024 rmdns systemd.mask=tmp.mount memtest=4 debian-installer/language=de console-setup/layoutcode?=de locale=en_US.UTF-8 noprompt noeject 
```

### iPXE with HTTP load
```
echo Booting Desinfec't 2024
set base-ip 10.0.0.1
set base-url http://${base-ip}/pxeboot/desinfect2024
kernel ${base-url}/casper/vmlinuz
initrd ${base-url}/casper/initrd.lz
imgargs vmlinuz initrd=initrd.lz nfssigs=10.0.0.1:/srv/shares/sigdesinfect/2024 ip=dhcp root=/dev/nfs boot=casper xfce file=/desinfect/preseed/ubuntu.seed netboot=nfs nfsroot=${base-ip}:/pxeboot/desinfect2024 rmdns systemd.mask=tmp.mount memtest=4 debian-installer/language=de console-setup/layoutcode?=de locale=en_US.UTF-8 noprompt noeject
boot || goto failed
goto start
```

## First Boot
Get the signatures with the call of: `sudo bash /opt/desinfect/update_all_signatures.sh`.
- The signatures of all scanners are fetched and saved to the NFS share
- Additionally all scan engines get installed.
- This also updates the Desinfec"t system incuding the Firefox browser. The packages are saved to the signature share and get reinstalled when the system is booted again.

## Scanning
Please be aware, that the signature update of the scan process does not work. To have working scanners you have to:
- Update the signature of the used scan engine after each boot. Can be done either with `sudo bash /opt/desinfect/update_all_signatures.sh` (for all engines) or woth `sudo bash /opt/desinfect/update_%scanner%.sh` (for specified scanner).
  - this installes the engine (engine is not installed after boot)
  - this gets a delta update uf the signatures
- Run the scan with signature update disabled in the `Expert` tab.

The above points are nessesary especially for WithSecure. I never got a working scan without this. Other scanners might work.