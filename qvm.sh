#!/usr/bin/env bash


#
# create or start an Alpine Linux QEMU VM
#

set -e

cleanup() {
	if [ -d "${SCRIPT_TMPDIR}" ]
	then
		rm -rf "${SCRIPT_TMPDIR}"
	fi
}
trap cleanup EXIT
SCRIPT_TMPDIR="${SCRIPT_TMPDIR:-$(mktemp -d -t "$(basename "${0}").XXXXXXXXXX")}"

SCRIPT_DATA_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/$(basename "${0}")"
mkdir -p "${SCRIPT_DATA_DIR}"


#
# TODO: parse cmd line args etc.
#
VM_NAME=alpine
BASE_IMAGE_URL='https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/cloud/nocloud_alpine-3.19.1-x86_64-bios-cloudinit-r0.qcow2'
VM_STORAGE_BUS=virtio
VM_USER=user
#VM_NAME=debian
#BASE_IMAGE_URL='https://cloud.debian.org/images/cloud/bookworm/20240211-1654/debian-12-genericcloud-amd64-20240211-1654.qcow2'
#VM_STORAGE_BUS=virtio
#VM_USER=user
VMS_DATA_DIR="${SCRIPT_DATA_DIR}/vms"
VM_DATA_DIR="${VMS_DATA_DIR}/${VM_NAME}"
VM_IMAGE_FILE="${VM_DATA_DIR}/image.qcow2"
VM_IMAGE_TYPE=qcow2
VM_IMAGE_SIZE=4G
VM_MEMORY=512M
VM_CPUS=2
#VM_SSH_PORT=29022
VM_SSH_PORT=
# TODO: should be "native" if qemu build supports it - not on Termux...
VM_AIO=threads

SSH_PORTS_MIN=27700
SSH_PORTS_MAX=27799


