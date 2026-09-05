# Linux Mint custom setup

This repo has some scripts that I use to partially automate my Linux Mint 22.3 setup:

- Create partitions so /home lives on its own partition,
- all non-boot partitions use LVM for easier management,
- all non-boot partitions are encrypted with LUKS.

## Instructions

On the new machine:

1. Boot Linux Mint live CD/USB.
2. Install openssh:

   ```sh
   sudo apt update
   sudo apt install -y openssh-server
   ```

3. Give user mint a password: ```sudo passwd mint```
4. Find out the IP-address: ```ip a```

On another existing machine:

1. Clone and enter this repo.
2. Copy the scripts to the new machine: `scp setup.sh finalize.sh mint@<ip-address>:~`
3. SSH into the new machine: `ssh mint@<ip-address>`

On the new machine (over SSH):

1. Partition, encrypt, and format the disk: `sudo ./setup.sh -y /dev/sda [root_size_gb] [swap_size_gb]`
2. Note the partition layout printed at the end — you'll need it for the installer.
3. Launch the Ubiquity installer from the live session (e.g. `ubiquity`) and, on the "Something Else" screen, assign partitions per the printed layout (replace /dev/sda with correct drive):
   - /dev/sda2 -> ext4, /boot
   - vgmint-root -> ext4, /
   - vgmint-home -> ext4, /home
   - Device for boot loader installation -> /dev/sda
   Do not format the pre-created partitions.
4. Let the installer run through to completion, but do **not** reboot when prompted.
5. Before rebooting, run: `sudo ./finalize.sh [target_root]` (e.g. `sudo ./finalize.sh /target`) to configure the LUKS-encrypted root for boot. It auto-detects the crypt partition from the still-open `cryptroot` mapping.
6. Reboot into the new system.
