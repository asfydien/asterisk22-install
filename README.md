# 📞 Asterisk 22 LTS Auto-Installer & Konfigurasi Lab (Debian 13 Trixie)

Repositori ini memuat skrip otomatisasi instalasi, konfigurasi dasar Voice over IP (VoIP), serta materi praktikum komunikasi data untuk jurusan **Teknik Jaringan Komputer dan Telekomunikasi (TJKT)**.

Paket ini mengompilasi **Asterisk 22 LTS** langsung dari sumber resminya untuk berjalan optimal di **Debian 13 (Trixie)**, lengkap dengan dukungan protokol modern **chan_pjsip**, video call (H.264/VP8), pemutar musik tunggu (MP3 MoH), serta layanan Voicemail-to-Email.

---

## 🚀 Fitur Utama

- **PJSIP Protocol Native:** Menggantikan modul lawas `chan_sip` yang sudah usang (*deprecated*).
- **Video Call Ready:** Dukungan codec `H.264` dan `VP8` untuk panggilan tatap muka antar-softphone.
- **Voicemail Terintegrasi:** Fasilitas perekaman pesan suara saat ekstensi sibuk atau tidak merespons, dapat diakses via nomor cepat `*97`.
- **Music On Hold (MoH) MP3:** Kompilasi otomatis modul `format_mp3` untuk audio panggilan tunggu.
- **Systemd Service Isolated:** Dijalankan di bawah user non-root `asterisk` untuk keamanan sistem operasi.

---

## 📋 Prasyarat Sistem

| Komponen | Spesifikasi Minimum |
| :--- | :--- |
| **Sistem Operasi** | Debian GNU/Linux 13 (Trixie) 64-bit |
| **Hak Akses** | `root` atau pengguna dengan hak `sudo` |
| **Prosesor (vCPU)** | 1 Core (Direkomendasikan 2 Core untuk kompilasi lebih cepat) |
| **RAM** | 1 GB (Direkomendasikan 2 GB) |
| **Penyimpanan Bebas** | Minimal 5 GB |
| **Koneksi Internet** | Diperlukan untuk mengunduh kode sumber dan dependensi |

---

## 🛠️ Panduan Instalasi Cepat

Jalankan perintah berikut di terminal server Debian 13:

```bash
# 1. Klon repositori ini
git clone https://github.com/asfydien/asterisk22-debian13.git
cd asterisk22-debian13

# 2. Berikan izin eksekusi pada skrip
chmod +x install-asterisk-22lts.sh uninstall-asterisk-22lts.sh

# 3. Jalankan instalasi sebagai root
sudo ./install-asterisk-22lts.sh
```

Proses kompilasi memakan waktu sekitar **5 - 15 menit** tergantung spesifikasi prosesor server.

---

## ⚙️ Modul Praktikum: Konfigurasi Server PBX

Setelah proses instalasi selesai, ikuti langkah-langkah di bawah ini untuk mengonfigurasi dua buah ekstensi siswa beserta layanan kotak suara (*Voicemail*).

### Langkah 1: Konfigurasi Akun Ekstensi (`pjsip.conf`)

Buka file konfigurasi PJSIP:
```bash
sudo nano /etc/asterisk/pjsip.conf
```

Tambahkan baris berikut di **bagian paling bawah file**:

```ini
; ==============================================================================
; TRANSPORT UDP
; ==============================================================================
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060

; ==============================================================================
; TEMPLATE EKSTENSI (Mempermudah penambahan user baru)
; ==============================================================================
[endpoint-siswa](!)
type=endpoint
context=tjkt
disallow=all
allow=ulaw,alaw,gsm
allow=h264,vp8
direct_media=no

; ==============================================================================
; AKUN 100 (Siswa 1)
; ==============================================================================
[100](endpoint-siswa)
auth=100
aors=100
mailboxes=100@tjkt

[100]
type=auth
auth_type=userpass
username=100
password=123

[100]
type=aor
max_contacts=1
remove_existing=yes

; ==============================================================================
; AKUN 200 (Siswa 2)
; ==============================================================================
[200](endpoint-siswa)
auth=200
aors=200
mailboxes=200@tjkt

[200]
type=auth
auth_type=userpass
username=200
password=123

[200]
type=aor
max_contacts=1
remove_existing=yes
```

> **Catatan Teknis:** Parameter `remove_existing=yes` penting agar siswa yang membuka-tutup aplikasi softphone tidak terblokir oleh batasan kontak aktif.

---

### Langkah 2: Konfigurasi Kotak Suara (`voicemail.conf`)

Buka file konfigurasi voicemail:
```bash
sudo nano /etc/asterisk/voicemail.conf
```

Gulir ke baris paling bawah, lalu tambahkan konteks context `[tjkt]`:

```ini
[tjkt]
; Format: ekstensi => PIN,Nama Pemilik,Email_Penerima
100 => 1234,Siswa 100,siswa100@smk.local
200 => 1234,Siswa 200,siswa200@smk.local
```

---

### Langkah 3: Mengatur Alur Panggilan / Dialplan (`extensions.conf`)

