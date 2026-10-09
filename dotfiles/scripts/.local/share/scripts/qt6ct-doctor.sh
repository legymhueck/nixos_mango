#!/usr/bin/env bash
# Diagnose, repair, and reproduce the qt6ct configuration warning.
#
# Usage:
#   qt6ct-doctor.sh check
#   qt6ct-doctor.sh fix
#   qt6ct-doctor.sh run [qt6ct arguments...]
#   qt6ct-doctor.sh reproduce [--offscreen] [qt6ct arguments...]

set -u

PROGRAM=${0##*/}
CONFIG_HOME=${XDG_CONFIG_HOME:-"$HOME/.config"}
QT6CT_BIN=${QT6CT_BIN:-qt6ct}
QT6CT_ENV_FILE="$CONFIG_HOME/environment.d/90-qt6ct.conf"
MANGO_CONFIG="$CONFIG_HOME/mango/config.conf"
BASH_RC="$HOME/.bashrc"

info() { printf '[INFO] %s\n' "$*"; }
ok() { printf '[ OK ] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
err() { printf '[FAIL] %s\n' "$*" >&2; }

usage() {
    cat <<EOF
Usage:
  $PROGRAM check                 Diagnose the current installation and configuration
  $PROGRAM fix                   Apply persistent user-session fixes
  $PROGRAM run [args...]         Launch qt6ct with a clean qt6ct environment
  $PROGRAM reproduce [--offscreen] [args...]
                                Launch qt6ct with QT_QPA_PLATFORMTHEME removed
  $PROGRAM all                   Check, fix, and check again

The fix is user-scoped. It does not modify /etc or install packages.
EOF
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

qt_plugin_root() {
    if [[ -n ${QT_PLUGIN_ROOT:-} ]]; then
        printf '%s\n' "$QT_PLUGIN_ROOT"
    elif [[ -e /etc/NIXOS ]] && command_exists qt6ct; then
        local qt6ct_path package_root
        qt6ct_path=$(readlink -f "$(command -v qt6ct)")
        package_root=${qt6ct_path%/bin/*}
        if [[ -d $package_root/lib/qt-6/plugins ]]; then
            printf '%s\n' "$package_root/lib/qt-6/plugins"
        else
            printf '%s\n' "${QT_PLUGIN_PATH:-$package_root/lib/qt-6/plugins}"
        fi
    elif command_exists qmake6; then
        qmake6 -query QT_INSTALL_PLUGINS 2>/dev/null || printf '%s\n' /usr/lib/qt6/plugins
    else
        printf '%s\n' /usr/lib/qt6/plugins
    fi
}

check_packages() {
    local package
    local missing=0

    if [[ -e /etc/NIXOS ]]; then
        if command_exists qt6ct; then
            ok 'qt6ct is available in the NixOS profile'
            return 0
        fi
        err 'qt6ct is missing from the NixOS profile'
        return 1
    fi

    if ! command_exists pacman; then
        info 'pacman is not available; skipping package checks'
        return 0
    fi

    for package in qt6ct qt6-base qt6-svg; do
        if pacman -Q "$package" >/dev/null 2>&1; then
            ok "$package is installed"
        else
            err "$package is missing"
            missing=1
        fi
    done

    if (( missing )); then
        printf '       Install on Arch with: sudo pacman -S --needed qt6ct qt6-base qt6-svg\n' >&2
        return 1
    fi
}

check_plugins() {
    local root
    local plugin
    local failed=0

    root=$(qt_plugin_root)
    info "Qt plugin directory: $root"

    for plugin in \
        "$root/platformthemes/libqt6ct.so" \
        "$root/styles/libqt6ct-style.so"; do
        if [[ -f $plugin ]]; then
            ok "found $plugin"
            if command_exists ldd && ldd "$plugin" 2>/dev/null | grep -q 'not found'; then
                err "unresolved library dependency in $plugin"
                ldd "$plugin" 2>/dev/null | grep 'not found' >&2 || true
                failed=1
            fi
        else
            err "missing $plugin"
            failed=1
        fi
    done

    return "$failed"
}

check_current_environment() {
    local failed=0

    info 'Current shell environment'

    if [[ ${QT_STYLE_OVERRIDE+x} ]]; then
        warn "QT_STYLE_OVERRIDE is present (value: '${QT_STYLE_OVERRIDE}')"
        printf '       qt6ct will display its configuration warning while this variable exists.\n' >&2
    else
        ok 'QT_STYLE_OVERRIDE is not set'
    fi

    case ${QT_QPA_PLATFORMTHEME:-} in
        qt6ct)
            ok 'QT_QPA_PLATFORMTHEME=qt6ct'
            ;;
        qt5ct)
            warn 'QT_QPA_PLATFORMTHEME=qt5ct (accepted for compatibility; qt6ct is preferred)'
            ;;
        '')
            err 'QT_QPA_PLATFORMTHEME is not set'
            failed=1
            ;;
        *)
            err "QT_QPA_PLATFORMTHEME has the wrong value: '${QT_QPA_PLATFORMTHEME}'"
            failed=1
            ;;
    esac

    if [[ -n ${DISPLAY:-}${WAYLAND_DISPLAY:-} ]]; then
        ok 'a graphical display is available'
    else
        warn 'neither DISPLAY nor WAYLAND_DISPLAY is set'
    fi

    return "$failed"
}

check_persistent_configuration() {
    local failed=0

    info 'Persistent configuration'

    if [[ -e /etc/NIXOS ]]; then
        if [[ ${QT_QPA_PLATFORMTHEME:-} == qt6ct ]]; then
            ok 'QT_QPA_PLATFORMTHEME is set by the NixOS/Home Manager configuration'
        else
            err 'QT_QPA_PLATFORMTHEME is not set to qt6ct in the current session'
            failed=1
        fi
    elif [[ -f $QT6CT_ENV_FILE ]] && grep -Eq '^QT_QPA_PLATFORMTHEME=qt6ct$' "$QT6CT_ENV_FILE"; then
        ok "$QT6CT_ENV_FILE"
    else
        err "$QT6CT_ENV_FILE does not set QT_QPA_PLATFORMTHEME=qt6ct"
        failed=1
    fi

    if [[ -f $MANGO_CONFIG ]] && grep -Eq '^[[:space:]]*env[[:space:]]*=[[:space:]]*QT_QPA_PLATFORMTHEME[[:space:]]*,[[:space:]]*qt6ct[[:space:]]*$' "$MANGO_CONFIG"; then
        ok "$MANGO_CONFIG"
    elif [[ -f $MANGO_CONFIG ]]; then
        err "$MANGO_CONFIG does not enable QT_QPA_PLATFORMTHEME=qt6ct"
        failed=1
    else
        warn "$MANGO_CONFIG does not exist; Mango-specific setup was skipped"
    fi

    if [[ -f $BASH_RC ]] && grep -Eq '^[[:space:]]*export[[:space:]]+QT_QPA_PLATFORMTHEME=qt6ct[[:space:]]*$' "$BASH_RC"; then
        ok "$BASH_RC"
    elif [[ -e /etc/NIXOS ]]; then
        ok 'NixOS/Home Manager owns the shell environment'
    else
        warn "$BASH_RC does not export QT_QPA_PLATFORMTHEME=qt6ct"
    fi

    if command_exists mango && [[ -f $MANGO_CONFIG ]]; then
        if mango -p -c "$MANGO_CONFIG" >/dev/null 2>&1; then
            ok 'Mango configuration validates'
        else
            err 'Mango configuration validation failed'
            failed=1
        fi
    fi

    return "$failed"
}

check() {
    local rc=0

    printf '\n== qt6ct diagnosis ==\n\n'
    check_packages || rc=1
    check_plugins || rc=1
    check_current_environment || rc=1
    check_persistent_configuration || rc=1

    if (( rc == 0 )); then
        printf '\nqt6ct configuration looks good.\n'
    else
        printf '\nOne or more qt6ct configuration problems were found.\n' >&2
    fi
    return "$rc"
}

write_environment_file() {
    local file=$1
    local tmp

    mkdir -p "$(dirname "$file")"

    if [[ -e $file || -L $file ]]; then
        tmp=$(mktemp "${file}.qt6ct.XXXXXX") || return 1
        awk '
            BEGIN { found = 0 }
            {
                if ($0 ~ /^[[:space:]]*QT_QPA_PLATFORMTHEME[[:space:]]*=/) {
                    if (!found) {
                        print "QT_QPA_PLATFORMTHEME=qt6ct"
                        found = 1
                    }
                    next
                }
                print
            }
            END {
                if (!found) print "QT_QPA_PLATFORMTHEME=qt6ct"
            }
        ' "$file" > "$tmp" || {
            rm -f "$tmp"
            return 1
        }
        cat "$tmp" > "$file" || {
            rm -f "$tmp"
            return 1
        }
        rm -f "$tmp"
    else
        cat > "$file" <<'EOF'
# Keep Qt 6 applications on the qt6ct platform theme.
QT_QPA_PLATFORMTHEME=qt6ct
EOF
    fi
}

write_mango_config() {
    local file=$1
    local tmp

    if [[ ! -e $file && ! -L $file ]]; then
        warn "$file does not exist; not creating a Mango configuration"
        return 0
    fi

    tmp=$(mktemp "${file}.qt6ct.XXXXXX") || return 1
    awk '
        BEGIN { found = 0 }
        {
            if ($0 ~ /^[[:space:]]*#?[[:space:]]*env[[:space:]]*=[[:space:]]*QT_QPA_PLATFORMTHEME[[:space:]]*,/) {
                if (!found) {
                    print "env = QT_QPA_PLATFORMTHEME,qt6ct"
                    found = 1
                }
                next
            }
            print
        }
        END {
            if (!found) {
                print ""
                print "# Qt 6 theme integration"
                print "env = QT_QPA_PLATFORMTHEME,qt6ct"
            }
        }
    ' "$file" > "$tmp" || {
        rm -f "$tmp"
        return 1
    }
    cat "$tmp" > "$file" || {
        rm -f "$tmp"
        return 1
    }
    rm -f "$tmp"
}

write_bashrc() {
    local file=$1

    mkdir -p "$(dirname "$file")"
    if [[ -f $file ]] && grep -Eq '^[[:space:]]*export[[:space:]]+QT_QPA_PLATFORMTHEME=qt6ct[[:space:]]*$' "$file"; then
        return 0
    fi

    cat >> "$file" <<'EOF'

# Qt 6 theme integration (qt6ct)
export QT_QPA_PLATFORMTHEME=qt6ct
EOF
}

reload_mango() {
    if ! command_exists mmsg; then
        return 0
    fi

    if mmsg dispatch reload_config >/dev/null 2>&1; then
        ok 'Mango configuration reloaded'
    else
        warn 'Could not reload Mango automatically; reload it or log out/in'
    fi
}

update_session_environment() {
    export QT_QPA_PLATFORMTHEME=qt6ct

    if command_exists dbus-update-activation-environment; then
        if dbus-update-activation-environment --systemd QT_QPA_PLATFORMTHEME >/dev/null 2>&1; then
            ok 'D-Bus activation environment updated'
        else
            warn 'Could not update the D-Bus activation environment'
        fi
    fi

    if command_exists systemctl; then
        if systemctl --user import-environment QT_QPA_PLATFORMTHEME >/dev/null 2>&1; then
            ok 'systemd user environment updated'
        else
            warn 'Could not update the systemd user environment'
        fi
    fi
}

fix() {
    local rc=0

    printf '\n== Applying qt6ct fixes ==\n\n'

    if [[ -e /etc/NIXOS ]]; then
        err 'NixOS configuration is declarative; refusing to edit Home Manager-managed files.'
        printf 'Set QT_QPA_PLATFORMTHEME and Mango settings in the flake, then run nixos-rebuild switch.\n' >&2
        return 1
    fi

    if ! check_packages; then
        err 'Install the missing packages first, then run the fix again.'
        return 1
    fi
    if ! check_plugins; then
        err 'The qt6ct plugins are missing or have unresolved dependencies.'
        return 1
    fi

    if write_environment_file "$QT6CT_ENV_FILE"; then
        ok "wrote $QT6CT_ENV_FILE"
    else
        err "could not write $QT6CT_ENV_FILE"
        rc=1
    fi

    if write_mango_config "$MANGO_CONFIG"; then
        ok "updated $MANGO_CONFIG"
    else
        err "could not update $MANGO_CONFIG"
        rc=1
    fi

    if write_bashrc "$BASH_RC"; then
        ok "updated $BASH_RC"
    else
        err "could not update $BASH_RC"
        rc=1
    fi

    # This affects this script and newly launched commands, not the parent shell.
    unset QT_STYLE_OVERRIDE
    update_session_environment
    reload_mango

    printf '\nPersistent fixes were applied.\n'
    printf 'Open a new terminal or log out/in for already-running applications to inherit the change.\n'
    return "$rc"
}

run_clean() {
    unset QT_STYLE_OVERRIDE
    export QT_QPA_PLATFORMTHEME=qt6ct
    exec "$QT6CT_BIN" "$@"
}

reproduce_warning() {
    local offscreen=0

    if [[ ${1:-} == --offscreen ]]; then
        offscreen=1
        shift
    fi

    # qt6ct treats the presence of QT_STYLE_OVERRIDE as a configuration error.
    # Removing QT_QPA_PLATFORMTHEME reproduces the missing-variable warning.
    if (( offscreen )); then
        exec env -u QT_STYLE_OVERRIDE -u QT_QPA_PLATFORMTHEME QT_QPA_PLATFORM=offscreen "$QT6CT_BIN" "$@"
    fi
    exec env -u QT_STYLE_OVERRIDE -u QT_QPA_PLATFORMTHEME "$QT6CT_BIN" "$@"
}

case ${1:-check} in
    check|--check)
        check
        ;;
    fix|--fix)
        fix
        ;;
    run|--run)
        shift
        run_clean "$@"
        ;;
    reproduce|--reproduce)
        shift
        reproduce_warning "$@"
        ;;
    all)
        check || true
        printf '\n'
        fix
        printf '\n'
        check
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
