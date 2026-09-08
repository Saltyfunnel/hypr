#!/usr/bin/env bash

set -euo pipefail

# ==============================================================================
# CONFIGURATION
# ==============================================================================
THEME_NAME="pywal-sddm"
THEME_DIR="/usr/share/sddm/themes/${THEME_NAME}"
SDDM_CONF_DIR="/etc/sddm.conf.d"
CURRENT_USER="$(logname 2>/dev/null || echo "${SUDO_USER:-$USER}")"
USER_HOME="$(getent passwd "${CURRENT_USER}" | cut -d: -f6)"
SETWALL_SCRIPT="${USER_HOME}/.config/scripts/setwall.sh"
GLOBAL_WAL_CACHE="/var/cache/wal"

echo "==> [SDDM Setup] Starting SDDM + pywal16 integration for user: ${CURRENT_USER}..."

# 1. Install required packages
echo "==> [SDDM Setup] Installing required system packages..."
sudo pacman -S --needed --noconfirm sddm qt5-quickcontrols qt5-quickcontrols2 qt5-graphicaleffects

# 2. Create SDDM theme and global cache directories
echo "==> [SDDM Setup] Creating directories..."
sudo mkdir -p "${THEME_DIR}"
sudo mkdir -p "${GLOBAL_WAL_CACHE}"
sudo chmod 755 "${GLOBAL_WAL_CACHE}"

# Sync current colors to global cache if available
if [ -f "${USER_HOME}/.cache/wal/colors.json" ]; then
    sudo cp "${USER_HOME}/.cache/wal/colors.json" "${GLOBAL_WAL_CACHE}/colors.json"
    sudo chmod 644 "${GLOBAL_WAL_CACHE}/colors.json"
fi

# 3. Write Main.qml using /var/cache/wal/colors.json
echo "==> [SDDM Setup] Writing Main.qml..."
sudo bash -c "cat << 'EOF' > '${THEME_DIR}/Main.qml'
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    width: 1920
    height: 1080

    // Default fallback colors
    property color colorBg: \"#1a1b26\"
    property color colorFg: \"#c0caf5\"
    property color colorAccent: \"#7aa2f7\"
    property color colorInputBg: \"#24283b\"

    // Global location accessible by sddm user
    readonly property string pywalJsonPath: \"file:///var/cache/wal/colors.json\"

    function loadWalColors() {
        var xhr = new XMLHttpRequest();
        xhr.open(\"GET\", root.pywalJsonPath, true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200 || xhr.status === 0) {
                    try {
                        var colors = JSON.parse(xhr.responseText);
                        if (colors.special) {
                            root.colorBg = colors.special.background || root.colorBg;
                            root.colorFg = colors.special.foreground || root.colorFg;
                        }
                        if (colors.colors) {
                            root.colorAccent = colors.colors.color4 || root.colorAccent;
                            root.colorInputBg = colors.colors.color0 || root.colorInputBg;
                        }
                    } catch (e) {
                        console.log(\"Failed to parse pywal JSON, using fallback colors.\");
                    }
                }
            }
        };
        xhr.send();
    }

    Component.onCompleted: {
        loadWalColors();
    }

    color: root.colorBg

    // Center Card Container
    Rectangle {
        anchors.centerIn: parent
        width: 360
        height: 380
        radius: 16
        color: Qt.rgba(root.colorInputBg.r, root.colorInputBg.g, root.colorInputBg.b, 0.6)
        border.color: root.colorAccent
        border.width: 1

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 20
            width: parent.width - 60

            // User Avatar / Icon Indicator
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 72
                height: 72
                radius: 36
                color: root.colorAccent

                Text {
                    anchors.centerIn: parent
                    text: usernameInput.text.length > 0 ? usernameInput.text.substring(0, 1).toUpperCase() : \"?\"
                    color: root.colorBg
                    font.pixelSize: 32
                    font.bold: true
                    font.family: \"Hack Nerd Font\"
                }
            }

            // Username Input Field
            TextField {
                id: usernameInput
                Layout.fillWidth: true
                placeholderText: \"Username\"
                text: userModel.lastUser
                font.family: \"Hack Nerd Font\"
                font.pixelSize: 14
                color: root.colorFg
                background: Rectangle {
                    color: Qt.darker(root.colorInputBg, 1.2)
                    radius: 8
                    border.color: usernameInput.activeFocus ? root.colorAccent : \"transparent\"
                    border.width: 1
                }
            }

            // Password Input Field
            TextField {
                id: passwordInput
                Layout.fillWidth: true
                placeholderText: \"Password\"
                echoMode: TextInput.Password
                font.family: \"Hack Nerd Font\"
                font.pixelSize: 14
                color: root.colorFg
                focus: true
                background: Rectangle {
                    color: Qt.darker(root.colorInputBg, 1.2)
                    radius: 8
                    border.color: passwordInput.activeFocus ? root.colorAccent : \"transparent\"
                    border.width: 1
                }
                onAccepted: sddm.login(usernameInput.text, passwordInput.text, sessionSelect.currentIndex)
            }

            // Session Selector
            ComboBox {
                id: sessionSelect
                Layout.fillWidth: true
                model: sessionModel
                textRole: \"name\"
                currentIndex: sessionModel.lastIndex
                font.family: \"Hack Nerd Font\"
                font.pixelSize: 12
            }

            // Login Button
            Button {
                Layout.fillWidth: true
                height: 40
                onClicked: sddm.login(usernameInput.text, passwordInput.text, sessionSelect.currentIndex)

                contentItem: Text {
                    text: \"LOGIN\"
                    color: root.colorBg
                    font.bold: true
                    font.family: \"Hack Nerd Font\"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    color: parent.down ? Qt.darker(root.colorAccent, 1.2) : root.colorAccent
                    radius: 8
                }
            }
        }
    }
}
EOF"

