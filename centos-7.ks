# livemedia-creator --no-virt --make-tar --ks centos-7.ks --image-name=centos-root.tar.xz --project "CentOS 7 RootFS" --releasever "7"
# rm -rf /mnt/* ; tar -Jxf /var/tmp/centos-root.tar.xz -C /mnt
# cd /mnt ; find . -print0 | cpio --null -ov --format=newc | gzip -9 > ~/rootfs.gz

# scp root@172.21.1.131:~/rootfs.gz ~ ; scp ~/rootfs.gz 172.21.0.70:~

# Basic setup information
url --url="http://mirrors.kernel.org/centos/7/os/x86_64/"
install
keyboard us
rootpw --plaintext root
timezone --isUtc --nontp UTC
selinux --disabled
firewall --disabled
network --bootproto=dhcp --device=link --activate --onboot=on
shutdown
bootloader --disable
lang en_US

# Repositories to use
repo --name="CentOS" --baseurl=http://mirror.centos.org/centos/7/os/x86_64/ --cost=100
repo --name="Updates" --baseurl=http://mirror.centos.org/centos/7/updates/x86_64/ --cost=100
repo --name="EPEL" --baseurl=http://dl.fedoraproject.org/pub/epel/7/x86_64 --cost=100
repo --name="MCP" --baseurl=http://downloads.linux.hpe.com/repo/mcp/centos/7/x86_64/current/ --cost=100
repo --name="HPE_SUM" --baseurl=http://downloads.linux.hpe.com/repo/hpsum/rhel/7/x86_64/current/ --cost=100

# Disk setup
zerombr
clearpart --all --initlabel
part / --size 3000 --fstype ext4

# Package setup
%packages --excludedocs --instLangs=en --nocore
rpm
bash
nano
iputils
iproute
systemd
rootfiles
passwd
hpsum
hponcfg

%end

%pre
# Pre configure tasks

# Don't add the anaconda build logs to the image
# see /usr/share/anaconda/post-scripts/99-copy-logs.ks
touch /tmp/NOSAVE_LOGS
%end

%post --log=/anaconda-post.log
# Post configure tasks

# Install HPSUM
yum localinstall -y --nogpgcheck http://downloads.linux.hpe.com/repo/hpsum/rhel/7/x86_64/current/hpsum-7.6.0-86.rhel7.x86_64.rpm

# Update local packages
yum update -y --nogpgcheck --skip-broken

# remove stuff we don't need that anaconda insists on
# kernel needs to be removed by rpm, because of grubby
rpm -e kernel

# Clean up unused directories
rm -rf /boot
rm -rf /etc/firewalld

awk '(NF==0&&!done){print "override_install_langs=en_US.utf8\ntsflags=nodocs";done=1}{print}' \
    < /etc/yum.conf > /etc/yum.conf.new
mv /etc/yum.conf.new /etc/yum.conf
echo 'container' > /etc/yum/vars/infra

# Setup locale properly
#rm -f /usr/lib/locale/locale-archive
#localedef -v -c -i en_US -f UTF-8 en_US.UTF-8

# Remove some things we don't need
rm -f /tmp/ks-script*
rm -rf /boot
rm -rf /etc/sysconfig/network-scripts/ifcfg-*
rm -rf /tmp/*
rm -rf /var/cache/yum/*
rm -rf /var/log/*

# No machine-id by default.
:> /etc/machine-id

# Fix /run/lock breakage since it's not tmpfs in docker
umount /run
systemd-tmpfiles --create --boot

# Make sure login works
rm /var/run/nologin

# Generate installtime file record
/bin/date +%Y%m%d_%H%M > /etc/BUILDTIME

# Create /init symlink
ln -s /sbin/init /init

%end
