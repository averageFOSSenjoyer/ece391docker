#!/bin/bash
#
# setup_linux: installs the ECE 391 home environment on Linux
#
# This script only officially supports Ubuntu 16.04, Debian 9,
# and Arch Linux; however, you should be able to run it on
# other distributions without much problem. If your package
# manager is not supported, you may have to manually install
# any required dependencies.
#
# Note that this script should NOT be run as root/sudo.
set -e

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
share_dir="${script_dir}/ece391_share"
work_dir="${share_dir}/work"
qemu_dir="${script_dir}/qemu"
image_dir="${script_dir}/image"
vm_dir="${work_dir}/vm"
kernel_path="${work_dir}/source/linux-2.6.22.5/bzImage"

install_qemu() {
    echo "[*] Installing QEMU"

    echo "[*] Downloading QEMU"
    curl -L "https://download.qemu.org/qemu-1.5.0.tar.bz2" -o "/tmp/qemu-1.5.0.tar.bz2"
    tar xfj "/tmp/qemu-1.5.0.tar.bz2" -C "/tmp"

    # Work around ancient QEMU bug
    # https://bugzilla.redhat.com/show_bug.cgi?id=969955
    echo "[*] Patching QEMU -- removing libfdt_env.h"
    rm "/tmp/qemu-1.5.0/include/libfdt_env.h"

    # Workaround for newer Perl versions
    echo "[*] Patching QEMU -- modifying texi2pod.pl"
    sed -i 's/@strong{(.*)}/@strong\\{$1\\}/g' "/tmp/qemu-1.5.0/scripts/texi2pod.pl"
    (
        # Need to cd into the directory or else make fails
        # Run this in a subshell so we return to our old directory after
        cd "/tmp/qemu-1.5.0"
        echo "[*] Compiling QEMU (this may take a few minutes)"

        # Another weird workaround
        export ARFLAGS="rv"
        export TERM=xterm

        # Only compile for i386 arch to speed up compile time
        # Output directory will be in ${qemu_dir}
        # Make sure we're using python2 for systems like Arch where python points to python3
        ./configure --target-list=i386-softmmu --prefix="${qemu_dir}" --python=python2 --enable-curses
        make -j 8

        echo "[*] Installing QEMU"
        make install
    )
}

create_qcow() {
    echo "[*] Creating qcow files"
    mkdir -p "${vm_dir}"

    # rebase devel
    "${qemu_dir}/bin/qemu-img" rebase -b "${image_dir}/ece391.qcow" -f qcow2 "${vm_dir}/devel.qcow" >/dev/null

    if [ ! -f "${vm_dir}/test.qcow" ]; then
        echo "[*] Creating test.qcow"
        "${qemu_dir}/bin/qemu-img" create -b "${image_dir}/ece391.qcow" -f qcow2 "${vm_dir}/test.qcow" >/dev/null
    fi
}

create_shortcuts() {
    echo "[*] Creating shortcuts"

    tee "${script_dir}/devel" >/dev/null <<EOF
#!/bin/bash
params=()
for i in \$@;
do
    params+=("\$i")
done
"${qemu_dir}/bin/qemu-system-i386" -hda "${vm_dir}/devel.qcow" -m 512 -name devel -k en-us -redir tcp:2022::22 \${params[@]}
EOF

    tee "${script_dir}/test_debug" >/dev/null <<EOF
#!/bin/bash
params=()
for i in \$@;
do
    params+=("\$i")
done
"${qemu_dir}/bin/qemu-system-i386" -hda "${vm_dir}/test.qcow" -m 512 -name test -gdb tcp:127.0.0.1:1234 -redir tcp:2023::22 -kernel "${kernel_path}" -S -k en-us \${params[@]}
EOF

    tee "${script_dir}/test_nodebug" >/dev/null <<EOF
#!/bin/bash
params=()
for i in \$@;
do
    params+=("\$i")
done
"${qemu_dir}/bin/qemu-system-i386" -hda "${vm_dir}/test.qcow" -m 512 -name test -gdb tcp:127.0.0.1:1234 -redir tcp:2024::22 -kernel "${kernel_path}" -k en-us \${params[@]}
EOF

    echo "[*] Making desktop shortcuts executable"
    chmod a+x "${script_dir}"/devel "${script_dir}"/test_debug "${script_dir}"/test_nodebug

}

config_samba() {
    echo "[*] Setting up Samba"

    # Username must be same as Linux username for some reason
    echo "[*] Creating Samba user"
    smb_user="user"

    (echo "ece391"; echo "ece391") | sudo smbpasswd -a ${smb_user}

    echo "[*] Adding new Samba config"
    sudo tee -a "/etc/samba/smb.conf" >/dev/null <<EOF
### BEGIN ECE391 CONFIG ###
[ece391_share]
  path = "${share_dir}"
  valid users = ${smb_user}
  create mask = 0755
  read only = no

[global]
  ntlm auth = yes
  min protocol = NT1
### END ECE391 CONFIG ###
EOF
}

config_ssh() { 
    mkdir ~/.ssh 
    touch ~/.ssh/config
    sudo tee -a ~/.ssh/config >/dev/null <<EOF
Host 391devel
	Ciphers 3des-cbc
	KexAlgorithms +diffie-hellman-group1-sha1
	HostKeyAlgorithms=+ssh-dss
	HostName localhost
	Port 2022
	User user

Host 391testdbug
	Ciphers 3des-cbc
	KexAlgorithms +diffie-hellman-group1-sha1
	HostKeyAlgorithms=+ssh-dss
	HostName localhost
	Port 2023
	User user

Host 391testndbug
	Ciphers 3des-cbc
	KexAlgorithms +diffie-hellman-group1-sha1
	HostKeyAlgorithms=+ssh-dss
	HostName localhost
	Port 2024
	User user
EOF

sudo chmod 700 ~/.ssh
sudo chmod 600 ~/.ssh/*
}

echo "[*] ECE 391 home setup script for Linux"
install_qemu
create_qcow
create_shortcuts
config_samba
config_ssh
echo "[+] Done!"