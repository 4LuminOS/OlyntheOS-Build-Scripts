#!/bin/bash
set -e

    echo "======= LUMINOS MASTER BUILD SCRIPT (v8.2) ======="

    if [ "$(id -u)" -ne 0 ]; then echo "ERROR: This script must be run as root."; exit 1; fi

# --- 1. Setup ---
BASE_DIR=$(dirname "$(readlink -f "$0")")
WORK_DIR="${BASE_DIR}/work"
CHROOT_DIR="${WORK_DIR}/chroot"
ISO_DIR="${WORK_DIR}/iso"
AI_BUILD_DIR="${WORK_DIR}/ai_build"
ISO_NAME="LuminOS-0.2.1-amd64.iso"

# Cleanup
for mount_point in "${CHROOT_DIR}/sys" "${CHROOT_DIR}/proc" "${CHROOT_DIR}/dev/pts" "${CHROOT_DIR}/dev"; do
    mountpoint -q "$mount_point" 2>/dev/null && sudo umount "$mount_point" || true
done
pkill -f "ollama serve" || true
sudo rm -rf "${WORK_DIR}"
sudo rm -f "${BASE_DIR}/${ISO_NAME}"

mkdir -p "${CHROOT_DIR}" "${ISO_DIR}/live" "${ISO_DIR}/boot/grub" "${AI_BUILD_DIR}"

