local artWidth = 12
local maxHeight = 17
local colorMode = 2     -- 1: "words"; 2: "symbols"
local word = "!@#$%^&*()>~?<|'"

return function(user)
    -- Previous Fastfetch modules populate these globals before this renderer runs.
    local sys = SYS or {}
    local kernel = KERNEL or {}
    local wm = WM or {}
    local term = TERM or {}
    local host = HOST or {}
    local cpu = CPU or {}
    local gpu = GPU or {}
    local display = DISPLAY or {}
    local mem = MEM or {}
    local root = ROOT or {}
    local bat = BAT or {}
    local health = HEALTH or "?"
    local up = UP or {}
    local pkg = PKG or {}
    local ip = IP or {}
    local wifi = WIFI or {}
    local date = DATE or {}

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

    local function meter(raw, inverse)
        local value = number(raw)
        local filled = math.floor(value * 12 / 100 + 0.5)

        if value > 0 and filled == 0 then
            filled = 1
        end
        filled = math.min(filled, 12)

        local code
        if inverse then
            code = value < 20 and "91" or value < 50 and "33" or "32"
        else
            code = value >= 85 and "91" or value >= 65 and "33" or "34"
        end

        return color(code, string.rep("━", filled))
            .. color("90", string.rep("┄", 12 - filled))
            .. color(code, string.format(" %3d%%", value))
    end

    local panel = {}
    local function add(line)
        panel[#panel + 1] = line
    end

    local shell = tostring(user.userShell or "shell"):match("([^/]+)$") or "shell"
    local stamp = string.format(
        "%s %s %s · %s:%s",
        date.weekdayShort or "",
        date.dayPretty or "",
        date.monthNameShort or "",
        date.hourPretty or "",
        date.minutePretty or ""
    )
    local identity = tostring(user.userName or "user") .. "@" .. tostring(user.hostName or "host")
    local identityPadding = string.rep(" ", math.max(2, 27 - #identity))

    add(
        color("94", user.userName or "user")
            .. color("90", "@")
            .. color("96", user.hostName or "host")
            .. color("90", identityPadding .. stamp)
    )
    add("")

    add(section("SYSTEM", "34"))
    add(pair("", (sys.prettyName or "Linux") .. " " .. (sys.arch or ""), "󰣇", kernel.release or "?"))
    add(pair("", (wm.prettyName or "?") .. " " .. (wm.version or ""), "", (term.prettyName or "?") .. " / " .. shell))
    add(pair("󰏖", tostring(pkg.all or "?") .. " packages", "󰅐", up.formatted or "?"))

    add(section("HARDWARE", "33"))

    local model = tostring(host.name or "?"):gsub(" Notebook PC$", "")
    add(color("33", "󰌢  ") .. color("97", fit(model, 43)))
    add(color("33", "  ") .. color("97", fit(cpu.name or "?", 43)))

    local gpuName = tostring(gpu.name or "?")
    gpuName = gpuName:match("/ (.+)") or gpuName
    gpuName = gpuName:gsub(" Series$", "")
    add(color("35", "󰢮  ") .. color("97", fit((gpu.vendor or "") .. " " .. gpuName, 43)))

    local displayText = tostring(display.width or "?")
        .. "x"
        .. tostring(display.height or "?")
        .. "  "
        .. tostring(display.inch or "?")
        .. '"'
    add(color("34", "󰍹  ") .. color("97", displayText))

    add(section("RESOURCES", "36"))
    add(
        color("90", "mem  ")
            .. meter(mem.percentage, false)
            .. color("90", "  ")
            .. color("97", tostring(mem.used or "?") .. " / " .. tostring(mem.total or "?"))
    )
    add(
        color("90", "root ")
            .. meter(root.sizePercentage, false)
            .. color("90", "  ")
            .. color("97", tostring(root.sizeUsed or "?") .. " / " .. tostring(root.sizeTotal or "?"))
    )

    if bat.capacity then
        local normalized = tostring(bat.status or ""):lower()
        local state = "AC"
        local stateColor = "34"

        if normalized:find("discharg", 1, true) then
            state = "−"
            stateColor = "33"
        elseif normalized:find("not charging", 1, true) then
            state = "AC"
        elseif normalized:find("charg", 1, true) then
            state = "+"
            stateColor = "32"
        elseif normalized:find("full", 1, true) then
            state = "✓"
            stateColor = "32"
        end

        local healthValue = number(health)
        local healthColor = healthValue == 0 and "90"
            or healthValue < 60 and "91"
            or healthValue < 80 and "33"
            or "32"
        local healthText = healthValue > 0 and tostring(healthValue) .. "%" or "?"

        add(
            color("90", "bat  ")
                .. meter(bat.capacity, true)
                .. color("90", " ")
                .. badge(state, stateColor)
                .. color("90", " ")
                .. badge("♥ " .. healthText, healthColor)
                .. color("90", " ")
                .. badge("↻ " .. tostring(bat.cycleCount or "?"), "97")
        )
    end

    add(section("NETWORK", "35"))
    add(pair("󰤨", wifi.ssid or "offline", "󰩟", ip.ipv4 or "offline"))

    if colorMode ~= 2 then -- If mode is not in [1, 2]
        colorMode = 1
    end

    -- ANSI text has no alpha channel, so opacity is simulated by blending
    -- the RESOURCES color with the Kitty background at several levels.
    local foreground = { 142, 164, 162 } -- #8ea4a2
    local background = { 24, 22, 22 }    -- #181616
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

    local seed = (tonumber(date.second) or 0) * 100000
        + (tonumber(up.milliseconds) or 0) * 100
        + (tonumber(user.pid) or 0)
    math.randomseed(seed)

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

    return table.concat(output, string.char(10))
end
