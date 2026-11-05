#!/usr/bin/env bash
# ============================================================================
#  WhiteSur Plasma Setup — Auto Installer
#  Distro target : Arch / CachyOS (bash, pacman)
#  Tujuan        : Menyiapkan tema + settingan fix di laptop lain
#  Sifat         : Idempoten (aman dijalankan berulang) & bisa di-rollback
# ============================================================================
set -uo pipefail

# ---------------------------------------------------------------------------
# 0. Konstanta & lokasi
# ---------------------------------------------------------------------------
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/whitesur-plasma-setup"
SRC_DIR="$WORK_DIR/src"
LOG_FILE="$WORK_DIR/install.log"
BACKUP_ROOT="$HOME/.local/state/whitesur-plasma-setup/backups"
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/$TS"

# --- Pilihan tema (ubah di sini kalau mau varian lain) ---------------------
DESKTOP_THEME="WhiteSur-dark"      # plasma/desktoptheme
COLOR_SCHEME="WhiteSurDark"        # color-schemes
ICON_THEME="Mkos-Big-Sur-Night"    # icons
CURSOR_THEME="WhiteSur-cursors"    # kursor
SPLASH_THEME="AppleSplash"         # look-and-feel (splash)
GTK_THEME_NAME="WhiteSur-Dark"     # gtk/window
WALLPAPER="/usr/share/wallpapers/cachyos-wallpapers/north.png"

# --- Sumber upstream ------------------------------------------------------
URL_WHITESUR_KDE="https://github.com/vinceliuice/WhiteSur-kde.git"
URL_WHITESUR_GTK="https://github.com/vinceliuice/WhiteSur-gtk-theme.git"
URL_WHITESUR_CURSORS="https://github.com/vinceliuice/WhiteSur-cursors.git"
URL_MKOS_ICONS="https://github.com/zayronxio/Mkos-Big-Sur.git"

# ---------------------------------------------------------------------------
# 1. Helper output
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
  C_R=$'\e[31m'; C_G=$'\e[32m'; C_Y=$'\e[33m'; C_B=$'\e[36m'; C_D=$'\e[2m'; C_0=$'\e[0m'
else
  C_R=''; C_G=''; C_Y=''; C_B=''; C_D=''; C_0=''
fi
step()  { printf '\n%s==>%s %s%s%s\n' "$C_B" "$C_0" "$C_B" "$*" "$C_0"; }
info()  { printf '    %s\n' "$*"; }
ok()    { printf '    %s✓%s %s\n' "$C_G" "$C_0" "$*"; }
warn()  { printf '    %s!%s %s\n' "$C_Y" "$C_0" "$*"; }
die()   { printf '\n%sERROR:%s %s\n' "$C_R" "$C_0" "$*" >&2; exit 1; }

# Semua perintah dicatat
mkdir -p "$WORK_DIR"; : > "$LOG_FILE"
run() { echo "+ $*" >> "$LOG_FILE"; "$@" >> "$LOG_FILE" 2>&1; }

# ---------------------------------------------------------------------------
# 2. Parse argumen
# ---------------------------------------------------------------------------
SKIP_DOWNLOAD=0
SKIP_DEPS=0
SKIP_LAYOUT=0
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --skip-download) SKIP_DOWNLOAD=1 ;;
    --skip-deps)     SKIP_DEPS=1 ;;
    --config-only)   SKIP_DOWNLOAD=1; SKIP_DEPS=1 ;;
    --no-layout)     SKIP_LAYOUT=1 ;;
    --dry-run)       DRY_RUN=1 ;;
    -h|--help)
      cat <<EOF
Pemakaian: ./install.sh [opsi]

  --skip-deps      Jangan install paket (asumsikan sudah lengkap)
  --skip-download  Jangan clone/unduh tema (hanya terapkan config)
  --config-only    = --skip-deps + --skip-download
  --no-layout      Jangan sentuh susunan panel (hanya tema + settingan)
  --dry-run        Tampilkan rencana, tidak mengubah apa pun
  -h, --help       Bantuan ini

Log lengkap: $LOG_FILE
EOF
      exit 0 ;;
    *) die "Opsi tidak dikenal: $arg (pakai --help)" ;;
  esac
