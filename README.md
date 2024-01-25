# Arch Linux Installation Script

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/dominikoetiker/ArchLinuxInstaller/blob/main/LICENSE)
[![GitHub Issues](https://img.shields.io/github/issues/dominikoetiker/ArchLinuxInstaller)](https://github.com/dominikoetiker/ArchLinuxInstaller/issues)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/dominikoetiker/ArchLinuxInstaller/tree/v1.0.0)

This Bash script automates the installation of Arch Linux by performing various steps involved in the setup process. It covers keymap loading, boot mode verification, internet connection check, system clock update, disk partitioning, filesystem formatting, mounting, mirror selection, essential package installation, fstab generation, timezone and localization setup, network configuration, initramfs creation, root password setting, and bootloader installation.

But the most important thing: It creates a full-disk encryption installation.

## Table of Contents

- [Arch Linux Installation Script](#arch-linux-installation-script)
  - [Table of Contents](#table-of-contents)
  - [Why Use This Script?](#why-use-this-script)
  - [Warning](#warning)
  - [Usage](#usage)
    - [Prerequisites](#prerequisites)
    - [Cloning the Repository](#cloning-the-repository)
    - [Customize the configuration file](#customize-the-configuration-file)
      - [CONFIGNAME](#configname)
      - [\[OPTIONAL_VARIABLES\]](#optional_variables)
      - [\[VARIABLES\]](#variables)
      - [\[LOCALIZATIONS\]](#localizations)
      - [\[PARTITIONS\]](#partitions)
      - [\[LVM\]](#lvm)
      - [\[ESSENTIALPACKAGES\]](#essentialpackages)
      - [\[BOOTLOADERPACKAGES\]](#bootloaderpackages)
      - [\[MICROCODEPACKAGES\]](#microcodepackages)
    - [Customization Steps](#customization-steps)
    - [Run the installation](#run-the-installation)
  - [Contributing](#contributing)
  - [License](#license)

## Why Use This Script?

- **Full Disk Encryption**: This script provides a Full Disk Encrypted Installation of Arch Linux.
- **Automation**: This script streamlines the Arch Linux installation process, saving time and reducing manual errors.
- **Consistency**: Ensures a consistent installation across multiple systems.
- **Customization**: Easily customizable for specific configurations through the configuration file.

## Warning

**Disk Encryption and Data Deletion**: This script will encrypt the target disk, and all existing data on the disk will be permanently deleted during the installation process. Ensure you have backed up any important data before running the script.

Be careful and make sure you know what you are doing. This script and the configuration file do not replace reading and understanding the official documentation.

## Usage

### Prerequisites

Before running the script, make sure you have:

- Backed up important data on the target disk, as the script will partition and format it.
- An up-to-date installation medium created from the official Arch Linux website.
- Booted from the installation medium.
- Verified the boot mode (UEFI).
- Established a working internet connection.
- Customized the configuration file.

### Cloning the Repository

To clone the repository:

```bash
git clone https://github.com/dominikoetiker/ArchLinuxInstaller
cd ArchLinuxInstaller
```

### Customize the configuration file

Customize the template provided in this repository `config-template` to suit your system and your needs.

#### CONFIGNAME

- This label indicates the configuration name. Modify it for clarity if needed.

#### [OPTIONAL_VARIABLES]

- Optional settings for customization:
  - `KEYMAP`: Set keyboard layout (default: us).
  - `TIME_ZONE`: Set time zone (default: America/New_York).

#### [VARIABLES]

- Essential system variables:
  - `CRYPT_MAPPER_NAME`: Name for encryption mapper.
  - `LVM_VG_NAME`: LVM volume group name.
  - `MIRROR_COUNTRIES`: Package mirror countries (default: Germany).
  - `HOST_NAME`: System hostname.

#### [LOCALIZATIONS]

- Language and locale settings:
  - `LANG`: Language setting (default: en_US.UTF-8).
  - `LC_COLLATE`, `LC_CTYPE`, `LC_MONETARY`, `LC_NUMERIC`, `LC_TIME`, `LC_PAPER`: Locale settings.

#### [PARTITIONS]

- Partition configuration:
  - `NAME`: Partition name.
  - `STARTSIZE` and `ENDSIZE`: Partition size.
  - `FILESYS`: File system type.
  - `MOUNTPOINT`: Mount point.
  - `PARTNR`: Partition number.
  - `FLAG`: Partition flags.

#### [LVM]

- Logical Volume Management settings:
  - `NAME`: Logical volume name.
  - `SIZE`: Size of the logical volume.
  - `FILESYS`: File system type.
  - `MOUNTPOINT`: Mount point.

#### [ESSENTIALPACKAGES]

- Essential system packages:
  - `BASE`, `KERNEL`, `FIRMWARE`: Core packages.
  - `FS_MANAGEMENT_TOOLS`, `LVM_UTILITIES`, `NETWORKING_SOFTWARE`: Utilities.
  - `EDITOR`, `MANUTIL`, `MANPAGES`, `GNUDOC`: Documentation tools.

#### [BOOTLOADERPACKAGES]

- Bootloader-related packages:
  - `BOOTLOADER`, `EFIBOOTMGRTOOL`: GRUB and EFIBOOTMGRTOOL.

#### [MICROCODEPACKAGES]

- CPU microcode update packages:
  - `MICROCODEUPTDATES`: Microcode updates (default: amd-ucode).

### Customization Steps

1. Replace values such as `VALUE` with your preferred settings.
2. Adjust partition sizes, mount points, and file system types based on your requirements.
3. Add or remove packages in the `[ESSENTIALPACKAGES]`, `[BOOTLOADERPACKAGES]`, and `[MICROCODEPACKAGES]` sections.

**Be careful when customizing the file. Make sure you know what you are doing. This script and the configuration file do not replace reading and understanding the official documentation.**

### Run the installation

```bash
./install_arch_linux.sh [-hvlr] [-L logfile] [-c configfile] [-d device]
```

- `-h` prints the help menu to stdout
- `-v` prints detailed output to stdout
- `-l` prints detailed output to logfile (standard logfile)
- `-L <logfile>` prints detailed output to logfile `<filename>`
- `-r` if -l or -L is selected and the logfile allready exists,
  the existing logfile will be removed (standard is to append
  to existing logfile)
- `-c <configfile>` preselect a configfile (standard is a select menu)
- `-d <device>` preselect a target disk `<device>`

## Contributing

I welcome contributions! If you find any issues, have suggestions, or want to contribute new features, please follow these steps:

1. Check if the issue exists in the [issue tracker](https://github.com/dominikoetiker/ArchLinuxInstaller/issues).
2. If it doesn't exist, create a new issue with a detailed description.
3. Fork the repository and create a new branch for your contribution.
4. Submit a pull request with your changes.

Please read my [Contribution Guidelines](CONTRIBUTE.md) for more details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
