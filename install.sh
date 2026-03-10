#!/usr/bin/env bash
# install.sh — tiddly-winks installer
# Idempotent: safe to run again after git pull to pick up changes.
#
# What it does:
#   1. Creates ~/.tiddly-winks/ runtime directory structure
#   2. Symlinks tw to ~/.local/bin/tw (so git pull updates it automatically)
#   3. Initializes sessions.json and Caddyfile if not present
#   4. Generates the Caddy LaunchDaemon plist
#   5. Prints next steps

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TW_DIR="$HOME/.tiddly-winks"
BIN_DIR="$HOME/.local/bin"

# ─── Colors ──────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

ok()   { echo -e "${GREEN}  ✓${RESET} $*"; }
info() { echo -e "${CYAN}  →${RESET} $*"; }
warn() { echo -e "${YELLOW}  !${RESET} $*"; }

echo ""
echo "tiddly-winks installer"
echo "repo: $REPO_DIR"
echo ""

# ─── Runtime directory ───────────────────────────────────────────────────────
mkdir -p "$TW_DIR/logs"
ok "Runtime dir: $TW_DIR"

# Initialize sessions.json if not present
if [[ ! -f "$TW_DIR/sessions.json" ]]; then
    echo '{}' > "$TW_DIR/sessions.json"
    ok "Created sessions.json"
else
    ok "sessions.json exists (untouched)"
fi

# Initialize Caddyfile if not present
if [[ ! -f "$TW_DIR/Caddyfile" ]]; then
    cat > "$TW_DIR/Caddyfile" <<'EOF'
{
    # Caddy admin API — needed for hot reload
    admin localhost:2019
}
EOF
    ok "Created Caddyfile"
else
    ok "Caddyfile exists (untouched)"
fi

# ─── Migrate from ~/.devenv if it exists ─────────────────────────────────────
if [[ -d "$HOME/.devenv" && ! -f "$TW_DIR/.migrated" ]]; then
    warn "Found ~/.devenv — migrating sessions.json..."
    if [[ -f "$HOME/.devenv/sessions.json" ]]; then
        # Only migrate if tw sessions.json is still empty
        tw_sessions=$(cat "$TW_DIR/sessions.json")
        if [[ "$tw_sessions" == "{}" ]]; then
            cp "$HOME/.devenv/sessions.json" "$TW_DIR/sessions.json"
            ok "Migrated sessions.json from ~/.devenv"
        else
            warn "tw sessions.json not empty — skipping migration"
        fi
    fi
    touch "$TW_DIR/.migrated"
    info "Old ~/.devenv left in place — remove manually when ready"
fi

# ─── Symlink binary ──────────────────────────────────────────────────────────
mkdir -p "$BIN_DIR"
chmod +x "$REPO_DIR/bin/tw"

if [[ -L "$BIN_DIR/tw" ]]; then
    # Remove old symlink (may point to a different location)
    rm "$BIN_DIR/tw"
fi
ln -s "$REPO_DIR/bin/tw" "$BIN_DIR/tw"
ok "Symlinked: $BIN_DIR/tw → $REPO_DIR/bin/tw"

# Check PATH
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
    warn "$BIN_DIR is not in your PATH"
    warn "Add to ~/.zshrc or ~/.bashrc:  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# ─── Caddy LaunchDaemon plist ─────────────────────────────────────────────────
PLIST_DEST="$TW_DIR/com.bentley.tw-caddy.plist"
CADDY_BIN="${CADDY_BIN:-/opt/homebrew/bin/caddy}"

cat > "$PLIST_DEST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.bentley.tw-caddy</string>

    <key>ProgramArguments</key>
    <array>
        <string>$CADDY_BIN</string>
        <string>run</string>
        <string>--config</string>
        <string>$TW_DIR/Caddyfile</string>
        <string>--adapter</string>
        <string>caddyfile</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>UserName</key>
    <string>root</string>

    <key>StandardOutPath</key>
    <string>$TW_DIR/logs/caddy.log</string>

    <key>StandardErrorPath</key>
    <string>$TW_DIR/logs/caddy.log</string>
</dict>
</plist>
EOF
ok "Generated plist: $PLIST_DEST"

# Check if old devenv caddy plist is loaded
if sudo launchctl list 2>/dev/null | grep -q "com.bentley.devenv-caddy"; then
    warn "Old com.bentley.devenv-caddy plist is loaded"
    warn "Run: sudo launchctl unload /Library/LaunchDaemons/com.bentley.devenv-caddy.plist"
fi

# ─── Next steps ──────────────────────────────────────────────────────────────
echo ""
echo "Installation complete. To finish setup:"
echo ""
if ! sudo launchctl list 2>/dev/null | grep -q "com.bentley.tw-caddy"; then
    echo "  1. Install Caddy LaunchDaemon (runs Caddy as root for port 80):"
    echo "     sudo cp $PLIST_DEST /Library/LaunchDaemons/"
    echo "     sudo launchctl load /Library/LaunchDaemons/com.bentley.tw-caddy.plist"
    echo ""
    echo "  2. Verify Caddy is running:"
    echo "     curl -s http://localhost:2019/config/"
    echo ""
    echo "  3. Add to ~/.zshrc if not already present:"
    echo "     export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
else
    ok "Caddy LaunchDaemon already loaded"
    echo ""
    echo "  Update Caddy config (if plist changed):"
    echo "    sudo launchctl unload /Library/LaunchDaemons/com.bentley.tw-caddy.plist"
    echo "    sudo cp $PLIST_DEST /Library/LaunchDaemons/"
    echo "    sudo launchctl load /Library/LaunchDaemons/com.bentley.tw-caddy.plist"
    echo ""
fi
echo "  Run 'tw help' to get started."
echo ""
