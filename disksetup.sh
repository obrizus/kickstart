
DISK_NAME="rootfs"
PARTITION_SIZE="12M"

DISK_IMAGE="${DISK_NAME}.img"
DISK_MOUNT="/mnt/${DISK_NAME}"

START_SECTOR="63"
SECTOR_SIZE="512"
MOUNT_OFFSET="$((${START_SECTOR}*${SECTOR_SIZE}))"

NUM_BLOCKS="8000"

# Create veirtual hard disk image
qemu-img create -f raw ${DISK_IMAGE} ${PARTITION_SIZE}

# Attach hard disk image

# Partition disk image
fdisk /dev/loop0
#n p 1 1 a w

fdisk -l -u /dev/loop0

losetup -d /dev/loop0

losetup -o ${MOUNT_OFFSET} /dev/loop0 ${DISK_IMAGE}

mke2fs -b 1024 /dev/loop0 ${NUM_BLOCKS}

losetup -d /dev/loop0

test -e ${DISK_MOUNT} || mkdir /mnt/${DISK_MOUNT}
mount -o loop,offset=${MOUNT_OFFSET} ${DISK_IMAGE} ${DISK_MOUNT}

cd ${DISK_MOUNT}
mkdir boot
mkdir boot/grub
touch boot/grub/grub.conf
ln -s boot/grub/grub.conf boot/grub/menu.lst
cp /usr/lib/grub/i386-pc/stage1 boot/grub
cp /usr/lib/grub/i386-pc/stage2 boot/grub
cp /usr/lib/grub/i386-pc/e2fs_stage1_5 boot/grub

