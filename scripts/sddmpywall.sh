#!/usr/bin/env bash

set -euo pipefail

# ==============================================================================
# CONFIGURATION
# ==============================================================================
THEME_NAME="pywal-sddm"
THEME_DIR="/usr/share/sddm/themes/${THEME_NAME}"
SDDM_CONF_DIR="/etc/sddm.conf.d"
CURRENT_USER="$(whoami)"
USER_HOME="${HOME}"
SETWALL_SCRIPT="${USER_HOME}/.config/scripts/setwall.sh" # Update path if different

echo "==> [SDDM Setup] Starting SDDM + pywal16 integration..."

# 1. Install required packages
echo "==> [SDDM Setup] Installing required system packages..."
sudo pacman -S --needed --noconfirm sddm qt5-quickcontrols qt5-quickcontrols2 qt5-graphicaleffects

# 2. Create SDDM theme directory
echo "==> [SDDM Setup] Creating theme directory at ${THEME_DIR}..."
sudo mkdir -p "${THEME_DIR}"

# 3. Write Main.qml
echo "==> [SDDM Setup] Writing Main.qml..."
sudo bash -c "cat << 'EOF' > '${THEME_DIR}/Main.qml'
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    width: 1920
    height: 1080

    // Default fallback colors in case colors.json isn't accessible
    property color colorBg: \"#1a1b26\"
    property color colorFg: \"#c0caf5\"
    property color colorAccent: \"#7aa2f7\"
    property color colorInputBg: \"#24283b\"

    // Path to pywal16 JSON
    readonly property string pywalJsonPath: \"file://${USER_HOME}/.cache/wal/colors.json\"

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

# 6. Set current permissions on .cache
echo "==> [SDDM Setup] Applying immediate permissions to ~/.cache/wal..."
chmod 755 "${USER_HOME}"
chmod 755 "${USER_HOME}/.cache" || true
if [ -d "${USER_HOME}/.cache/wal" ]; then
    chmod 755 "${USER_HOME}/.cache/wal"
    [ -f "${USER_HOME}/.cache/wal/colors.json" ] && chmod 644 "${USER_HOME}/.cache/wal/colors.json"
fi

# 7. Inject SDDM permissions fix into setwall.sh automatically
if [ -f "${SETWALL_SCRIPT}" ]; then
    echo "==> [SDDM Setup] Patching setwall.sh at ${SETWALL_SCRIPT}..."
    if ! grep -q "chmod 644 ~/.cache/wal/colors.json" "${SETWALL_SCRIPT}"; then
        # Insert chmod commands right after the 'wal -i' command
        sed -i '/wal -i/a \
\
# Maintain permissions for SDDM user access\
chmod 755 ~/.cache 2>/dev/null || true\
chmod 755 ~/.cache/wal 2>/dev/null || true\
chmod 644 ~/.cache/wal/colors.json 2>/dev/null || true' "${SETWALL_SCRIPT}"
        echo "==> [SDDM Setup] Successfully patched setwall.sh!"
    else
        echo "==> [SDDM Setup] setwall.sh already contains SDDM permission logic. Skipping patch."
    fi
else
    echo "==> [SDDM Setup] Warning: setwall.sh not found at ${SETWALL_SCRIPT}. Remember to add permissions logic to setwall manually."
fi

echo "==> [SDDM Setup] SDDM Pywal16 installation finished!"