done

if [ "$DRY_RUN" = 1 ]; then
  warn "MODE DRY-RUN: tidak ada yang diubah."
fi

# ---------------------------------------------------------------------------
# 3. Pemeriksaan awal
# ---------------------------------------------------------------------------
step "Memeriksa lingkungan"

[ -n "${XDG_CURRENT_DESKTOP:-}" ] || warn "XDG_CURRENT_DESKTOP kosong (jalankan dari sesi Plasma)"
case "${XDG_CURRENT_DESKTOP:-}" in
  *KDE*) ok "Sesi Plasma terdeteksi (${XDG_CURRENT_DESKTOP})" ;;
  "")    : ;;
  *)     warn "Desktop bukan KDE (${XDG_CURRENT_DESKTOP}); lanjut tapi hasil mungkin tidak penuh" ;;
esac

if ! command -v kwriteconfig6 >/dev/null; then
  die "kwriteconfig6 tidak ada. Ini untuk Plasma 6. Pastikan paket 'plasma-workspace' terpasang."
fi
ok "Plasma 6 tooling tersedia"

# Direktori tujuan
if [ "$DRY_RUN" = 0 ]; then
mkdir -p "$HOME/.config" \
         "$HOME/.local/share/plasma/desktoptheme" \
         "$HOME/.local/share/plasma/look-and-feel" \
         "$HOME/.local/share/plasma/plasmoids" \
         "$HOME/.local/share/color-schemes" \
         "$HOME/.local/share/icons" \
         "$HOME/.icons" || die "Gagal membuat direktori tujuan"
fi

command -v git   >/dev/null || die "git tidak ditemukan (wajib untuk mengunduh tema)"
command -v curl  >/dev/null || die "curl tidak ditemukan"
ok "git & curl tersedia"

# ---------------------------------------------------------------------------
# 4. Backup konfigurasi lama
# ---------------------------------------------------------------------------
step "Backup konfigurasi lama"
if [ "$DRY_RUN" = 1 ]; then
  warn "(dry-run) akan membackup config lama → $BACKUP_DIR"
  BACKED_UP=0
else
mkdir -p "$BACKUP_DIR/config"
BACKED_UP=0
for f in kdeglobals plasmarc ksplashrc kwinrc kcminputrc konsolesshconfig \
         plasma-org.kde.plasma.desktop-appletsrc plasmashellrc; do
  if [ -f "$HOME/.config/$f" ]; then
    cp -a "$HOME/.config/$f" "$BACKUP_DIR/config/$f" && BACKED_UP=$((BACKED_UP+1))
  fi
done
for d in gtk-3.0 gtk-4.0; do
  if [ -d "$HOME/.config/$d" ]; then
    cp -a "$HOME/.config/$d" "$BACKUP_DIR/config/$d" 2>/dev/null && BACKED_UP=$((BACKED_UP+1))
  fi
done
[ -f "$HOME/.gtkrc-2.0" ] && cp -a "$HOME/.gtkrc-2.0" "$BACKUP_DIR/config/gtkrc-2.0"

# Catat tema yang terpasang SEBELUM ini (untuk rollback)
{
  echo "DESKTOP_THEME=$DESKTOP_THEME"
  echo "COLOR_SCHEME=$COLOR_SCHEME"
  echo "ICON_THEME=$ICON_THEME"
  echo "CURSOR_THEME=$CURSOR_THEME"
  echo "SPLASH_THEME=$SPLASH_THEME"
} > "$BACKUP_DIR/themes.env"

