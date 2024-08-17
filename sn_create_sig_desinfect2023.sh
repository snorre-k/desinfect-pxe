#!/bin/bash


YEAR=2023
P=00
SIG="/srv/shares/sigdesinfect/$YEAR"
SUB="desinfect-signatures"

## Signatures
  if ! [ -d $SIG ]; then
  echo "$SIG"
  mkdir -p $SIG
  chmod 777 $SIG
fi

if ! [ -d $SIG/$SUB ]; then
  echo "$SIG/$SUB"
  mkdir $SIG/$SUB
fi

for i in clamav eset f-secure msdefender thorlite yara; do
  if ! [ -d $SIG/$SUB/$i ]; then
    echo "$SIG/$SUB/$i (incl. .syncme)"
    mkdir $SIG/$SUB/$i
    touch $SIG/$SUB/$i/.syncme
  fi
done

if ! [ -f $SIG/.desinfect$YEAR ]; then
  echo "$SIG/.desinfect${YEAR}$P"
  touch $SIG/.desinfect${YEAR}$P
fi


# Debs
echo "$SIG/deb"
mkdir $SIG/deb
for i in $(ls "$(dirname "$0")/${YEAR}_deb"); do
  echo "$SIG/deb/$i"
  cp "$(dirname "$0")/${YEAR}_deb/$i" $SIG/deb
done

# Userinit Scripts
echo "$SIG/userinit.sh"
cat <<EOF >$SIG/userinit.sh
#!/bin/bash


## Set Time
sudo /opt/desinfect/busybox ntpd -ddd -n -q -p de.pool.ntp.org
sudo hwclock --systohc


##Bugfix NFS Locks for f-secure setup - mount with NFSv3
# Copy script to /tmp to be able to umount
if ! [ -x /tmp/\$(basename \$0) ]; then
  cp \$0 /tmp
  exec /tmp/\$(basename \$0)
fi

# Check MP (nfssigs) in /proc/cmdline
for i in \$(cat /proc/cmdline); do echo \$i | grep -q nfssigs && eval \$i; done

sleep 10
sudo umount /opt/desinfect/signatures
# Mount with NFS3 and local_locks enabled
sudo mount -o nfsvers=3,local_lock=all \$nfssigs /opt/desinfect/signatures


## SSH Password desinfect
echo desinfect:a | sudo chpasswd


## PXE Info
echo "WARNING: The scan buildin update does not work with PXE!" > /home/desinfect/Desktop/PXE.txt
echo "WARNING: after start before a scan do an update" >> /home/desinfect/Desktop/PXE.txt
echo "         either all with: sudo bash /opt/desinfect/update_sigs.sh" >> /home/desinfect/Desktop/PXE.txt
echo "         or defined with: sudo bash /opt/desinfect/update_%scanner%.sh" >> /home/desinfect/Desktop/PXE.txt
EOF

chmod +x $SIG/userinit.sh

echo
echo "WARNING: The scan buildin update does not work with PXE!"
echo "WARNING: after start before a scan do an update"
echo "         either all with: sudo bash /opt/desinfect/update_sigs.sh"
echo "         or defined with: sudo bash /opt/desinfect/update_%scanner%.sh"
echo
