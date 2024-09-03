#!/bin/bash

## Definitions ##
YEAR=2024
P=00
SIG="/srv/shares/sigdesinfect/$YEAR"
SUB="desinfect-signatures"
INFO=/home/desinfect/Desktop/PXE_INFO.txt
desinfect_password=a
MSG="The scan buildin update does (most of the time) not work with PXE!

After each boot before starting a scan do an update:
 - either all with: sudo /opt/desinfect/update_all_signatures.sh
 - or defined with: sudo /opt/desinfect/update_%scanner%.sh

Then start the scan(s) without signature update (Expert tab)"

## End Definitions ##


## Interactive
if [ "$1" = "-i" ]; then
  echo -n "YEAR [$YEAR]: "
  read answer
  if [ "$answer" ]; then YEAR="$answer"; fi
  echo -n "Desinfect $YEAR NFS share - will be created [$SIG]: "
  read answer
  if [ "$answer" ]; then SIG="$answer"; fi
  echo -n "User \"desinfect\" password [$desinfect_password]: "
  read answer
  if [ "$answer" ]; then desinfect_password="$answer"; fi
fi

## Signatures
echo "Creating NFS directories incl. initial content:"
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
echo

## Debs
echo "Creating DEB directory - copy saved *.deb files:"
echo "$SIG/deb"
mkdir $SIG/deb
if [ -d "$(dirname "$0")/${YEAR}_deb" ]; then
  for i in $(ls "$(dirname "$0")/${YEAR}_deb"); do
    echo "$SIG/deb/$i"
    cp "$(dirname "$0")/${YEAR}_deb/$i" $SIG/deb
  done
fi
echo

## Userinit Scripts
INFO_FILE=$(basename $INFO)
echo "Creating userinit script:"
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


## SSH Password user desinfect
echo desinfect:$desinfect_password | sudo chpasswd


## PXE Info
echo "$MSG" > "$INFO"
EOF

chmod +x $SIG/userinit.sh
echo

## WARNING
echo "WARNING:"
echo "$MSG"
echo