Buka file pengaturan alur panggilan:
```bash
sudo nano /etc/asterisk/extensions.conf
```

Tambahkan alur logika pemanggilan berikut di baris paling bawah:

```ini
[tjkt]
; ----------------------------------------------------
; Panggilan ke Ekstensi 100
; ----------------------------------------------------
exten => 100,1,NoOp(Panggilan Masuk ke Ekstensi 100)
 same => n,Dial(PJSIP/100,15)             ; Berdering selama 15 detik
 same => n,VoiceMail(100@tjkt,u)          ; Jika tidak diangkat, lempar ke Voicemail
 same => n,Hangup()

; ----------------------------------------------------
; Panggilan ke Ekstensi 200
; ----------------------------------------------------
exten => 200,1,NoOp(Panggilan Masuk ke Ekstensi 200)
 same => n,Dial(PJSIP/200,15)
 same => n,VoiceMail(200@tjkt,u)
 same => n,Hangup()

; ----------------------------------------------------
; Layanan Mandiri Pengecekan Pesan Suara (*97)
; ----------------------------------------------------
exten => *97,1,NoOp(Siswa Mengakses Mesin Voicemail)
 same => n,VoiceMailMain(@tjkt)
 same => n,Hangup()
```

---

### Langkah 4: Menerapkan Konfigurasi

Jalankan perintah berikut agar Asterisk memuat perubahan file konfigurasi:

```bash
sudo asterisk -rx "pjsip reload"
sudo asterisk -rx "voicemail reload"
sudo asterisk -rx "dialplan reload"
```

---

## 📱 Panduan Pengujian pada Softphone (Siswa)

Instal aplikasi softphone SIP seperti **MicroSIP** (Windows), **Zoiper** (Android/iOS/PC), atau **Linphone**.

Gunakan parameter konfigurasi berikut:

| Parameter | Akun Siswa 1 | Akun Siswa 2 |
| :--- | :--- | :--- |
| **Account Name / Display Name** | Siswa 100 | Siswa 200 |
| **SIP Server / Domain** | `<IP-Server-Debian>` | `<IP-Server-Debian>` |
| **Username / Login / User ID** | `100` | `200` |
| **Password / Secret** | `123` | `123` |
| **Port Transpor** | `5060` (UDP) | `5060` (UDP) |

### Skenario Pengujian Lab:
1. **Panggilan Suara & Video:** Lakukan panggilan dari ekstensi `100` ke `200`. Uji fitur audio dan video.
2. **Pesan Suara (Voicemail):** Hubungi `200` dari `100`, lalu biarkan berdering hingga lebih dari 15 detik tanpa diangkat. Tunggu nada *beep*, ucapkan pesan singkat, lalu putus panggilan.
3. **Mengecek Pesan:** Dari ekstensi `200`, panggil nomor `*97`. Masukkan PIN `1234` untuk mendengarkan rekaman pesan suara yang ditinggalkan.

---

## 🔍 Perintah Diagnosis & Troubleshooting (CLI)

Gunakan perintah-perintah ini untuk memantau trafik panggilan secara *real-time*:

- **Melihat status registrasi ekstensi:**
  ```bash
  asterisk -rx "pjsip show endpoints"
  ```
- **Melihat status endpoint terdaftar (AOR):**
  ```bash
  asterisk -rx "pjsip show aors"
  ```
- **Masuk ke konsol Asterisk interaktif:**
  ```bash
  asterisk -rvvv
  ```
  *(Ketik `exit` atau tekan `Ctrl + C` untuk keluar dari CLI Asterisk).*

---

## 🗑️ Cara Menghapus (Uninstall)

Jika server ingin dikembalikan ke kondisi awal, jalankan skrip pembersih:

```bash
sudo ./uninstall-asterisk-22lts.sh
```

Skrip ini akan menghentikan service, membersihkan biner, mencopot service systemd, dan menghapus seluruh folder konfigurasi `/etc/asterisk`.

---

## Batasan Tanggung Jawab (Disclaimer)

Skrip dan seluruh materi panduan di dalam repositori ini disediakan semata-mata untuk **tujuan edukasi, pembelajaran, dan pengujian di lingkungan lab/praktikum**.

- Perangkat lunak ini disediakan dengan status **"AS IS" (Apa Adanya)**, tanpa jaminan performa, stabilitas, atau kesesuaian untuk lingkungan operasional tertentu.
- Pembuat repositori **tidak bertanggung jawab** atas segala kerusakan sistem operasi, kehilangan data, eror konfigurasi, downtime layanan, maupun kerugian lain yang mungkin timbul akibat eksekusi skrip installer atau uninstaller ini.
- Pengguna bertanggung jawab penuh atas segala tindakan eksekusi hak akses root (`sudo`) dan dianjurkan untuk selalu melakukan pencadangan (*backup*) berkala atau menjalankannya di lingkungan mesin virtual (*VM / Lab Sandbox*).

---

## Lisensi

Proyek ini didistribusikan di bawah naungan **[MIT License](LICENSE)**. Anda bebas menggunakan, memodifikasi, dan mendistribusikan ulang materi ini untuk kebutuhan belajar maupun pengembangan lebih lanjut.
