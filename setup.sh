#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 [-y] <disk> [root_size_gb] [swap_size_gb]"
    echo "Example: $0 /dev/sda 60 8"
    echo "  -y  Skip the interactive wipe confirmation."
    exit 1
}

skip_confirm=false
if [[ "${1:-}" == "-y" ]]; then
    skip_confirm=true
    shift
fi

[[ $# -lt 1 ]] && usage

disk="$1"
root_size_gb="${2:-100}"
swap_size_gb="${3:-36}"
volume_group_name="vgmint"

confirm_disk_wipe() {
    lsblk "$disk"
    if [[ "$skip_confirm" == true ]]; then
        echo "Skipping confirmation (-y): PERMANENTLY WIPING $disk."
        return
    fi
    read -rp "This will PERMANENTLY WIPE $disk. Type YES to continue: " answer
    [[ "$answer" == "YES" ]] || { echo "Aborted."; exit 1; }
}

wipe_and_partition_disk() {
    sgdisk --zap-all "$disk"
    partprobe "$disk"
    sleep 2

    parted "$disk" --script -- \
        mklabel gpt \
        mkpart ESP fat32 1MiB 513MiB \
        set 1 esp on \
        mkpart boot ext4 513MiB 1537MiB \
        mkpart cryptroot 1537MiB 100%

    partprobe "$disk"
    sleep 2
}

partition_path() {
    local partition_number="$1"
    [[ "$disk" =~ [0-9]$ ]] && echo "${disk}p${partition_number}" || echo "${disk}${partition_number}"
}

format_boot_partitions() {
    mkfs.fat -F32 -n ESP "$(partition_path 1)"
    mkfs.ext4 -F -L boot "$(partition_path 2)"
}

setup_luks_and_lvm() {
    local crypt_partition
    crypt_partition="$(partition_path 3)"

    cryptsetup luksFormat -q --type luks2 "$crypt_partition"
    cryptsetup open "$crypt_partition" cryptroot

    pvcreate /dev/mapper/cryptroot
    vgcreate "$volume_group_name" /dev/mapper/cryptroot
    lvcreate -L "${root_size_gb}G" -n root "$volume_group_name"
    lvcreate -L "${swap_size_gb}G" -n swap "$volume_group_name"
    lvcreate -l 100%FREE -n home "$volume_group_name"
}

format_logical_volumes() {
    mkfs.ext4 -F -L root "/dev/mapper/${volume_group_name}-root"
    mkfs.ext4 -F -L home "/dev/mapper/${volume_group_name}-home"
    mkswap -L swap "/dev/mapper/${volume_group_name}-swap"
}

print_summary() {
    echo
    echo "Done. Layout:"
    lsblk -f "$disk"
    echo
    echo "In the installer's 'Something Else' screen, use:"
    echo "  $(partition_path 1)                    -> EFI System Partition"
    echo "  $(partition_path 2)                    -> /boot (do not format)"
    echo "  /dev/mapper/${volume_group_name}-root  -> / (do not format)"
    echo "  /dev/mapper/${volume_group_name}-home  -> /home (do not format)"
    echo "  /dev/mapper/${volume_group_name}-swap  -> swap area"
    echo "  Boot loader device: $disk"
}

confirm_disk_wipe
wipe_and_partition_disk
format_boot_partitions
setup_luks_and_lvm
format_logical_volumes
print_summary