cat > "$BACKUP_DIR/rollback.sh" <<'EOS'
#!/usr/bin/env bash
# Mengembalikan konfigurasi tampilan seperti sebelum install.sh dijalankan.
set -uo pipefail
BK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo ">> Menghentikan plasmashell sementara..."
systemctl --user stop plasma-plasmashell.service 2>/dev/null || true
for item in "$BK"/config/*; do
  [ -e "$item" ] || continue
  name="$(basename "$item")"
  case "$name" in
    gtkrc-2.0) cp -a "$item" "$HOME/.gtkrc-2.0" ;;
    *)         cp -a "$item" "$HOME/.config/$name" ;;
  esac
  echo "   restored: $name"
done
rm -f "$HOME"/.cache/icon-cache.kcache "$HOME"/.cache/ksvg-elements* 2>/dev/null || true
rm -rf "$HOME"/.cache/plasma_theme_* 2>/dev/null || true
systemctl --user start plasma-plasmashell.service 2>/dev/null || true
echo ">> Selesai. Silakan logout/login jika tampilan belum berubah."
EOS
chmod +x "$BACKUP_DIR/rollback.sh"

if [ "$BACKED_UP" -gt 0 ]; then
  ok "$BACKED_UP item lama dibackup → $BACKUP_DIR"
else
  warn "Tidak ada config lama (instalasi bersih)."
fi
ok "Rollback tersedia: $BACKUP_DIR/rollback.sh"
fi

# ---------------------------------------------------------------------------
# 5. Install paket pendukung (opsional)
# ---------------------------------------------------------------------------
step "Paket pendukung"
if [ "$SKIP_DEPS" = 1 ]; then
  info "Dilewati (--skip-deps)."
else
  # Hanya paket yang benar-benar dipakai. Tidak wajib sukses semua.
  PKGS=(git curl unzip gtk3 gtk4 gtk-engine-murrine sassc rsync)
  FONT_PKGS=(noto-fonts ttf-hack)
  MISSING=()
  for p in "${PKGS[@]}" "${FONT_PKGS[@]}"; do
    pacman -Q "$p" >/dev/null 2>&1 || MISSING+=("$p")
  done
  if [ "${#MISSING[@]}" -eq 0 ]; then
    ok "Semua paket pendukung sudah terpasang."
  else
    info "Perlu: ${MISSING[*]}"
    if [ "$DRY_RUN" = 1 ]; then
      warn "(dry-run) akan menjalankan: sudo pacman -S --needed --noconfirm ${MISSING[*]}"
    elif sudo -n true 2>/dev/null || sudo -v 2>/dev/null; then
      run sudo pacman -S --needed --noconfirm "${MISSING[@]}" \
        && ok "Paket terpasang." \
        || warn "Sebagian paket gagal dipasang — tema mungkin kurang sempurna. Cek: $LOG_FILE"
    else
      warn "Tidak bisa sudo. Lewati. Pasang manual bila perlu:"
      warn "  sudo pacman -S --needed ${MISSING[*]}"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 6. Unduh & pasang tema
# ---------------------------------------------------------------------------
step "Tema & aset"
if [ "$SKIP_DOWNLOAD" = 1 ]; then
  info "Dilewati (--skip-download)."
else
  mkdir -p "$SRC_DIR"

  clone_or_update() { # $1=url $2=dir
    local url="$1" dir="$2"
    if [ -d "$dir/.git" ]; then
      run git -C "$dir" pull --ff-only || warn "Gagal update $(basename "$dir"), pakai versi lama."
    else
      run git clone --depth=1 "$url" "$dir" || return 1
    fi
  }

  # --- 6a. WhiteSur-kde (desktop theme + color-scheme + aurorae) ----------
  info "WhiteSur-kde…"
  if clone_or_update "$URL_WHITESUR_KDE" "$SRC_DIR/WhiteSur-kde"; then
    if [ "$DRY_RUN" = 1 ]; then
      warn "(dry-run) akan menjalankan install.sh WhiteSur-kde -c dark -t default --round"
    else
      ( cd "$SRC_DIR/WhiteSur-kde" && \
        run bash ./install.sh -c dark -t default --round ) \
        && ok "WhiteSur-kde terpasang." \
        || warn "Installer WhiteSur-kde gagal, lihat log."
    fi
  else
    warn "Gagal mengunduh WhiteSur-kde."
  fi

  # --- 6b. WhiteSur-gtk-theme (GTK 3/4) ----------------------------------
  info "WhiteSur-gtk-theme…"
  if clone_or_update "$URL_WHITESUR_GTK" "$SRC_DIR/WhiteSur-gtk-theme"; then
    if [ "$DRY_RUN" = 1 ]; then
      warn "(dry-run) akan menjalankan install.sh WhiteSur-gtk-theme -l -c dark --tweaks round"
    else
      ( cd "$SRC_DIR/WhiteSur-gtk-theme" && \
        run bash ./install.sh -l -c dark -t default --tweaks round ) \
        && ok "WhiteSur GTK terpasang." \
        || warn "Installer GTK gagal, lihat log."
    fi
  else
    warn "Gagal mengunduh WhiteSur-gtk-theme."
  fi

  # --- 6c. Ikon Mkos-Big-Sur ---------------------------------------------
  info "Mkos-Big-Sur (ikon)…"
  if clone_or_update "$URL_MKOS_ICONS" "$SRC_DIR/Mkos-Big-Sur"; then
    if [ "$DRY_RUN" = 1 ]; then
      warn "(dry-run) akan menyalin ikon ke ~/.local/share/icons."
    else
      mkdir -p "$HOME/.local/share/icons/Mkos-Big-Sur"
      run rsync -a --delete \
        --exclude '.git' "$SRC_DIR/Mkos-Big-Sur/" \
        "$HOME/.local/share/icons/Mkos-Big-Sur/"
      ok "Ikon Mkos-Big-Sur terpasang."
    fi
  else
    warn "Gagal mengunduh ikon Mkos-Big-Sur."
  fi

  # --- 6d. Kursor WhiteSur -----------------------------------------------
  info "WhiteSur-cursors…"
  if clone_or_update "$URL_WHITESUR_CURSORS" "$SRC_DIR/WhiteSur-cursors"; then
    if [ "$DRY_RUN" = 1 ]; then
      warn "(dry-run) akan menjalankan build.sh + install.sh WhiteSur-cursors"
    else
      ( cd "$SRC_DIR/WhiteSur-cursors" && \
        run bash ./install.sh ) \
        && ok "Kursor terpasang." \
        || warn "Installer kursor gagal, lihat log."
    fi
  else
    warn "Gagal mengunduh WhiteSur-cursors."
  fi
fi

# ---------------------------------------------------------------------------
# 6e. Look-and-feel (splash) — dibundel di repo, tidak perlu unduh
# ---------------------------------------------------------------------------
if [ -d "$REPO_DIR/assets/AppleSplash" ]; then
  if [ "$DRY_RUN" = 1 ]; then
    warn "(dry-run) akan memasang splash AppleSplash."
  else
    run rm -rf "$HOME/.local/share/plasma/look-and-feel/AppleSplash"
    cp -a "$REPO_DIR/assets/AppleSplash" "$HOME/.local/share/plasma/look-and-feel/"
    ok "Splash AppleSplash terpasang."
  fi
fi

# ---------------------------------------------------------------------------
# 6f. Plasmoid pihak ketiga — dibundel di repo
# ---------------------------------------------------------------------------
if [ -d "$REPO_DIR/plasmoids" ]; then
  for p in "$REPO_DIR"/plasmoids/*/; do
    [ -d "$p" ] || continue
    name="$(basename "$p")"
    if [ "$DRY_RUN" = 1 ]; then continue; fi
    run rm -rf "$HOME/.local/share/plasma/plasmoids/$name"
    cp -a "$p" "$HOME/.local/share/plasma/plasmoids/$name"
  done
  [ "$DRY_RUN" = 1 ] || ok "Plasmoid pihak ketiga terpasang."