if [ \! -d "${VM_DATA_DIR}" ]
then
	mkdir -p "${VM_DATA_DIR}"

	if [ \! -f "${VM_IMAGE_FILE}" ]
	then
		BASE_IMAGES_DIR="${SCRIPT_DATA_DIR}/base_images" 
		mkdir -p "${BASE_IMAGES_DIR}/base_images" 
		BASE_IMAGE_NAME="$(basename "${BASE_IMAGE_URL%%\?*}")"
		BASE_IMAGE_TYPE="$(echo "${BASE_IMAGE_NAME##*.}" | awk '{$0=tolower($0);sub(/^img$/,"raw")}/^(dmg|qcow2?|raw|vdi|vhdx|vmdk|vpc)$/{print}')"
		if [ -z "${BASE_IMAGE_TYPE}" ]
		then
			echo "ERROR: base image type ${BASE_IMAGE_NAME##*.} not recognized" 1>&2
			exit 1
		fi
		BASE_IMAGE_FILE="${BASE_IMAGES_DIR}/${BASE_IMAGE_NAME}"
		if [ \! -f "${BASE_IMAGE_FILE}" ]
		then
			# TODO: or curl, or busybox
			wget -O "${BASE_IMAGE_FILE}" "${BASE_IMAGE_URL}"
		fi
		qemu-img create \
			-b "${BASE_IMAGE_FILE}" -F "${BASE_IMAGE_TYPE}" \
			-f "${VM_IMAGE_TYPE}" "${VM_IMAGE_FILE}" "${VM_IMAGE_SIZE}"
	fi

	CLOUD_INIT_DIR="${SCRIPT_TMPDIR}/cloud_init"
	mkdir -p "${CLOUD_INIT_DIR}"
	touch "${CLOUD_INIT_DIR}/meta-data"
	touch "${CLOUD_INIT_DIR}/user-data"

	mkdir -p "${SCRIPT_TMPDIR}/ssh_keys"
	ssh-keygen -t ed25519 -C "sshd@${VM_NAME}" -P '' -q -f "${SCRIPT_TMPDIR}/ssh_keys/server_ed25519"
	ssh-keygen -t ed25519 -C "user@${VM_NAME}" -P '' -q -f "${VM_DATA_DIR}/ssh_user_ed25519"

	# TODO: forward unix socket and not a port once this feature drops: https://gitlab.com/qemu-project/qemu/-/issues/347
	if [ -z "${VM_SSH_PORT}" ]
	then
		if [ -n "$(ls "${VMS_DATA_DIR}"/*/ssh_config 2>/dev/null || true)" ]
		then
			VM_SSH_PORT=$SSH_PORTS_MIN
		else
			for VM_SSH_PORT in $(seq $SSH_PORTS_MIN $SSH_PORTS_MAX)
			do
				if grep -q "Port ${VM_SSH_PORT}" "${VMS_DATA_DIR}"/*/ssh_config
				then
					continue
				else
					break
				fi
			done
			if [ -z "${VM_SSH_PORT}" ]
			then
				echo "ERROR: cannot find SSH port in range ${SSH_PORTS_MIN} to ${SSH_PORTS_MAX}" 1>&2
				exit 1
			fi
		fi
	fi

	if [ \! -d ~/.ssh ]
	then
		mkdir -p ~/.ssh
		chmod 700 ~/.ssh
	fi
	if [ -f ~/.ssh/config ]
	then
		sed -i.bak.$(date +%Y%m%d%H%M%S) "/^Host ${VM_NAME}\.vm$/,/^$/d" ~/.ssh/config
	fi

	cat <<__SSH_CONFIG__ >> ~/.ssh/config
Host ${VM_NAME}.vm
	HostName 127.0.0.1
	Port ${VM_SSH_PORT}
	User ${VM_USER}
	#PreferredAuthentications publickey
	#PasswordAuthentication no
	KbdInteractiveAuthentication no
	IdentityFile ${VM_DATA_DIR}/ssh_user_ed25519
	IdentitiesOnly yes
	UserKnownHostsFile ${VM_DATA_DIR}/ssh_known_hosts
	UpdateHostKeys no

__SSH_CONFIG__
	echo "[127.0.0.1]:${VM_SSH_PORT} $(cut -d ' ' -f 1,2 "${SCRIPT_TMPDIR}/ssh_keys/server_ed25519.pub")" > "${VM_DATA_DIR}"/ssh_known_hosts

	CLOUD_INIT_DIR="${SCRIPT_TMPDIR}/cloud_init"
	mkdir -p "${CLOUD_INIT_DIR}"
	touch "${CLOUD_INIT_DIR}/vendor-data"
	( echo "instance-id: ${VM_NAME}" ; echo ) > "${CLOUD_INIT_DIR}/meta-data"
	cat <<__USER_DATA__ > "${CLOUD_INIT_DIR}/user-data"
#cloud-config
hostname: ${VM_NAME}
ssh_keys:
  ed25519_private: |
$(sed -e 's/^/    /' < "${SCRIPT_TMPDIR}/ssh_keys/server_ed25519")
  ed25519_public: $(cat "${SCRIPT_TMPDIR}/ssh_keys/server_ed25519.pub")
#ssh_pwauth: false
ssh_deletekeys: true
users:
- name: ${VM_USER}
  sudo: ALL=(ALL) NOPASSWD:ALL
  plain_text_passwd: ${VM_USER}
  ssh_authorized_keys:
    - $(cat "${VM_DATA_DIR}/ssh_user_ed25519.pub")

__USER_DATA__
	rm "${SCRIPT_TMPDIR}/ssh_keys/server_ed25519"

	CLOUD_INIT_ISO="${SCRIPT_TMPDIR}/cloud_init.iso"
	# TODO: or genisoimage, or mkisofs, or genisofs
	xorriso -as genisoimage \
		-o "${CLOUD_INIT_ISO}" \
		-V CIDATA -J -r \
		"${CLOUD_INIT_DIR}"

else
	if [ -z "${VM_SSH_PORT}" ]
	then
		VM_SSH_PORT="$(awk '/Port [0-9]+/{ print $2 ; exit(0) }' < "${VM_DATA_DIR}/ssh_config")"
		if [ -z "${VM_SSH_PORT}" ]
		then
			echo "ERROR: cannot find SSH port in range ${SSH_PORTS_MIN} to ${SSH_PORTS_MAX}" 1>&2
			exit 1
		fi
	fi
	CLOUD_INIT_ISO=/dev/null
fi

qemu-system-x86_64 -M pc \
	-name "${VM_NAME}" \
	-m "${VM_MEMORY}" -smp "${VM_CPUS}" \
	-no-user-config -no-reboot \
	-device virtio-rng-pci,rng=rng0 -object rng-random,filename=/dev/urandom,id=rng0 \
	-netdev user,id=en0,hostfwd=tcp:127.0.0.1:"${VM_SSH_PORT}"-:22 \
	-device virtio-net-pci,netdev=en0 \
	-nographic -vga none -serial stdio \
	-boot order=c \
	-drive file="${VM_IMAGE_FILE}",format=${VM_IMAGE_TYPE},media=disk,cache=none,if=${VM_STORAGE_BUS},aio=${VM_AIO},discard=unmap,id=hd0 \
	-drive file="${CLOUD_INIT_ISO}",format=raw,media=cdrom,read-only=on,cache=none,if=${VM_STORAGE_BUS},id=cdrom0 \
	-nodefaults



