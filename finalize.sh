#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 [target_root]"
    echo "Example: $0 /target"
    echo
    echo "Run this from the live session right after the installer finishes,"
    echo "before rebooting, with the cryptroot mapping still open."
    echo "Default target is /target (Ubiquity's mount point)."
    exit 1
}

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && usage

target_root="${1:-/target}"
bind_mounts=(dev proc sys run)

detect_crypt_partition() {
    local device
    device="$(cryptsetup status cryptroot 2>/dev/null | awk '/device:/ {print $2}')"
    if [[ -z "$device" ]]; then
        echo "Error: could not find an open 'cryptroot' mapping." >&2
        echo "Is this the same live session where setup.sh ran?" >&2
        exit 1
    fi
    echo "$device"
}

mount_virtual_filesystems() {
    for dir in "${bind_mounts[@]}"; do
        mount --bind "/$dir" "${target_root}/${dir}"
    done
}

write_crypttab_entry() {
    local crypt_uuid
    crypt_uuid="$(blkid -s UUID -o value "$crypt_partition")"
    echo "cryptroot UUID=${crypt_uuid} none luks,discard" | tee "${target_root}/etc/crypttab"
}

rebuild_boot_configuration() {
    chroot "$target_root" update-initramfs -u -k all
    chroot "$target_root" update-grub
}

unmount_efivars_if_present() {
    local efivars_path="${target_root}/sys/firmware/efi/efivars"
    if mountpoint -q "$efivars_path"; then
        umount "$efivars_path"
    fi
}

unmount_virtual_filesystems() {
    unmount_efivars_if_present
    for ((i = ${#bind_mounts[@]} - 1; i >= 0; i--)); do
        umount "${target_root}/${bind_mounts[i]}"
    done
}

print_next_steps() {
    echo
    echo "Done. The installed system now knows how to unlock $crypt_partition at boot."
    echo "You can safely reboot now."
}

crypt_partition="$(detect_crypt_partition)"

mount_virtual_filesystems
write_crypttab_entry
rebuild_boot_configuration
unmount_virtual_filesystems
print_next_steps