fi

# ---------------------------------------------------------------------------
# 7. Terapkan settingan fix (kdeglobals, plasmarc, dst.)
# ---------------------------------------------------------------------------
step "Menerapkan settingan fix"

apply_file() { # $1 = nama file di config/ ; $2 = tujuan relatif $HOME atau absolut
  local src="$REPO_DIR/config/$1" dst="$2"
  [ -f "$src" ] || { warn "config/$1 tidak ada, dilewati."; return 0; }
  if [ "$DRY_RUN" = 1 ]; then warn "(dry-run) tulis $src → $dst"; return 0; fi
  mkdir -p "$(dirname "$dst")"
  cp -f "$src" "$dst"
  ok "$1"
}

# kdeglobals — tema, warna, font
apply_file kdeglobals "$HOME/.config/kdeglobals"
apply_file plasmarc   "$HOME/.config/plasmarc"
apply_file ksplashrc  "$HOME/.config/ksplashrc"
apply_file gtk-3.0-settings.ini "$HOME/.config/gtk-3.0/settings.ini"
apply_file gtk-4.0-settings.ini "$HOME/.config/gtk-4.0/settings.ini"

# konsolesshconfig & yang tidak ada di repo -> lewati dengan sopan
for f in konsolesshconfig; do
  [ -f "$REPO_DIR/config/$f" ] && apply_file "$f" "$HOME/.config/$f"
