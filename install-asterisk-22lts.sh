#!/usr/bin/env bash
# ==============================================================================
# Script Name   : install-asterisk-22lts.sh
# Target OS     : Debian 13 (Trixie)
# Asterisk Ver  : 22 LTS (Compiled from Source)
# Fitur         : PJSIP, Video Codec (H.264/VP8), Voicemail-to-Email, MP3 MoH
# ==============================================================================

set -euo pipefail

# 1. Validasi Hak Akses Root
if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] Skrip ini wajib dijalankan dengan hak akses root (sudo)." >&2
    exit 1
fi

echo "=========================================================="
echo "   Memulai Instalasi Asterisk 22 LTS pada Debian 13       "
echo "=========================================================="

# 2. Otomatisasi Debconf & Update Repositori
echo "[1/10] Menyiapkan repositori dan dependensi multimedia..."
export DEBIAN_FRONTEND=noninteractive

# Konfigurasi otomatis Postfix (Local Only) agar instalasi tidak terhenti oleh dialog interaktif
debconf-set-selections <<< "postfix postfix/mailname string pbx.local"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Local only'"

apt-get update -y
apt-get install -y \
    wget curl git build-essential \
    sox lame libmp3lame-dev \
    postfix mailutils \
    sqlite3 libsqlite3-dev uuid-dev libxml2-dev \
    libjansson-dev libssl-dev libedit-dev

# 3. Mengunduh Kode Sumber Asterisk 22 LTS
echo "[2/10] Mengunduh source code Asterisk 22 LTS..."
cd /usr/src
rm -rf asterisk-22*
wget -c https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz
tar -zxvf asterisk-22-current.tar.gz

# Menemukan folder hasil ekstrak secara dinamis
SRC_DIR=$(find /usr/src -maxdepth 1 -type d -name "asterisk-22*" | head -n 1)
cd "$SRC_DIR"

# 4. Memasang Dependensi Sistem Tambahan via Skrip Bawaan
echo "[3/10] Memasang dependensi pelengkap via install_prereq..."
contrib/scripts/install_prereq install

# 5. Mengunduh Modul MP3 untuk Music on Hold
echo "[4/10] Menyiapkan source format MP3..."
contrib/scripts/get_mp3_source.sh

# 6. Konfigurasi Pra-Kompilasi
echo "[5/10] Menjalankan konfigurasi sistem..."
./configure --with-jansson-bundled

# 7. Penyiapan Modul Melalui Menuselect
echo "[6/10] Menyesuaikan modul pilihan (Voicemail, MP3, Extra Sounds)..."
make menuselect.makeopts

# Mengaktifkan modul format MP3 & Voicemail
menuselect/menuselect --enable format_mp3 menuselect.makeopts
menuselect/menuselect --enable app_voicemail menuselect.makeopts

# Mengaktifkan sound prompt berkualitas standar dan tinggi (WAV & G722)
menuselect/menuselect --enable EXTRA-SOUNDS-EN-WAV menuselect.makeopts
menuselect/menuselect --enable EXTRA-SOUNDS-EN-G722 menuselect.makeopts
menuselect/menuselect --enable CORE-SOUNDS-EN-G722 menuselect.makeopts

# 8. Kompilasi dan Instalasi Biner
echo "[7/10] Mengompilasi Asterisk menggunakan $(nproc) core CPU..."
make -j"$(nproc)"
make install

# 9. Memasang Konfigurasi Sampel dan Service Systemd
echo "[8/10] Menginstal sample konfigurasi dan mendaftarkan shared libraries..."
make samples
ldconfig

# 10. Manajemen User & Hak Akses
echo "[9/10] Mengonfigurasi pengguna sistem 'asterisk'..."
if ! id -u asterisk >/dev/null 2>&1; then
    useradd -m -s /usr/sbin/nologin asterisk
fi

# Mengamankan direktori kerja Asterisk
chown -R asterisk:asterisk \
    /etc/asterisk \
    /var/lib/asterisk \
    /var/log/asterisk \
    /var/spool/asterisk \
    /usr/lib/asterisk

mkdir -p /var/spool/asterisk/voicemail
chown -R asterisk:asterisk /var/spool/asterisk/voicemail

# 11. Konfigurasi Systemd Service Modern
echo "[10/10] Mengonfigurasi service systemd Asterisk..."
cat << 'EOF' > /etc/systemd/system/asterisk.service
[Unit]
Description=Asterisk PBX and telephony daemon
After=network.target

[Service]
Type=simple
User=asterisk
Group=asterisk
ExecStart=/usr/sbin/asterisk -f -C /etc/asterisk/asterisk.conf
ExecStop=/usr/sbin/asterisk -rx 'core stop now'
ExecReload=/usr/sbin/asterisk -rx 'core reload'
Restart=always
RestartSec=5
RuntimeDirectory=asterisk
RuntimeDirectoryMode=0750
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now asterisk

echo "=========================================================="
echo " Instalasi Berhasil!"
echo " Status Service: $(systemctl is-active asterisk)"
echo " Masuk CLI     : asterisk -rvvv"
echo "=========================================================="
