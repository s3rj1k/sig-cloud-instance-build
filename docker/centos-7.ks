# This is a minimal CentOS kickstart designed for docker.
# It will not produce a bootable system
# To use this kickstart, run the following command
# livemedia-creator --make-tar \
#   --iso=/path/to/boot.iso  \
#   --ks=centos-7.ks \
#   --image-name=centos-root.tar.xz
#
# Once the image has been generated, it can be imported into docker
# by using: cat centos-root.tar.xz | docker import -i imagename

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
yum
centos-release
bash
nano
-kernel*
-*firmware
-firewalld-filesystem
-os-prober
-gettext*
-GeoIP
-bind-license
-freetype
iputils
iproute
systemd
rootfiles
-libteam
-teamd
tar
passwd
hpsum
hponcfg

%end

%pre
# Pre configure tasks for Docker

# Don't add the anaconda build logs to the image
# see /usr/share/anaconda/post-scripts/99-copy-logs.ks
touch /tmp/NOSAVE_LOGS
%end

%post --log=/anaconda-post.log
# Post configure tasks for Docker

# remove stuff we don't need that anaconda insists on
# kernel needs to be removed by rpm, because of grubby
rpm -e kernel

yum -y remove bind-libs bind-libs-lite \
  dracut-network e2fsprogs e2fsprogs-libs ebtables ethtool file \
  firewalld freetype gettext gettext-libs groff-base grub2 grub2-tools \
  grubby initscripts iproute iptables kexec-tools libcroco libgomp \
  libmnl libnetfilter_conntrack libnfnetlink libselinux-python lzo \
  libunistring os-prober python-decorator python-slip python-slip-dbus \
  snappy sysvinit-tools which linux-firmware GeoIP firewalld-filesystem \
  qemu-guest-agent

yum clean all

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