done

# .gtkrc-2.0 (GTK2 apps)
if [ -f "$REPO_DIR/config/gtkrc-2.0" ]; then
  [ "$DRY_RUN" = 1 ] || cp -f "$REPO_DIR/config/gtkrc-2.0" "$HOME/.gtkrc-2.0"
  ok ".gtkrc-2.0"
fi

# --- kcminputrc: MERGE, jangan timpa setting touchpad ---------------------
if [ "$DRY_RUN" = 1 ]; then
  warn "(dry-run) merge kcminputrc (cursor only)"
else
  if command -v kwriteconfig6 >/dev/null; then
    kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme "$CURSOR_THEME"
    kwriteconfig6 --file kcminputrc --group Mouse --key cursorSize  24
    ok "kcminputrc (cursor) — setting touchpad dipertahankan."
  fi
fi

# --- kwinrc: MERGE lewat kwriteconfig6 agar tak menghapus setting lain ---
if [ "$DRY_RUN" = 1 ]; then
  warn "(dry-run) merge kwinrc"
else
  # Dekorasi jendela: pakai Aurorae WhiteSur-dark (gaya macOS), BUKAN Breeze.
  # Kalau tema Aurorae-nya belum ada, jangan dipaksa — biar Plasma pakai default.
  if [ -d "$HOME/.local/share/aurorae/themes/WhiteSur-dark" ] \
     || [ -d "/usr/share/aurorae/themes/WhiteSur-dark" ]; then
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key library org.kde.kwin.aurorae.v2
    kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme   __aurorae__svg__WhiteSur-dark
    ok "Dekorasi jendela: Aurorae WhiteSur-dark"
  else
    warn "Tema Aurorae 'WhiteSur-dark' belum terpasang — dekorasi jendela dibiarkan apa adanya."
  fi
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft XIA
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight ""
  kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key NoPlugin false
  kwriteconfig6 --file kwinrc --group Effect-blur --key NoiseStrength 7
  kwriteconfig6 --file kwinrc --group Effect-blur --key Saturation 152
  kwriteconfig6 --file kwinrc --group Plugins --key kwin4_effect_yetanothermagiclampEnabled true
  kwriteconfig6 --file kwinrc --group Plugins --key libkwin4_effect_yetanothermagiclampEnabled true
  kwriteconfig6 --file kwinrc --group Plugins --key yetanothermagiclampEnabled true
  kwriteconfig6 --file kwinrc --group Plugins --key mouseclickEnabled true
  kwriteconfig6 --file kwinrc --group Plugins --key magiclampEnabled false
  kwriteconfig6 --file kwinrc --group Plugins --key squashEnabled false
  ok "kwinrc (dekorasi, blur, magic lamp)"
fi

# ---------------------------------------------------------------------------
# 8. Terapkan tema lewat tool Plasma (lebih aman daripada copy manual)
# ---------------------------------------------------------------------------
step "Menerapkan tema"
if [ "$DRY_RUN" = 1 ]; then
  warn "(dry-run) plasma-apply-colorscheme $COLOR_SCHEME, dst."
