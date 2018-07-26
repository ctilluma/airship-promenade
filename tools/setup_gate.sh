#!/usr/bin/env bash

set -e

SCRIPT_DIR=$(realpath "$(dirname "${0}")")
WORKSPACE=$(realpath "${SCRIPT_DIR}/..")
GATE_UTILS=${WORKSPACE}/tools/g2/lib/all.sh

GATE_COLOR=${GATE_COLOR:-1}

export GATE_COLOR
export GATE_UTILS
export WORKSPACE

source "${GATE_UTILS}"

REQUIRE_RELOG=0

log_stage_header "Installing Packages"
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
sudo apt-get install -q -y --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    curl \
    fio \
    genisoimage \
    jq \
    libstring-shellquote-perl \
    libvirt-bin \
    qemu-kvm \
    qemu-utils \
    software-properties-common \
    virtinst

# Install the docker gpg key & Add the repository
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get update -qq

# Remove old versions of docker, if installed
sudo apt-get remove -q -y docker docker-engine docker.io
# Install docker
sudo apt-get install -q -y --no-install-recommends \
    docker-ce

log_stage_header "Joining User Groups"
for grp in docker libvirtd libvirt; do
    if ! groups | grep $grp > /dev/null; then
        sudo adduser "$(id -un)" $grp || echo "Group $grp not found, not added to user"
        REQUIRE_RELOG=1
    fi
done

log_stage_header "Setting Kernel Parameters"
if [ "xY" != "x$(cat /sys/module/kvm_intel/parameters/nested)" ]; then
    log_note Enabling nested virtualization.
    sudo modprobe -r kvm_intel
    sudo modprobe kvm_intel nested=1
    echo "options kvm-intel nested=1" | sudo tee /etc/modprobe.d/kvm-intel.conf
fi

if ! sudo virt-host-validate qemu &> /dev/null; then
    log_note Host did not validate virtualization check:
    sudo virt-host-validate qemu || true
fi

if [[ ! -d ${VIRSH_POOL_PATH} ]]; then
    sudo mkdir -p "${VIRSH_POOL_PATH}"
fi

if [[ ${REQUIRE_RELOG} -eq 1 ]]; then
    echo
    log_note "You must ${C_HEADER}log out${C_CLEAR} and back in before the gate is ready to run."
fi

log_huge_success
