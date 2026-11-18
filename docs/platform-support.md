# REA platform / provider support matrix

Statuses come from live `rea doctor` and real CLI invocations on this device,
not from documentation alone. "Working" means a tool produced Evidence.

## Android / Termux arm64 (this device)

| Capability | Status | How it was enabled |
| --- | --- | --- |
| Ghidra / JADX / Kuna, APK analysis | working | base installer; arm64 decompiler built from source |
| ADB device tools (24 tools) | working | `pkg install android-tools`, `REA_ADB_PATH` |
| WASM (`inspect_wasm_artifact`) | working | WABT 1.0.42 from Termux repo |
| Firmware scan / extraction | working | Binwalk 3.1.0 + `rea-android-prlimit` shim (bionic CFI crashes under `prlimit --as`) |
| EVM interface (`inspect_evm_interface`) | working | REA bundles `evmole_bg.wasm`; old x64-only gate widened |
| ELF layout / recorded crash | working | pwntools 4.15.0 + pyelftools 0.33 in a venv using Termux's patched psutil/cryptography; x64-only gate widened |
| JS source recovery (`recover_javascript_sources`) | working | Wakaru 1.16.0 (npm) + its linux-arm64 Rust binary run under proot with a minimal Debian glibc rootfs; x64-only gate widened |
| Packet capture / fields | working | TShark 4.2.2 installed inside the Ubuntu 24.04 proot; wrapper preserves cwd |
| sigrok signal decoding | installed, probe-limited | sigrok-cli 0.7.2 installed in proot, but its libusb backend cannot initialise there, so `-L` and decoder listing return no output. REA's version check is satisfied by a dpkg-sourced banner shim; real decoding remains unverified. |
| Browser / CDP | not installed locally | No headless Chromium in Termux repos and Ubuntu 24.04's `chromium-browser` is a snap stub. Use `scripts/setup-browser-cdp.sh` to forward a remote CDP port to `127.0.0.1:9222`. A full Debian/Ubuntu Chromium inside proot is possible but was not installed here. |
| Unblob extraction | not installed | PyPI manylinux wheel is glibc-linked and the Rust source build needs an unsupported Android target. It could be installed inside the Ubuntu proot with `pip install unblob==26.6.4` if needed. |
| JEB | unavailable | Commercial product; start its MCP server and set `REA_JEB_MCP_URL` |
| macOS tools (Mach-O, codesign, plist, asset catalog, native UI) | impossible on Android | Require Darwin kernel APIs and Xcode tools |
| iOS device tools | not applicable | REA has no iOS device provider |

`target_required` tools (`open_binary`, `analyze_function`, `xrefs`, ...) are
not missing — they activate when a target is opened.

### Reproduce

`scripts/enable-arm64-capabilities.sh` re-applies the gate patch, builds the
pwntools venv, recreates the Wakaru proot rootfs, and installs TShark/sigrok
in the Ubuntu proot. If REA is upgraded, re-run it.

### Caveats

- The REA gate patch (`toolchain/patch-rea-arm64-gates.cjs`) edits the installed
  `cli.js`; a backup is kept at `cli.js.arm64-backup`.
- The `unicorn` entry is a **metadata-only stub** because the native extension
  cannot build on Android. REA's pwntools bridges check its version but never
  import it; this is documented, not hidden.
- The `prlimit` shim drops CPU/address-space ceilings that crash bionic; use it
  only with trusted tools and files.

## macOS (Apple Silicon / Intel)

Run `platform/macos/setup.sh` on a real Mac. Xcode CLT supplies the utilities
behind `inspect_macho`, `inspect_signature`, `inspect_plist`,
`inspect_asset_catalog`, `demangle_swift`, and native UI tools. Playwright's
Chromium provides `REA_BROWSER_EXECUTABLE`.

## iPhone / iOS

REA has no iOS device provider and cannot gain one by installing packages on a
phone. iOS support is static analysis on a macOS host:

1. Pull the IPA with `ideviceinstaller` / `iproxy`.
2. Open the IPA as a ZIP archive with REA's artifact inventory tools.
3. Analyze the embedded Mach-O executable with the macOS-native provider.

Live iOS instrumentation is Frida / LLDB / Xcode work, outside REA.

## Skills

Skills are Markdown instruction sets, not compiled components. The installed
skills (`opencode`, `report`, `reverse-engineer-anything`, `rea-platform-setup`)
load on every platform. Platform support is a matter of MCP tools and their
external providers, not skills.