# --- 2. Install Dependencies ---
echo "--> Installing dependencies..."
apt-get update
apt-get install -y debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools curl rsync

    # --- 3. PREPARE AI ---
    echo "--> Preparing AI..."
    TARGET_MODEL_DIR="${AI_BUILD_DIR}/models"
    mkdir -p "${TARGET_MODEL_DIR}"

    # 3a. Find or Download
    REAL_USER="${SUDO_USER:-$USER}"
    USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
    POSSIBLE_LOCATIONS=("${USER_HOME}/.ollama/models" "/root/.ollama/models" "/usr/share/ollama/.ollama/models")
    MODEL_FOUND=false

    for LOC in "${POSSIBLE_LOCATIONS[@]}"; do
        if [ -d "$LOC" ]; then
            SIZE_CHECK=$(du -s "$LOC" | cut -f1)
            if [ "$SIZE_CHECK" -gt 1000000 ]; then
                echo "SUCCESS: Found models at $LOC! Copying..."
                cp -r "${LOC}/." "${TARGET_MODEL_DIR}/"
                MODEL_FOUND=true
                break
            fi
        fi
    done

    if [ "$MODEL_FOUND" = false ]; then
        echo "--> Downloading models..."
        curl -fL "https://github.com/ollama/ollama/releases/download/v0.1.32/ollama-linux-amd64" -o "${AI_BUILD_DIR}/ollama"
        
        echo "--> Verifying Ollama binary checksum..."
        SHA256FILE=$(mktemp)
        if curl -fsSL "https://github.com/ollama/ollama/releases/download/v0.1.32/sha256sum.txt" -o "$SHA256FILE" 2>/dev/null; then
            if grep -q "[[:space:]]ollama-linux-amd64$" "$SHA256FILE"; then
                EXPECTED_HASH=$(grep "[[:space:]]ollama-linux-amd64$" "$SHA256FILE" | awk '{print $1}')
                ACTUAL_HASH=$(sha256sum "${AI_BUILD_DIR}/ollama" | awk '{print $1}')
                if [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
                    echo "ERROR: Ollama binary checksum mismatch! Expected: $EXPECTED_HASH  Got: $ACTUAL_HASH"
                    rm -f "${AI_BUILD_DIR}/ollama" "$SHA256FILE"
                    exit 1
                fi
                echo "--> Ollama checksum verified"
            else
                echo "WARNING: ollama-linux-amd64 entry not found in sha256sum.txt — skipping verification"
            fi
        else
            echo "WARNING: Could not download sha256sum.txt — skipping checksum verification"
        fi
        rm -f "$SHA256FILE"
        
        chmod +x "${AI_BUILD_DIR}/ollama"
        export HOME="${AI_BUILD_DIR}"
        "${AI_BUILD_DIR}/ollama" serve > "${AI_BUILD_DIR}/server.log" 2>&1 &
        OLLAMA_PID=$!
        sleep 10
        "${AI_BUILD_DIR}/ollama" pull llama3
        kill ${OLLAMA_PID} || true
        if [ -d "${AI_BUILD_DIR}/.ollama/models" ]; then
            cp -r "${AI_BUILD_DIR}/.ollama/models/." "${TARGET_MODEL_DIR}/"
        fi
    fi


# 3b. CUT LARGE FILES
echo "--> Cutting large AI files into 900MB chunks..."
find "${TARGET_MODEL_DIR}" -type f -size +900M -print0 | while IFS= read -r -d '' file; do
    echo "Splitting $file ..."
    split -b 900M "$file" "$file.part"
    touch "$file.is_split"
    rm "$file"
done

# --- 4. Bootstrap System ---
echo "--> Bootstrapping Debian..."
debootstrap --arch=amd64 --components=main,contrib,non-free-firmware --include=linux-image-amd64,live-boot,systemd-sysv trixie "${CHROOT_DIR}" http://ftp.debian.org/debian/

# --- 5. Customize ---
mkdir -p "${CHROOT_DIR}/etc/apt/apt.conf.d"
echo 'Acquire::IndexTargets::deb::Contents-deb "false";' > "${CHROOT_DIR}/etc/apt/apt.conf.d/99-no-contents"

# Commented, because it fails and not actually needed inside docker
# echo "--> Mounting..."
# mount --bind /dev "${CHROOT_DIR}/dev"
# mount --bind /dev/pts "${CHROOT_DIR}/dev/pts"
# mount -t proc /proc "${CHROOT_DIR}/proc"
# mount -t sysfs /sys "${CHROOT_DIR}/sys"

echo "--> Copying Assets & Binary..."
mkdir -p "${CHROOT_DIR}/usr/share/wallpapers/luminos"
cp "${BASE_DIR}/assets/"* "${CHROOT_DIR}/usr/share/wallpapers/luminos/"
if [ ! -f "${AI_BUILD_DIR}/ollama" ]; then
    curl -fL "https://github.com/ollama/ollama/releases/download/v0.1.32/ollama-linux-amd64" -o "${AI_BUILD_DIR}/ollama"
    
    echo "--> Verifying Ollama binary checksum..."
    SHA256FILE=$(mktemp)
    if curl -fsSL "https://github.com/ollama/ollama/releases/download/v0.1.32/sha256sum.txt" -o "$SHA256FILE" 2>/dev/null; then
        if grep -q "[[:space:]]ollama-linux-amd64$" "$SHA256FILE"; then
            EXPECTED_HASH=$(grep "[[:space:]]ollama-linux-amd64$" "$SHA256FILE" | awk '{print $1}')
            ACTUAL_HASH=$(sha256sum "${AI_BUILD_DIR}/ollama" | awk '{print $1}')
            if [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
                echo "ERROR: Ollama binary checksum mismatch! Expected: $EXPECTED_HASH  Got: $ACTUAL_HASH"
                rm -f "${AI_BUILD_DIR}/ollama" "$SHA256FILE"
                exit 1
            fi
            echo "--> Ollama checksum verified"
        else
            echo "WARNING: ollama-linux-amd64 entry not found in sha256sum.txt — skipping verification"
        fi
    else
        echo "WARNING: Could not download sha256sum.txt — skipping checksum verification"
    fi
    rm -f "$SHA256FILE"
    chmod +x "${AI_BUILD_DIR}/ollama"
fi
cp "${AI_BUILD_DIR}/ollama" "${CHROOT_DIR}/usr/local/bin/"

echo "--> Running Scripts..."
cp "${BASE_DIR}/phases/02-configure-system.sh" "${CHROOT_DIR}/tmp/"
cp "${BASE_DIR}/phases/03-install-desktop.sh" "${CHROOT_DIR}/tmp/"
cp "${BASE_DIR}/phases/04-customize-desktop.sh" "${CHROOT_DIR}/tmp/"
cp "${BASE_DIR}/phases/05-install-ai.sh" "${CHROOT_DIR}/tmp/"
cp "${BASE_DIR}/phases/07-install-plymouth-theme.sh" "${CHROOT_DIR}/tmp/"
cp "${BASE_DIR}/phases/08-install-software.sh" "${CHROOT_DIR}/tmp/"
cp "${BASE_DIR}/phases/06-final-cleanup.sh" "${CHROOT_DIR}/tmp/"
chmod +x "${CHROOT_DIR}/tmp/"*.sh

chroot "${CHROOT_DIR}" /tmp/02-configure-system.sh
chroot "${CHROOT_DIR}" /tmp/03-install-desktop.sh
chroot "${CHROOT_DIR}" /tmp/04-customize-desktop.sh
chroot "${CHROOT_DIR}" /tmp/05-install-ai.sh
chroot "${CHROOT_DIR}" /tmp/07-install-plymouth-theme.sh
chroot "${CHROOT_DIR}" /tmp/08-install-software.sh
chroot "${CHROOT_DIR}" /tmp/06-final-cleanup.sh

# Commented, because it fails and not actually needed inside docker
# echo "--> Unmounting..."
# umount "${CHROOT_DIR}/sys"
# umount "${CHROOT_DIR}/proc"
# umount "${CHROOT_DIR}/dev/pts"
# umount "${CHROOT_DIR}/dev"

# --- 6. Build ISO (Multi-Layer Distribution) ---
echo "--> Creating Layers..."

# Layer 1: OS (Exclude .ollama to avoid duplicating files)
echo "   Layer 1 (OS)..."
mksquashfs "${CHROOT_DIR}" "${ISO_DIR}/live/01-filesystem.squashfs" -e boot -e usr/share/ollama/.ollama -comp zstd -processors "$(nproc)"

# Prepare distribution directories
L2="${WORK_DIR}/layer2"
L3="${WORK_DIR}/layer3"
L4="${WORK_DIR}/layer4"

# FIX: added /models/ in the path !
mkdir -p "$L2/usr/share/ollama/.ollama/models"
mkdir -p "$L3/usr/share/ollama/.ollama/models"
mkdir -p "$L4/usr/share/ollama/.ollama/models"

# Copy manifests to Layer 2
mkdir -p "$L2/usr/share/ollama/.ollama/models/manifests"
cp -r "${TARGET_MODEL_DIR}/manifests/." "$L2/usr/share/ollama/.ollama/models/manifests/" 2>/dev/null || true

# Distribute blobs (chunks) across 3 layers
echo "   Distributing chunks..."
# FIX: added /models/ in the path !
mkdir -p "$L2/usr/share/ollama/.ollama/models/blobs"
mkdir -p "$L3/usr/share/ollama/.ollama/models/blobs"
mkdir -p "$L4/usr/share/ollama/.ollama/models/blobs"

COUNT=0
while IFS= read -r -d '' file; do
    MOD=$((COUNT % 3))
    if [ $MOD -eq 0 ]; then
        cp "$file" "$L2/usr/share/ollama/.ollama/models/blobs/"
    elif [ $MOD -eq 1 ]; then
        cp "$file" "$L3/usr/share/ollama/.ollama/models/blobs/"
    else
        cp "$file" "$L4/usr/share/ollama/.ollama/models/blobs/"
    fi
    COUNT=$((COUNT + 1))
done < <(find "${TARGET_MODEL_DIR}/blobs" -type f -print0)

echo "   Layer 2..."
mksquashfs "$L2" "${ISO_DIR}/live/02-ai-part1.squashfs" -comp zstd -processors "$(nproc)"
echo "   Layer 3..."
mksquashfs "$L3" "${ISO_DIR}/live/03-ai-part2.squashfs" -comp zstd -processors "$(nproc)"
echo "   Layer 4..."
mksquashfs "$L4" "${ISO_DIR}/live/04-ai-part3.squashfs" -comp zstd -processors "$(nproc)"

# --- 7. Bootloader & Final ISO ---
echo "--> Bootloader..."
cp "${CHROOT_DIR}/boot"/vmlinuz* "${ISO_DIR}/live/vmlinuz"
cp "${CHROOT_DIR}/boot"/initrd.img* "${ISO_DIR}/live/initrd.img"

cat > "${ISO_DIR}/boot/grub/grub.cfg" << EOF
set default="0"
set timeout=5
menuentry "LuminOS v0.2.1 Live" {
    linux /live/vmlinuz boot=live quiet splash
    initrd /live/initrd.img
}
EOF

echo "--> Generating ISO..."
grub-mkrescue -o "${BASE_DIR}/${ISO_NAME}" "${ISO_DIR}"

echo "--> Cleanup..."
sudo rm -rf "${WORK_DIR}"

ISO_SIZE=$(du -h "${BASE_DIR}/${ISO_NAME}" | cut -f1)
echo "SUCCESS: ISO Built! Size: $ISO_SIZE"
exit 0
