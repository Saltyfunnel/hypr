local artWidth = 17
local maxHeight = 17
local colorMode = 1     -- 1: "words" (keeps 'Arch' colored consistently); 2: "symbols"
local word = "Arch "

local function exec(cmd)
    local handle = io.popen(cmd)
    if not handle then return "" end
    local result = handle:read("*a") or ""
    handle:close()
    return (result:gsub("^%s*(.-)%s*$", "%1"))
end

local function readfile(path)
    local file = io.open(path, "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    return content
end

local escape = string.char(27) .. "["

local function color(code, text)
    return escape .. code .. "m" .. tostring(text or "") .. escape .. "0m"
end

local function fit(value, width)
    local text = tostring(value or "?")
    if #text > width then
        return text:sub(1, width - 3) .. "..."
    end
    return text .. string.rep(" ", width - #text)
end

local function section(name, code)
    return color(code, name .. " ") .. color("90", string.rep("─", 47 - #name))
end

local function pair(icon1, value1, icon2, value2)
    return color("36", icon1 .. "  ")
        .. color("97", fit(value1, 19))
        .. color("90", "    ")
        .. color("35", icon2 .. "  ")
        .. color("97", fit(value2, 19))
end

local function number(raw)
    return tonumber(tostring(raw or "0"):match("%d+")) or 0
end

local function badge(text, code)
    return color("90", "[ ") .. color(code, text) .. color("90", " ]")
end

local function meter(value, inverse)
    local val = number(value)
    local filled = math.floor(val * 12 / 100 + 0.5)

    if val > 0 and filled == 0 then
        filled = 1
    end
    filled = math.min(filled, 12)

    local code
    if inverse then
        code = val < 20 and "91" or val < 50 and "33" or "32"
    else
        code = val >= 85 and "91" or val >= 65 and "33" or "34"
    end

    return color(code, string.rep("━", filled))
        .. color("90", string.rep("┄", 12 - filled))
        .. color(code, string.format(" %3d%%", val))
end

-- User and Host details
local userName = os.getenv("USER") or exec("whoami")
local hostName = exec("uname -n"):gsub("%s+", "")
if hostName == "" then hostName = exec("cat /etc/hostname"):gsub("%s+", "") end
if hostName == "" then hostName = "arch" end

-- System Data Gathering
local osName = exec("grep '^PRETTY_NAME=' /etc/os-release | cut -d'=' -f2 | tr -d '\"'"):gsub(" Linux", "")
if osName == "" then osName = "Arch Linux" end
local kernelRel = exec("uname -r")
local wmName = os.getenv("XDG_CURRENT_DESKTOP") or os.getenv("DESKTOP_SESSION") or "Hyprland"
local termName = os.getenv("TERM") or "kitty"
local shellName = (os.getenv("SHELL") or "bash"):match("([^/]+)$") or "bash"

local pkgCount = exec("pacman -Qq 2>/dev/null | wc -l")
if pkgCount == "" or pkgCount == "0" then pkgCount = "?" end

local uptimeSec = tonumber((readfile("/proc/uptime") or ""):match("^([%d%.]+)")) or 0
local days = math.floor(uptimeSec / 86400)
local hours = math.floor((uptimeSec % 86400) / 3600)
local mins = math.floor((uptimeSec % 3600) / 60)
local uptimeFormatted = ""
if days > 0 then uptimeFormatted = days .. "d " end
uptimeFormatted = uptimeFormatted .. string.format("%dh %dm", hours, mins)

local hostModel = exec("cat /sys/class/dmi/id/product_name 2>/dev/null"):gsub(" Notebook PC$", "")
if hostModel == "" then hostModel = "Desktop System" end

local cpuModel = exec("grep -m1 'model name' /proc/cpuinfo | cut -d':' -f2 | sed 's/^[ \t]*//'")
cpuModel = cpuModel:gsub("%(R%)", ""):gsub("%(TM%)", ""):gsub("CPU ", "")

-- Clean GPU String
local gpuLine = exec("lspci -nn | grep -iE 'vga|3d' | head -n1")
local gpuModel = ""

for match in gpuLine:gmatch("%[(.-)%]") do
    if not match:find("^%x%x%x%x:%x%x%x%x$") and match ~= "AMD/ATI" and match ~= "NVIDIA Corporation" then
        gpuModel = match
    end
end

if gpuModel == "" then
    gpuModel = gpuLine:match(":%s*(.-)%s*%[") or gpuLine:gsub(".*:%s*", "")
end

gpuModel = gpuModel:gsub("^Advanced Micro Devices, Inc. ", ""):gsub("^NVIDIA Corporation ", "")
if gpuModel == "" then gpuModel = "Graphics Processor" end

-- Memory details
local memTotal, memAvail = 0, 0
local meminfo = readfile("/proc/meminfo") or ""
for line in meminfo:gmatch("[^\r\n]+") do
    local k, v = line:match("^(%w+):%s+(%d+)")
    if k == "MemTotal" then memTotal = tonumber(v) or 0 end
    if k == "MemAvailable" then memAvail = tonumber(v) or 0 end
end
local memUsed = memTotal - memAvail
local memPct = memTotal > 0 and math.floor((memUsed / memTotal) * 100) or 0
local memUsedGiB = string.format("%.1fGiB", memUsed / 1048576)
local memTotalGiB = string.format("%.1fGiB", memTotal / 1048576)

-- Disk details
local diskInfo = exec("df -h / | tail -n 1")
local diskUsed = diskInfo:match("%s+(%S+)%s+%S+%s+%S+%%") or "?"
local diskTotal = diskInfo:match("^%S+%s+(%S+)") or "?"
local diskPct = number(diskInfo:match("(%d+)%%"))

-- Battery details
local batCap = readfile("/sys/class/power_supply/BAT0/capacity") or readfile("/sys/class/power_supply/BAT1/capacity")
batCap = batCap and tonumber(batCap:match("%d+")) or nil

local batStatus = readfile("/sys/class/power_supply/BAT0/status") or readfile("/sys/class/power_supply/BAT1/status") or "Unknown"
batStatus = batStatus:gsub("%s+", "")

local batFull = tonumber(readfile("/sys/class/power_supply/BAT0/charge_full") or readfile("/sys/class/power_supply/BAT0/energy_full") or "0")
local batDesign = tonumber(readfile("/sys/class/power_supply/BAT0/charge_full_design") or readfile("/sys/class/power_supply/BAT0/energy_full_design") or "0")
local batHealth = (batDesign > 0) and math.floor((batFull / batDesign) * 100) or 0

local batCycles = (readfile("/sys/class/power_supply/BAT0/cycle_count") or readfile("/sys/class/power_supply/BAT1/cycle_count") or "?"):gsub("%s+", "")

-- Networking
local ipAddr = exec("ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \\K\\S+'")
if ipAddr == "" then ipAddr = "offline" end

local wifiSSID = exec("iwgetid -r 2>/dev/null || nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d':' -f2")
if wifiSSID == "" then wifiSSID = "offline" end

local panel = {}
local function add(line)
    panel[#panel + 1] = line
end

local stamp = os.date("%a %d %b · %H:%M")
local identity = userName .. "@" .. hostName
local identityPadding = string.rep(" ", math.max(2, 27 - #identity))

add(
    color("94", userName)
        .. color("90", "@")
        .. color("96", hostName)
        .. color("90", identityPadding .. stamp)
)
add("")

add(section("SYSTEM", "34"))
add(pair("", osName .. " " .. exec("uname -m"), "󰣇", kernelRel))
add(pair("", wmName, "", termName .. " / " .. shellName))
add(pair("󰏖", pkgCount .. " packages", "󰅐", uptimeFormatted))

add(section("HARDWARE", "33"))
add(color("33", "󰌢  ") .. color("97", fit(hostModel, 43)))
add(color("33", "  ") .. color("97", fit(cpuModel, 43)))
add(color("35", "󰢮  ") .. color("97", fit(gpuModel, 43)))

add(section("RESOURCES", "36"))
add(
    color("90", "mem  ")
        .. meter(memPct, false)
        .. color("90", "  ")
        .. color("97", memUsedGiB .. " / " .. memTotalGiB)
)
add(
    color("90", "root ")
        .. meter(diskPct, false)
        .. color("90", "  ")
        .. color("97", diskUsed .. " / " .. diskTotal)
)

if batCap then
    local state = "AC"
    local stateColor = "34"
    local norm = batStatus:lower()

    if norm:find("discharg") then
        state = "−"
        stateColor = "33"
    elseif norm:find("charg") then
        state = "+"
        stateColor = "32"
    elseif norm:find("full") then
        state = "✓"
        stateColor = "32"
    end

    local healthColor = batHealth == 0 and "90"
        or batHealth < 60 and "91"
        or batHealth < 80 and "33"
        or "32"
    local healthText = batHealth > 0 and tostring(batHealth) .. "%" or "?"

    add(
        color("90", "bat  ")
            .. meter(batCap, true)
            .. color("90", " ")
            .. badge(state, stateColor)
            .. color("90", " ")
            .. badge("♥ " .. healthText, healthColor)
            .. color("90", " ")
            .. badge("↻ " .. batCycles, "97")
    )
end

add(section("NETWORK", "35"))
add(pair("󰤨", wifiSSID, "󰩟", ipAddr))

local function hexToRgb(hex)
    hex = hex:gsub("#", "")
    return { tonumber(hex:sub(1, 2), 16) or 140, tonumber(hex:sub(3, 4), 16) or 160, tonumber(hex:sub(5, 6), 16) or 160 }
end

local function getWalColor(key, fallback)
    local homePath = os.getenv("HOME") or "/home/gerard"
    if not homePath:match("/$") then homePath = homePath .. "/" end
    local file = io.open(homePath .. ".cache/wal/colors.sh", "r")
    if not file then return fallback end
    for line in file:lines() do
        local k, v = line:match("^([%w_]+)=['\"]?([^'\"\n]+)['\"]?")
        if k == key then
            file:close()
            return v
        end
    end
    file:close()
    return fallback
end

local foreground = hexToRgb(getWalColor("color6", "#8ea4a2"))
local background = hexToRgb(getWalColor("background", "#181616"))
local alphaLevels = { 0.25, 0.4, 0.55, 0.7, 0.85, 1.0 }

local function alphaColor(alpha)
    local channels = {}
    for index = 1, 3 do
        channels[index] = math.floor(
            background[index] + (foreground[index] - background[index]) * alpha + 0.5
        )
    end
    return string.format("38;2;%d;%d;%d", channels[1], channels[2], channels[3])
end

math.randomseed(os.time())

local art = {}
local streamIndex = 0
local currentColor

for row = 1, maxHeight do
    local symbols = {}

    for column = 1, artWidth do
        local wordOffset = streamIndex % #word
        if colorMode == 2 or wordOffset == 0 then
            local alpha = alphaLevels[math.random(#alphaLevels)]
            currentColor = alphaColor(alpha)
        end

        symbols[column] = color(currentColor, word:sub(wordOffset + 1, wordOffset + 1))
        streamIndex = streamIndex + 1
    end

    art[row] = table.concat(symbols)
end

local output = {}
local count = math.max(#art, #panel)
for index = 1, count do
    output[index] = (art[index] or string.rep(" ", artWidth))
        .. "   "
        .. (panel[index] or "")
end

print(table.concat(output, string.char(10)))
