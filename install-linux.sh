#!/usr/bin/env bash
# Official SoundWave Linux Installer (x86_64)
# Installs / updates SoundWave into /opt/soundwave with desktop icon & `soundwave` command.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/SoundWave-labs/SoundWave/main/install-linux.sh | sudo bash

set -euo pipefail

REPO_SLUG="SoundWave-labs/SoundWave"
MANIFEST_URL="https://raw.githubusercontent.com/${REPO_SLUG}/main/version.json"
INSTALL_DIR="/opt/soundwave"
BIN_LINK="/usr/local/bin/soundwave"
UNINSTALL_BIN="/usr/local/bin/soundwave-uninstall"
DESKTOP_FILE="/usr/share/applications/soundwave.desktop"
ICON_FILE="/usr/share/icons/hicolor/512x512/apps/soundwave.png"

if [[ "$(uname -m)" != "x86_64" ]]; then
  echo "ERROR: SoundWave Linux currently supports x86_64 systems (detected: $(uname -m))."
  exit 1
fi

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Please run with sudo:"
  echo "  curl -fsSL https://raw.githubusercontent.com/${REPO_SLUG}/main/install-linux.sh | sudo bash"
  exit 1
fi

echo "==> Fetching latest SoundWave Linux release metadata..."
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

curl -fsSL "${MANIFEST_URL}?t=$(date +%s)" -o "${TMP_DIR}/version.json"

read -r VERSION_NAME LINUX_URL LINUX_SHA < <(
  python3 -c '
import json, sys
data = json.load(open(sys.argv[1]))
lx = data.get("linux", {}).get("x86_64", {})
print(data.get("version_name", ""), lx.get("url", ""), lx.get("sha256", ""))
' "${TMP_DIR}/version.json"
)

if [[ -z "$LINUX_URL" || -z "$LINUX_SHA" ]]; then
  echo "ERROR: Linux package metadata not found in version.json."
  exit 1
fi

echo "==> Downloading SoundWave v${VERSION_NAME} for Linux (x86_64)..."
TAR_PATH="${TMP_DIR}/soundwave-linux.tar.gz"
curl -fL --progress-bar "$LINUX_URL" -o "$TAR_PATH"

echo "==> Verifying SHA-256 integrity..."
ACTUAL_SHA="$(sha256sum "$TAR_PATH" | awk '{print $1}')"
if [[ "${ACTUAL_SHA,,}" != "${LINUX_SHA,,}" ]]; then
  echo "ERROR: SHA-256 verification failed!"
  echo "  Expected: ${LINUX_SHA}"
  echo "  Actual:   ${ACTUAL_SHA}"
  exit 1
fi
echo "    SHA-256 verified OK."

echo "==> Installing to ${INSTALL_DIR}..."
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
tar -xzf "$TAR_PATH" -C "$INSTALL_DIR"

chmod +x "${INSTALL_DIR}/soundwave"
ln -sf "${INSTALL_DIR}/soundwave" "$BIN_LINK"

mkdir -p "$(dirname "$ICON_FILE")"
if [[ -f "${INSTALL_DIR}/soundwave.png" ]]; then
  cp "${INSTALL_DIR}/soundwave.png" "$ICON_FILE"
fi

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=SoundWave
Comment=Privacy-First Studio Music Streaming & Offline Player
Exec=${BIN_LINK}
Icon=soundwave
Terminal=false
Type=Application
Categories=AudioVideo;Audio;Music;Player;
StartupWMClass=soundwave
EOF

cat > "$UNINSTALL_BIN" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "Run with sudo: sudo soundwave-uninstall"
  exit 1
fi
rm -rf /opt/soundwave /usr/local/bin/soundwave /usr/share/applications/soundwave.desktop /usr/share/icons/hicolor/512x512/apps/soundwave.png /usr/local/bin/soundwave-uninstall
echo "SoundWave uninstalled cleanly (your personal music & library files in ~/Music/SoundWave were preserved)."
EOF
chmod +x "$UNINSTALL_BIN"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t /usr/share/icons/hicolor >/dev/null 2>&1 || true
fi

echo ""
echo "✅ SoundWave v${VERSION_NAME} installed successfully!"
echo "   Launch from your App Menu or run: soundwave"
echo "   To uninstall later: sudo soundwave-uninstall"