# 4. Write metadata.desktop
echo "==> [SDDM Setup] Writing metadata.desktop..."
sudo bash -c "cat << 'EOF' > '${THEME_DIR}/metadata.desktop'
[SddmGreeterTheme]
Name=${THEME_NAME}
Description=A sleek minimalist theme that imports pywal16 colors dynamically
Author=Custom
Type=sddm-theme
ConfigFile=theme.conf
MainScript=Main.qml
EOF"

# 5. Enable SDDM Theme
echo "==> [SDDM Setup] Configuring SDDM to use ${THEME_NAME}..."
sudo mkdir -p "${SDDM_CONF_DIR}"
sudo bash -c "cat << 'EOF' > '${SDDM_CONF_DIR}/theme.conf'
[Theme]
Current=${THEME_NAME}
EOF"

# 6. Inject global cache sync into setwall.sh
if [ -f "${SETWALL_SCRIPT}" ]; then
    echo "==> [SDDM Setup] Patching setwall.sh at ${SETWALL_SCRIPT}..."
    if ! grep -q "/var/cache/wal/colors.json" "${SETWALL_SCRIPT}"; then
        sed -i '/wal -i/a \
\
# Sync colors to global cache for SDDM access\
sudo mkdir -p /var/cache/wal 2>/dev/null || true\
sudo cp ~/.cache/wal/colors.json /var/cache/wal/colors.json 2>/dev/null || true\
sudo chmod 644 /var/cache/wal/colors.json 2>/dev/null || true' "${SETWALL_SCRIPT}"
        echo "==> [SDDM Setup] Successfully patched setwall.sh!"
    else
        echo "==> [SDDM Setup] setwall.sh already contains global sync logic. Skipping patch."
    fi
else
    echo "==> [SDDM Setup] Warning: setwall.sh not found at ${SETWALL_SCRIPT}."
fi

echo "==> [SDDM Setup] SDDM Pywal16 installation finished!"