else
  if command -v plasma-apply-colorscheme >/dev/null; then
    run plasma-apply-colorscheme "$COLOR_SCHEME" && ok "Skema warna: $COLOR_SCHEME" \
      || warn "Skema warna $COLOR_SCHEME tidak ketemu — pakai BreezeDark."
  fi
  # Tema Plasma (desktop theme)
  kwriteconfig6 --file plasmarc --group Theme --key name "$DESKTOP_THEME"
  ok "Desktop theme: $DESKTOP_THEME"

  # Kursor via kreadconfig fallback
  kwriteconfig6 --file kdeglobals --group Icons --key Theme "$ICON_THEME"
  ok "Ikon: $ICON_THEME"

  # Splash
  kwriteconfig6 --file ksplashrc --group KSplash --key Theme "$SPLASH_THEME"
  kwriteconfig6 --file ksplashrc --group KSplash --key Engine org.kde.image
  ok "Splash: $SPLASH_THEME"

  # GTK
  for g in gtk-3.0 gtk-4.0; do
    [ -d "$HOME/.config/$g" ] || continue
    kwriteconfig6 --file "$g/settings.ini" --group Settings --key gtk-theme-name "$GTK_THEME_NAME"
    kwriteconfig6 --file "$g/settings.ini" --group Settings --key gtk-icon-theme-name "$ICON_THEME"
    kwriteconfig6 --file "$g/settings.ini" --group Settings --key gtk-cursor-theme-name "$CURSOR_THEME"
  done
  ok "GTK3/GTK4"
fi

# Wallpaper
if [ -f "$WALLPAPER" ]; then
  if [ "$DRY_RUN" = 1 ]; then
    warn "(dry-run) wallpaper → $WALLPAPER"
  else
    plasma-apply-wallpaperimage "$WALLPAPER" >> "$LOG_FILE" 2>&1 \
      && ok "Wallpaper: $(basename "$WALLPAPER")" \
      || warn "Wallpaper tidak bisa diterapkan (bukan fatal)."
  fi
else
  warn "Wallpaper $WALLPAPER tidak ada — dilewati."
fi

# ---------------------------------------------------------------------------
# 9. Susunan panel (opsional, bisa dilewati)
# ---------------------------------------------------------------------------
step "Susunan panel"
if [ "$SKIP_LAYOUT" = 1 ]; then
  info "Dilewati (--no-layout). Panel lama Anda tetap utuh."
elif [ ! -f "$REPO_DIR/layout/plasma-appletsrc.template" ]; then
  warn "Template layout tidak ada — dilewati."
elif [ "$DRY_RUN" = 1 ]; then
  warn "(dry-run) akan menulis ulang susunan panel dari template."
else
  warn "Susunan panel akan DIGANTI dengan template repo."
  warn "Layout lama sudah dibackup → $BACKUP_DIR/rollback.sh"
  systemctl --user stop plasma-plasmashell.service 2>/dev/null || true
  sleep 1
  cp -f "$REPO_DIR/layout/plasma-appletsrc.template" \
        "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
  ok "Layout panel diterapkan."
  systemctl --user start plasma-plasmashell.service 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# 10. Bersihkan cache & muat ulang
# ---------------------------------------------------------------------------
step "Membersihkan cache & memuat ulang"
if [ "$DRY_RUN" = 1 ]; then
  warn "(dry-run) bersihkan cache + restart plasmashell"
else
  rm -f  "$HOME"/.cache/icon-cache.kcache 2>/dev/null
  rm -rf "$HOME"/.cache/ksvg-elements* \
         "$HOME"/.cache/plasma_theme_* \
         "$HOME"/.cache/plasma-svgelements-* 2>/dev/null
  kbuildsycoca6 >> "$LOG_FILE" 2>&1 || true
  ok "Cache dibersihkan."

  if command -v qdbus6 >/dev/null; then
    qdbus6 org.kde.KWin /KWin reconfigure >> "$LOG_FILE" 2>&1 \
      && ok "KWin dimuat ulang." || warn "KWin reconfigure dilewati."
  fi
fi

# ---------------------------------------------------------------------------
# 11. Ringkasan
# ---------------------------------------------------------------------------
step "Selesai"
cat <<EOF
  Desktop theme : $DESKTOP_THEME
  Skema warna   : $COLOR_SCHEME
  Ikon          : $ICON_THEME
  Kursor        : $CURSOR_THEME
  Splash        : $SPLASH_THEME
  GTK           : $GTK_THEME_NAME

  Log       : $LOG_FILE
  Backup    : $BACKUP_DIR
  Rollback  : $BACKUP_DIR/rollback.sh
EOF
printf '\n%s%s%s\n' "$C_Y" "Kalau tampilan belum berubah sepenuhnya, LOGOUT lalu LOGIN." "$C_0"
