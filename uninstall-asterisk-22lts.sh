#!/usr/bin/env bash
# ==============================================================================
# Script Name   : uninstall-asterisk-22lts.sh
# Purpose       : Pembersihan total instalasi Asterisk hasil kompilasi
# ==============================================================================

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] Skrip ini wajib dijalankan dengan hak akses root (sudo)." >&2
    exit 1
fi

echo "=========================================================="
echo "    Pembersihan Total Asterisk PBX (Debian 13)            "
echo "=========================================================="
echo "PERINGATAN: Seluruh file konfigurasi (/etc/asterisk), log,"
echo "rekaman, dan kotak voicemail akan dihapus permanen!"
read -rp "Apakah Anda yakin ingin melanjutkan? (y/N): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Operasi dibatalkan oleh pengguna."
    exit 0
fi

# 1. Menghentikan dan menonaktifkan unit service
echo "[1/6] Menghentikan service Asterisk..."
systemctl stop asterisk 2>/dev/null || true
systemctl disable asterisk 2>/dev/null || true
rm -f /etc/systemd/system/asterisk.service
rm -f /lib/systemd/system/asterisk.service
rm -f /etc/init.d/asterisk
systemctl daemon-reload

# 2. Mematikan sisa proses jika masih menggantung
echo "[2/6] Mematikan seluruh proses Asterisk yang masih aktif..."
killall -9 asterisk 2>/dev/null || true
killall -9 safe_asterisk 2>/dev/null || true
sleep 1

# 3. Menjalankan make uninstall jika folder kompilasi masih tersedia
echo "[3/6] Menjalankan uninstaller Makefile..."
AST_SRC_DIR=$(find /usr/src -maxdepth 1 -type d -name "asterisk-22*" | head -n 1)
if [ -n "$AST_SRC_DIR" ] && [ -f "$AST_SRC_DIR/Makefile" ]; then
    echo ">> Menghapus file instalasi melalui $AST_SRC_DIR/Makefile..."
    make -C "$AST_SRC_DIR" uninstall || true
fi

# 4. Menghapus direktori konfigurasi, data, log, dan binary
echo "[4/6] Menghapus direktori sistem dan file biner Asterisk..."
rm -rf /etc/asterisk
rm -rf /var/lib/asterisk
rm -rf /var/spool/asterisk
rm -rf /var/log/asterisk
rm -rf /var/run/asterisk
rm -rf /run/asterisk
rm -rf /usr/lib/asterisk
rm -rf /usr/include/asterisk
rm -rf /usr/src/asterisk-22*

# Menghapus biner di /usr/sbin
rm -f /usr/sbin/asterisk \
      /usr/sbin/safe_asterisk \
      /usr/sbin/astgenkey \
      /usr/sbin/astcanary \
      /usr/sbin/autosupport

ldconfig

# 5. Menghapus User dan Group Sistem
echo "[5/6] Menghapus pengguna dan grup sistem 'asterisk'..."
if id -u asterisk >/dev/null 2>&1; then
    userdel -r asterisk 2>/dev/null || true
fi

if getent group asterisk >/dev/null 2>&1; then
    groupdel asterisk 2>/dev/null || true
fi

# 6. Pembersihan dependensi sisa (Autoremove)
echo "[6/6] Membersihkan paket-paket yang tidak lagi digunakan..."
apt-get autoremove --purge -y

echo "=========================================================="
echo " SELESAI: Asterisk telah dihapus bersih dari sistem!"
echo "=========================================================="
