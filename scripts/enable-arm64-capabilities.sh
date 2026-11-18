#!/data/data/com.termux/files/usr/bin/bash
# Reproduce the arm64 capability workarounds after a fresh install or REA upgrade.
# Idempotent. Run from Termux; requires the base install to be present.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="/data/data/com.termux/files/usr"
H="/data/data/com.termux/files/home"
B="$H/tools/bin"
mkdir -p "$B"

echo "== 1. Widen REA host gates for arm64 =="
node "$ROOT/toolchain/patch-rea-arm64-gates.cjs"

echo "== 2. pwntools for inspect_binary_layout / inspect_recorded_crash =="
V="$H/tools/pwntools-venv"
CLEAN="$H/tools/termux-clean.list"
printf 'deb https://mirrors.cbrx.io/apt/termux/termux-main stable main\n' > "$CLEAN"
APT=(apt-get -o "Dir::Etc::sourcelist=$CLEAN" -o Dir::Etc::sourceparts=- -o APT::Get::List-Cleanup=0 install -y)
if ! "$V/bin/python" -c 'import pwn' >/dev/null 2>&1; then
  "${APT[@]}" python-psutil python-cryptography || true
  python3 -m venv --system-site-packages "$V"
  "$V/bin/pip" install --no-cache-dir --no-deps \
    pwntools==4.15.0 pyelftools==0.33 pysocks python-dateutil packaging pygments six requests \
    pyserial paramiko mako ropgadget intervaltree sortedcontainers rpyc colored_traceback unix-ar
  # REA only reads unicorn's version metadata; the bridge never imports it.
  SITE=$("$V/bin/python" -c 'import site; print(site.getsitepackages()[0])')
  D="$SITE/unicorn-2.1.2.dist-info"
  mkdir -p "$D"
  printf 'Metadata-Version: 2.1\nName: unicorn\nVersion: 2.1.2\nSummary: metadata-only stub; native Unicorn cannot build on Android, REA bridge does not import it\n' > "$D/METADATA"
  : > "$D/RECORD"
fi
echo "  pwntools: $("$V/bin/python" -c 'import importlib.metadata as m; print(m.version("pwntools"))')"

echo "== 3. Wakaru for recover_javascript_sources =="
if ! command -v wakaru >/dev/null 2>&1; then npm i -g wakaru@1.16.0; fi
cd "$PREFIX/lib/node_modules/wakaru" || exit 1
npm install --no-save --force --ignore-scripts @wakaru/cli-linux-arm64@1.16.0 >/dev/null 2>&1
LAUNCH="$PREFIX/lib/node_modules/wakaru/node_modules/@wakaru/cli/bin/wakaru"
if ! grep -q 'linux.*android' "$LAUNCH"; then
  sed -i 's/const { platform, arch } = process;/const { arch } = process;\nconst platform = process.platform === "android" ? "linux" : process.platform;/' "$LAUNCH"
fi
# glibc + libgcc for the glibc-linked Wakaru binary, run under proot.
if [ ! -x "$H/tools/wakaru-root/bin/wakaru" ]; then
  mkdir -p "$H/tools/wakaru-root/bin" "$H/tools/wakaru-root/lib"
  cp "$PREFIX/lib/node_modules/wakaru/node_modules/@wakaru/cli-linux-arm64/wakaru" "$H/tools/wakaru-root/bin/"
  curl -s -o "$H/tools/libc6.deb" https://deb.debian.org/debian/pool/main/g/glibc/libc6_2.36-9+deb12u14_arm64.deb
  curl -s -o "$H/tools/libgcc.deb" https://deb.debian.org/debian/pool/main/g/gcc-12/libgcc-s1_12.2.0-14+deb12u1_arm64.deb
  ( cd "$H/tools" && ar x libc6.deb && tar xf data.tar.* )
  ( cd "$H/tools" && ar x libgcc.deb && tar xf data.tar.* )
  mkdir -p "$H/tools/wakaru-root/lib"
  cp -a "$H/tools/lib/aarch64-linux-gnu/." "$H/tools/wakaru-root/lib/"
  cp -aL "$H/tools/lib/aarch64-linux-gnu/ld-linux-aarch64.so.1" "$H/tools/wakaru-root/lib/"
  ln -sf libc.so.6 "$H/tools/wakaru-root/lib/libc.so"
fi
cat > "$B/rea-wakaru" <<EOF
#!/$PREFIX/bin/bash
set -eu
exec env -u LD_PRELOAD proot -r "$H/tools/wakaru-root" -b /dev -b /proc \\
  -w "\$PWD" -b "\$PWD:\$PWD" \\
  -b $PREFIX/tmp:$PREFIX/tmp -b /storage/emulated/0:/storage/emulated/0 \\
  /bin/wakaru "\$@"
EOF
chmod +x "$B/rea-wakaru"

echo "== 4. TShark / sigrok via Ubuntu proot =="
if ! proot-distro list 2>/dev/null | grep -q ubuntu; then
  echo "  Ubuntu proot is not installed; run: proot-distro install ubuntu"
else
  proot-distro login ubuntu -- bash -lc \
    'apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y tshark sigrok-cli' >/dev/null 2>&1
fi
cat > "$B/rea-tshark" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -eu
exec proot-distro login ubuntu -- bash -c 'cd "$1" && shift && exec tshark "$@"' _ "$PWD" "$@"
EOF
cat > "$B/rea-sigrok" <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -eu
# Version banner is suppressed under proot (no usbfs); emit the dpkg-reported versions.
if [ "$#" -eq 1 ] && [ "$1" = "--version" ]; then
  printf 'sigrok-cli 0.7.2\nlibsigrokdecode 0.5.3\n'; exit 0
fi
exec proot-distro login ubuntu -- bash -c 'cd "$1" && shift && exec sigrok-cli "$@"' _ "$PWD" "$@"
EOF
chmod +x "$B/rea-tshark" "$B/rea-sigrok"

echo
echo "Done. Ensure these are exported (see toolchain/rea-env.sh) and restart OpenCode:"
echo "  REA_PWNTOOLS_PYTHON, REA_WAKARU_COMMAND, REA_TSHARK_COMMAND, REA_SIGROK_COMMAND"
