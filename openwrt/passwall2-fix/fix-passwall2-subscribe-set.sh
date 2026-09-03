#!/bin/sh
# Fix PassWall2 subscription save error on LuCI/ucodebridge:
# node_subscribe_config.lua: attempt to call method 'set' (a nil value)

set -eu

TARGET="${PASSWALL2_SUBSCRIBE_FILE:-/usr/lib/lua/luci/model/cbi/passwall2/client/node_subscribe_config.lua}"
BACKUP="${TARGET}.proxymonitor-setfix.bak"
MARKER="ProxyMonitor PassWall2 Map.set compatibility"
ACTION="${1:-install}"

say() {
	printf '%s\n' "$*"
}

restart_luci() {
	if [ "${PASSWALL2_SKIP_RESTART:-0}" = "1" ]; then
		return 0
	fi
	rm -f /tmp/luci-indexcache 2>/dev/null || true
	rm -rf /tmp/luci-modulecache 2>/dev/null || true
	if [ -x /etc/init.d/rpcd ]; then
		/etc/init.d/rpcd restart
	fi
	if [ -x /etc/init.d/uhttpd ]; then
		/etc/init.d/uhttpd restart
	fi
}

show_context() {
	say "--- Relevant lines ---"
	awk 'NR >= 96 && NR <= 114 { print NR ": " $0 }' "$TARGET" 2>/dev/null || true
	say "--- Remaining incompatible writes ---"
	grep -nE '(m|self\.map)\.uci:set(_list)?\(appname,|self:set\(' "$TARGET" 2>/dev/null || say "none"
}

status() {
	if [ ! -f "$TARGET" ]; then
		say "ERROR: PassWall2 file not found: $TARGET"
		exit 2
	fi
	if grep -q "$MARKER" "$TARGET"; then
		say "Compatibility guard: installed"
	else
		say "Compatibility guard: not installed"
	fi
	if grep -qE '(m|self\.map)\.uci:set(_list)?\(appname,|self:set\(' "$TARGET"; then
		say "Incompatible writes: found"
	else
		say "Incompatible writes: none"
	fi
	[ -f "$BACKUP" ] && say "Backup: $BACKUP" || say "Backup: not created"
	show_context
}

install_fix() {
	if [ "$(id -u)" != "0" ]; then
		say "ERROR: Run this script as root."
		exit 1
	fi
	if [ ! -f "$TARGET" ]; then
		say "ERROR: PassWall2 file not found: $TARGET"
		exit 2
	fi

	if [ ! -f "$BACKUP" ]; then
		cp -p "$TARGET" "$BACKUP"
		say "Backup created: $BACKUP"
	else
		say "Keeping existing backup: $BACKUP"
	fi

	TMP="${TARGET}.proxymonitor-setfix.tmp.$$"
	cp -p "$TARGET" "$TMP"

	# Use the CBI Map writer instead of calling the bridged UCI cursor directly.
	# These replacements match both the affected release and close variants.
	sed -i \
		-e 's/m\.uci:set(appname,/m:set(/g' \
		-e 's/m\.uci:set_list(appname,/m:set(/g' \
		-e 's/self\.map\.uci:set(appname,/self.map:set(/g' \
		-e 's/self\.map\.uci:set_list(appname,/self.map:set(/g' \
		-e 's/self:set(/self.map:set(/g' \
		"$TMP"

	# Add a guarded Map.set implementation only for LuCI builds where it is absent.
	# The body follows LuCI CBI Map.set semantics and does nothing on normal builds.
	if ! grep -q "$MARKER" "$TMP"; then
		AWK_TMP="${TMP}.awk"
		awk -v marker="$MARKER" '
			{
				print
				if (!done && $0 ~ /^[[:space:]]*api\.set_default_cbi\(\)[[:space:]]*$/) {
					print ""
					print "-- " marker
					print "local _pm_cbi = require \"luci.cbi\""
					print "if type(_pm_cbi.Map.set) ~= \"function\" then"
					print "\tfunction _pm_cbi.Map.set(self, section, option, value)"
					print "\t\tif type(value) ~= \"table\" or #value > 0 then"
					print "\t\t\tif option then"
					print "\t\t\t\treturn self.uci:set(self.config, section, option, value)"
					print "\t\t\telse"
					print "\t\t\t\treturn self.uci:set(self.config, section, value)"
					print "\t\t\tend"
					print "\t\telse"
					print "\t\t\treturn self:del(section, option)"
					print "\t\tend"
					print "\tend"
					print "end"
					done = 1
				}
			}
			END {
				if (!done) exit 7
			}
		' "$TMP" > "$AWK_TMP" || {
			rm -f "$TMP" "$AWK_TMP"
			say "ERROR: Could not locate api.set_default_cbi() safely; no changes installed."
			exit 3
		}
		mv "$AWK_TMP" "$TMP"
	fi

	if grep -qE '(m|self\.map)\.uci:set(_list)?\(appname,|self:set\(' "$TMP"; then
		rm -f "$TMP"
		say "ERROR: An incompatible write remains; original file was not changed."
		show_context
		exit 4
	fi

	if command -v luac >/dev/null 2>&1; then
		if ! luac -p "$TMP"; then
			rm -f "$TMP"
			say "ERROR: Lua syntax check failed; original file was not changed."
			exit 5
		fi
	elif command -v lua >/dev/null 2>&1; then
		if ! env PM_LUA_CHECK_FILE="$TMP" lua -e 'local p = os.getenv("PM_LUA_CHECK_FILE"); assert(p and p ~= ""); assert(loadfile(p))'; then
			rm -f "$TMP"
			say "ERROR: Lua syntax check failed; original file was not changed."
			exit 5
		fi
	fi

	chmod --reference="$TARGET" "$TMP" 2>/dev/null || chmod 644 "$TMP"
	chown --reference="$TARGET" "$TMP" 2>/dev/null || true
	mv "$TMP" "$TARGET"
	restart_luci

	say "FIXED: PassWall2 subscription writer updated."
	say "Wait 10 seconds, reopen LuCI, then save the subscription again."
	status
}

uninstall_fix() {
	if [ "$(id -u)" != "0" ]; then
		say "ERROR: Run this script as root."
		exit 1
	fi
	if [ ! -f "$BACKUP" ]; then
		say "ERROR: Backup not found: $BACKUP"
		exit 6
	fi
	cp -p "$BACKUP" "$TARGET"
	restart_luci
	say "RESTORED: Original PassWall2 file restored from backup."
}

case "$ACTION" in
	install|fix)
		install_fix
		;;
	status)
		status
		;;
	uninstall|restore)
		uninstall_fix
		;;
	*)
		say "Usage: $0 [install|status|uninstall]"
		exit 64
		;;
esac
