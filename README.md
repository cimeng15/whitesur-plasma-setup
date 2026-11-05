# WhiteSur Plasma Setup

Auto-installer tema **WhiteSur-dark** (gaya macOS) + settingan fix untuk **KDE Plasma 6**.
Dibuat supaya bisa diterapkan ulang ke laptop lain dengan satu perintah.

Target: **Arch / CachyOS** (bash, `pacman`).

---

## Apa yang dipasang

| Bagian | Nilai |
|---|---|
| Desktop theme | `WhiteSur-dark` |
| Skema warna | `WhiteSurDark` |
| Ikon | `Mkos-Big-Sur-Night` |
| Kursor | `WhiteSur-cursors` (size 24) |
| Splash screen | `AppleSplash` |
| GTK theme | `WhiteSur-Dark` (GTK 2/3/4) |
| Font | Noto Sans 10 / Hack 10 (mono) |
| Tombol jendela | Kiri: `XIA` (close, minimize, maximize) |
| Efek KWin | Blur + Yet Another Magic Lamp |
| Wallpaper | CachyOS `north.png` |

Widget pihak ketiga yang ikut dibundel: **kpple menu**, **Window Title Fork**,
**simple separator**, **AppBay**, **Command Output**.

---

## Cara pakai di laptop lain

```bash
git clone https://github.com/cimeng15/whitesur-plasma-setup.git
cd whitesur-plasma-setup
chmod +x install.sh
./install.sh
```

Selesai. **Logout lalu login** supaya semua perubahan tampilan dimuat penuh.

### Opsi

```bash
./install.sh --help

  --skip-deps      Jangan install paket (asumsikan sudah lengkap)
  --skip-download  Jangan clone/unduh tema (hanya terapkan config)
  --config-only    = --skip-deps + --skip-download
  --no-layout      Jangan sentuh susunan panel (hanya tema + settingan)
  --dry-run        Tampilkan rencana, tidak mengubah apa pun
```

Contoh aman untuk mencoba dulu:

```bash
./install.sh --dry-run          # lihat rencana saja
./install.sh --no-layout        # tema + settingan, panel lama tetap utuh
```

---

## Rollback

Setiap kali dijalankan, installer membackup config lama. Untuk kembali:

```bash
~/.local/state/whitesur-plasma-setup/backups/<timestamp>/rollback.sh
```

Lalu logout/login.

---

## Catatan penting

- **Setting touchpad TIDAK ditimpa.** `kcminputrc` di-merge, hanya bagian
  kursor yang ditulis. Konfigurasi touchpad/device Anda tetap aman.
- **Susunan panel akan diganti** jika `--no-layout` tidak dipakai. Pakai
  `--no-layout` bila ingin mempertahankan panel yang sudah ada.
- **Config di `config/` adalah salinan bersih, bukan config asli mesin
  pengembang.** Beberapa nilai kustom (mis. `ColorSchemeHash`,
  `LookAndFeelPackage`, `accentColorFromWallpaper`) sengaja diseragamkan.
  Kalau di laptop lain Anda punya kustomisasi sendiri, backup dulu
  (`./install.sh --dry-run` lalu `--no-layout`) dan bandingkan dengan
  `~/.local/state/whitesur-plasma-setup/backups/`.
- **Dekorasi jendela** memakai Aurorae `WhiteSur-dark`. Bila tema itu belum
  terpasang, installer tidak memaksanya dan hanya memberi peringatan.
- Diuji pada Plasma 6 / CachyOS. Di distro Arch lain sebagian besar jalan,
  tapi nama wallpaper CachyOS akan dilewati bila tidak ada.
- Tema diunduh langsung dari upstream (Vinceliuice / zayronxio), jadi repo ini
  tidak menyimpan aset besar.

## Sumber tema

- [vinceliuice/WhiteSur-kde](https://github.com/vinceliuice/WhiteSur-kde)
- [vinceliuice/WhiteSur-gtk-theme](https://github.com/vinceliuice/WhiteSur-gtk-theme)
- [vinceliuice/WhiteSur-cursors](https://github.com/vinceliuice/WhiteSur-cursors)
- [zayronxio/Mkos-Big-Sur](https://github.com/zayronxio/Mkos-Big-Sur)
- [zayronxio/Apple-theme-Plasma](https://github.com/zayronxio/Apple-theme-Plasma)

## Struktur repo

```
install.sh                    # installer utama
config/                       # settingan fix (kdeglobals, kwinrc, gtk, dll.)
layout/plasma-appletsrc.template  # susunan panel
assets/AppleSplash/           # splash screen
plasmoids/                    # widget pihak ketiga
```
