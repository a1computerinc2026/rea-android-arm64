# REA Android/arm64 environment.
# Source this file (install.sh adds it to ~/.bashrc):
#   . "$HOME/rea-android-arm64/toolchain/rea-env.sh"

export JAVA_HOME="/data/data/com.termux/files/usr/lib/jvm/java-21-openjdk"
export GHIDRA_INSTALL_DIR="$HOME/tools/ghidra/ghidra_12.1.3_PUBLIC"
export REA_GHIDRA_STARTUP_TIMEOUT_MS=600000
export REA_JADX_MCP_JAR="$HOME/tools/jadx-mcp/jadx-headless-mcp-0.7.1-all.jar"
export REA_RIZIN_COMMAND="/data/data/com.termux/files/usr/bin/rizin"
export REA_APKTOOL_COMMAND="/data/data/com.termux/files/usr/bin/apktool"
# Optional: Kuna (if you installed the rea-mobile proot setup)
export REA_KUNA_COMMAND="$HOME/projects/rea-mobile/bin/kuna"