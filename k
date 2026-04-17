#!/usr/bin/env sh
_=[[
if command -v lua >/dev/null 2>&1; then
  exec lua "$0" "$@"
fi
exec lua5.4 "$0" "$@"
]]
math.randomseed(os.time())

-- Load main config
local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
local IS_WINDOWS = package.config:sub(1, 1) == "\\"
local NULL_DEVICE = IS_WINDOWS and "NUL" or "/dev/null"
local TEMP_ROOT = IS_WINDOWS
    and (os.getenv("TEMP") or os.getenv("TMP") or ".")
    or (os.getenv("TMPDIR") or (HOME .. "/.lunex-tmp"))
local LUNEX_ROOT = HOME .. "/lunex"
local LICENSE_PATH = LUNEX_ROOT .. "/license_key.json"
local LUNEX_TOOL_API = "0324241241241:https://lunex-termux-api.vercel.app:lunextool:R9p4K2m8Qx6Z1v3N"

-- ─────────────────────────────────────────────────────────────────────────────
-- Minimal JSON
-- ─────────────────────────────────────────────────────────────────────────────
local json = {}

local function json_encode(value)
    local value_type = type(value)
    if value_type == "nil" then return "null" end
    if value_type == "boolean" then return value and "true" or "false" end
    if value_type == "number" then
        return value ~= value and "null" or ("%.14g"):format(value)
    end
    if value_type == "string" then
        return '"' .. value
            :gsub('[\\"]', function(char) return "\\" .. char end)
            :gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t") .. '"'
    end
    if value_type == "table" then
        local is_array = #value > 0
        if is_array then
            for index = 1, #value do
                if value[index] == nil then is_array = false; break end
            end
        end
        local parts = {}
        if is_array then
            for _, item in ipairs(value) do parts[#parts + 1] = json_encode(item) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        for key, item in pairs(value) do
            parts[#parts + 1] = json_encode(tostring(key)) .. ":" .. json_encode(item)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "null"
end

local function json_skip(raw, index)
    while index <= #raw do
        local byte = raw:byte(index)
        if byte ~= 32 and byte ~= 9 and byte ~= 10 and byte ~= 13 then break end
        index = index + 1
    end
    return index
end

local json_value

local function json_string(raw, index)
    local parts = {}
    local cursor = index + 1
    while cursor <= #raw do
        local char = raw:sub(cursor, cursor)
        if char == '"' then return table.concat(parts), cursor + 1 end
        if char == "\\" then
            cursor = cursor + 1
            local escaped = raw:sub(cursor, cursor)
            if escaped == '"' then parts[#parts + 1] = '"'
            elseif escaped == "\\" then parts[#parts + 1] = "\\"
            elseif escaped == "n" then parts[#parts + 1] = "\n"
            elseif escaped == "r" then parts[#parts + 1] = "\r"
            elseif escaped == "t" then parts[#parts + 1] = "\t"
            elseif escaped == "u" then
                local code = tonumber(raw:sub(cursor + 1, cursor + 4), 16) or 63
                parts[#parts + 1] = code < 128 and string.char(code) or "?"
                cursor = cursor + 4
            else parts[#parts + 1] = escaped end
        else parts[#parts + 1] = char end
        cursor = cursor + 1
    end
    return table.concat(parts), cursor
end

local function json_array(raw, index)
    local result = {}
    index = json_skip(raw, index)
    if raw:sub(index, index) == "]" then return result, index + 1 end
    while true do
        local item
        item, index = json_value(raw, index)
        result[#result + 1] = item
        index = json_skip(raw, index)
        local char = raw:sub(index, index)
        if char == "]" then return result, index + 1 end
        if char ~= "," then break end
        index = index + 1
    end
    return result, index
end

local function json_object(raw, index)
    local result = {}
    index = json_skip(raw, index)
    if raw:sub(index, index) == "}" then return result, index + 1 end
    while true do
        index = json_skip(raw, index)
        local key
        key, index = json_string(raw, index)
        index = json_skip(raw, index)
        if raw:sub(index, index) ~= ":" then break end
        index = index + 1
        local item
        item, index = json_value(raw, index)
        result[key] = item
        index = json_skip(raw, index)
        local char = raw:sub(index, index)
        if char == "}" then return result, index + 1 end
        if char ~= "," then break end
        index = index + 1
    end
    return result, index
end

json_value = function(raw, index)
    index = json_skip(raw, index)
    local char = raw:sub(index, index)
    if char == '"' then return json_string(raw, index) end
    if char == "[" then return json_array(raw, index + 1) end
    if char == "{" then return json_object(raw, index + 1) end
    if raw:sub(index, index + 3) == "true" then return true, index + 4 end
    if raw:sub(index, index + 4) == "false" then return false, index + 5 end
    if raw:sub(index, index + 3) == "null" then return nil, index + 4 end
    local number = raw:match("^-?%d+%.?%d*[eE]?[+-]?%d*", index)
    if number then return tonumber(number), index + #number end
    return nil, index + 1
end

function json.decode(raw)
    if type(raw) ~= "string" or raw == "" then return nil end
    local ok, parsed = pcall(json_value, raw, 1)
    return ok and parsed or nil
end

json.encode = json_encode

-- ─────────────────────────────────────────────────────────────────────────────
-- Core helpers
-- ─────────────────────────────────────────────────────────────────────────────
local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function shell_first_line(command)
    local handle = io.popen(command .. " 2>" .. NULL_DEVICE)
    if not handle then return "" end
    local output = trim(handle:read("*l") or "")
    handle:close()
    return output
end

local function make_dir(path)
    if IS_WINDOWS then
        os.execute('if not exist "' .. path .. '" mkdir "' .. path .. '" >' .. NULL_DEVICE .. ' 2>&1')
        return
    end
    os.execute("mkdir -p '" .. path:gsub("'", "'\\''") .. "' 2>" .. NULL_DEVICE)
end

local function file_exists(path)
    local handle = io.open(path, "r")
    if handle then handle:close(); return true end
    return false
end

local function temp_path(prefix)
    local sep = IS_WINDOWS and "\\" or "/"
    return TEMP_ROOT .. sep .. prefix .. "_" .. math.random(999999) .. ".tmp"
end

local function terminal_width()
    local width = tonumber(shell_first_line("tput cols"))
    return math.max(60, width or 80)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Color / paint system  (256-color + true-color gradient palette)
-- ─────────────────────────────────────────────────────────────────────────────
local ESC = "\27["
local RST = ESC .. "0m"

local function c256(n)   return ESC .. "38;5;" .. n .. "m" end
local function c256bg(n) return ESC .. "48;5;" .. n .. "m" end
local function rgb(r, g, b) return ESC .. "38;2;" .. r .. ";" .. g .. ";" .. b .. "m" end

local UI = {
    reset   = RST,
    bold    = ESC .. "1m",
    dim     = ESC .. "2m",
    -- Blues / cyans (brand palette)
    brand1  = rgb(80,  160, 255),   -- bright sky blue
    brand2  = rgb(60,  130, 230),
    brand3  = rgb(40,  100, 200),
    brand4  = rgb(30,   80, 175),
    brand5  = rgb(20,   60, 150),
    brand6  = rgb(15,   45, 125),
    -- Accents
    cyan    = rgb(0,   210, 255),
    teal    = rgb(0,   200, 190),
    -- Neutrals
    white   = c256(255),
    silver  = c256(252),
    ash     = c256(245),
    slate   = c256(240),
    dim_fg  = c256(238),
    -- Semantic
    success = rgb(80,  220, 130),
    warning = rgb(255, 200,  60),
    danger  = rgb(255,  90,  90),
    muted   = c256(109),
    -- Box chrome
    border  = rgb(55,  80, 130),
    border2 = rgb(70, 100, 160),
}

local function paint(text, ...)
    return table.concat({ ... }) .. tostring(text or "") .. RST
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Terminal helpers
-- ─────────────────────────────────────────────────────────────────────────────
local function clear_screen()
    if IS_WINDOWS then os.execute("cls >" .. NULL_DEVICE .. " 2>&1") end
    io.write("\027[3J\027[2J\027[H")
    io.flush()
end

local function pad_right(text, width)
    local s = tostring(text or "")
    if #s >= width then return s:sub(1, width) end
    return s .. string.rep(" ", width - #s)
end

local function center(text, width)
    local s = tostring(text or "")
    local pad = math.max(0, width - #s)
    return string.rep(" ", math.floor(pad / 2)) .. s .. string.rep(" ", math.ceil(pad / 2))
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Logo  –  new gradient block-letter banner
-- ─────────────────────────────────────────────────────────────────────────────
-- Each row gets a slightly different blue shade to fake a top→bottom gradient.
local LOGO_ROWS = {
    { color = UI.brand1,
      text = "  ██╗     ██╗   ██╗███╗  ██╗███████╗██╗  ██╗" },
    { color = UI.brand2,
      text = "  ██║     ██║   ██║████╗ ██║██╔════╝╚██╗██╔╝" },
    { color = UI.brand3,
      text = "  ██║     ██║   ██║██╔██╗██║█████╗   ╚███╔╝ " },
    { color = UI.brand4,
      text = "  ██║     ██║   ██║██║╚████║██╔══╝   ██╔██╗ " },
    { color = UI.brand5,
      text = "  ███████╗╚██████╔╝██║ ╚███║███████╗██╔╝╚██╗" },
    { color = UI.brand6,
      text = "  ╚══════╝ ╚═════╝ ╚═╝  ╚══╝╚══════╝╚═╝  ╚═╝" },
}

local TAGLINE = "  Secure · Verified · Authenticated"

-- ─────────────────────────────────────────────────────────────────────────────
-- Box drawing  –  Unicode double-line style
-- ─────────────────────────────────────────────────────────────────────────────
local B = {
    tl = "╔", tr = "╗", bl = "╚", br = "╝",
    h  = "═", v  = "║",
    ml = "╠", mr = "╣", mt = "╦", mb = "╩", mc = "╬",
    -- thin variant for secondary boxes
    tl2 = "┌", tr2 = "┐", bl2 = "└", br2 = "┘",
    h2  = "─", v2  = "│",
    ml2 = "├", mr2 = "┤",
}

-- Draw a double-line box.  inner_w = usable columns inside the border walls.
local function box_top(inner_w, title, bc)
    bc = bc or UI.border
    local title_str = title and (" " .. title .. " ") or ""
    local fill = math.max(0, inner_w - #title_str)
    return paint(B.tl .. title_str .. string.rep(B.h, fill) .. B.tr, bc)
end

local function box_row(inner_w, content, bc)
    bc = bc or UI.border
    return paint(B.v, bc) .. pad_right(content, inner_w) .. paint(B.v, bc)
end

local function box_sep(inner_w, bc)
    bc = bc or UI.border
    return paint(B.ml .. string.rep(B.h, inner_w) .. B.mr, bc)
end

local function box_bot(inner_w, bc)
    bc = bc or UI.border
    return paint(B.bl .. string.rep(B.h, inner_w) .. B.br, bc)
end

-- High-level: render a named box with a list of lines, centered in terminal.
local function draw_box(title, lines, bc, margin)
    margin = margin or 2
    local width = terminal_width()
    local inner = math.max(30, math.min(width - margin * 2 - 2, 74))
    local pad = string.rep(" ", margin)

    io.write(pad .. box_top(inner, title, bc) .. "\n")
    for _, line in ipairs(lines) do
        io.write(pad .. box_row(inner, "  " .. tostring(line or ""), bc) .. "\n")
    end
    io.write(pad .. box_bot(inner, bc) .. "\n")
end

-- Thin-line info strip (no title).
local function draw_note_box(lines, margin)
    margin = margin or 2
    local width = terminal_width()
    local inner = math.max(30, math.min(width - margin * 2 - 2, 74))
    local pad = string.rep(" ", margin)
    local bc = UI.dim_fg

    io.write(pad .. paint(B.tl2 .. string.rep(B.h2, inner) .. B.tr2, bc) .. "\n")
    for _, line in ipairs(lines) do
        io.write(pad .. paint(B.v2, bc) .. pad_right("  " .. tostring(line or ""), inner) .. paint(B.v2, bc) .. "\n")
    end
    io.write(pad .. paint(B.bl2 .. string.rep(B.h2, inner) .. B.br2, bc) .. "\n")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Header
-- ─────────────────────────────────────────────────────────────────────────────
local function draw_header(subtitle)
    local width = terminal_width()
    clear_screen()
    io.write("\n")

    -- Gradient logo
    for _, row in ipairs(LOGO_ROWS) do
        io.write(center(paint(row.text, UI.bold, row.color), width) .. "\n")
    end

    -- Tagline
    io.write(center(paint(TAGLINE, UI.muted), width) .. "\n")
    io.write("\n")

    -- Thin rule under logo
    local rule_w = math.min(width - 4, 62)
    io.write(center(paint(string.rep("─", rule_w), UI.dim_fg), width) .. "\n")

    -- Subtitle badge
    if subtitle and subtitle ~= "" then
        io.write("\n")
        local badge = "  " .. subtitle .. "  "
        io.write(center(paint(badge, UI.cyan, UI.bold), width) .. "\n")
    end

    io.write("\n")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Screen layouts
-- ─────────────────────────────────────────────────────────────────────────────
local ICON = {
    key    = paint("⬡", UI.cyan),
    code   = paint("⬡", UI.teal),
    ok     = paint("✔", UI.success),
    err    = paint("✘", UI.danger),
    warn   = paint("⚠", UI.warning),
    arrow  = paint("›", UI.brand2),
    dot    = paint("•", UI.muted),
    spin   = paint("◈", UI.cyan),
}

local function show_license_screen(message)
    draw_header("License Authentication")

    local is_err = message and message ~= "Waiting for license key."
    local msg_icon = is_err and ICON.warn or ICON.spin
    local msg_color = is_err and UI.warning or UI.silver

    draw_box("  License Key  ", {
        "",
        "  " .. paint("Enter your license key to continue.", UI.white, UI.bold),
        "",
        "  " .. ICON.dot .. "  " .. paint("Use ", UI.muted) ..
            paint("/key_information", UI.cyan, UI.bold) ..
            paint(" in the Discord bot if needed.", UI.muted),
        "  " .. ICON.dot .. "  " .. paint("Paste the license key at the prompt below.", UI.muted),
        "",
        "  " .. msg_icon .. "  " .. paint(message or "Waiting for license key.", msg_color),
        "",
    }, UI.border)

    io.write("\n")

    draw_note_box({
        "  " .. ICON.dot .. "  " .. paint("Saved sessions are verified automatically on startup.", UI.muted),
        "  " .. ICON.dot .. "  " .. paint("If auto-login fails, enter your license key again.", UI.muted),
    })

    io.write("\n")
end

local function show_code_screen(device_label, message)
    draw_header("Device Verification")

    local is_err = message and message ~= "Waiting for Termux code."
    local msg_icon = is_err and ICON.warn or ICON.spin
    local msg_color = is_err and UI.warning or UI.silver

    local truncated = #(device_label or "") > 52
        and (device_label:sub(1, 49) .. "...") or (device_label or "Unknown")

    draw_box("  Termux Code  ", {
        "",
        "  " .. paint("Device  ", UI.muted) ..
            paint(truncated, UI.white, UI.bold),
        "",
        "  " .. ICON.dot .. "  " .. paint("Run ", UI.muted) ..
            paint("/get-termux-code", UI.cyan, UI.bold) ..
            paint(" in the Discord bot.", UI.muted),
        "  " .. ICON.dot .. "  " .. paint("Paste the code sent to your DMs.", UI.muted),
        "",
        "  " .. msg_icon .. "  " .. paint(message or "Waiting for Termux code.", msg_color),
        "",
    }, UI.border)

    io.write("\n")

    draw_note_box({
        "  " .. ICON.dot .. "  " .. paint("The code is tied to this device HWID.", UI.muted),
        "  " .. ICON.dot .. "  " .. paint("If the code expires, request a fresh one.", UI.muted),
    })

    io.write("\n")
end

local function show_status_screen(title, message, tone)
    draw_header(title)

    local bc = tone or UI.border2
    local icon
    if bc == UI.success then icon = ICON.ok
    elseif bc == UI.danger then icon = ICON.err
    else icon = ICON.spin end

    draw_box("  " .. title .. "  ", {
        "",
        "  " .. icon .. "  " .. paint(message or "", UI.white, UI.bold),
        "",
    }, bc)

    io.write("\n")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Shell / crypto helpers
-- ─────────────────────────────────────────────────────────────────────────────
local function shell_escape(value)
    if IS_WINDOWS then return '"' .. tostring(value):gsub('"', '""') .. '"' end
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function sha256(value)
    local path = temp_path("lunex_sha")
    local handle = io.open(path, "wb")
    if not handle then return "" end
    handle:write(value)
    handle:close()

    local digest
    if IS_WINDOWS then
        digest = shell_first_line(
            "powershell -NoProfile -Command \"(Get-FileHash -Algorithm SHA256 " ..
            shell_escape(path) .. ").Hash\"")
    else
        digest = shell_first_line(
            "openssl dgst -sha256 < " .. shell_escape(path) .. " | awk '{print $NF}'")
    end

    os.remove(path)
    return trim(digest):lower()
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Device fingerprint
-- ─────────────────────────────────────────────────────────────────────────────
local function getprop(name)
    return shell_first_line("getprop " .. name)
end

local function device_identity()
    local parts = {}
    local captured = {}
    local prop_names = {
        "ro.serialno", "ro.boot.serialno",
        "ro.product.manufacturer", "ro.product.brand",
        "ro.product.model", "ro.product.device",
        "ro.product.name", "ro.build.fingerprint", "ro.hardware",
    }

    local has_getprop = shell_first_line("command -v getprop") ~= ""
    if has_getprop then
        for _, name in ipairs(prop_names) do
            local value = getprop(name)
            if value ~= "" then
                captured[name] = value
                parts[#parts + 1] = name .. "=" .. value
            end
        end
    end

    for _, id_path in ipairs({ "/etc/machine-id", "/var/lib/dbus/machine-id" }) do
        local h = io.open(id_path, "r")
        if h then
            local mid = trim(h:read("*l") or "")
            h:close()
            if mid ~= "" then parts[#parts + 1] = "machine-id=" .. mid end
        end
    end

    parts[#parts + 1] = "node="   .. shell_first_line("hostname")
    parts[#parts + 1] = "system=" .. shell_first_line("uname -s")
    parts[#parts + 1] = "machine=" .. shell_first_line("uname -m")

    local digest = sha256(table.concat(parts, "\n")):upper()
    local hwid = digest:sub(1, 32)

    local manufacturer = captured["ro.product.manufacturer"]
        or captured["ro.product.brand"]
        or shell_first_line("uname -s")
    local model = captured["ro.product.model"]
        or captured["ro.product.device"]
        or shell_first_line("hostname")
        or "Device"

    local label = ((manufacturer ~= "" and model ~= "") and (manufacturer .. " " .. model))
        or (manufacturer ~= "" and manufacturer)
        or (model ~= "" and model)
        or "Unknown Device"

    return hwid, label:sub(1, 80)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Local license storage
-- ─────────────────────────────────────────────────────────────────────────────
local function load_saved_license()
    make_dir(LUNEX_ROOT)
    if not file_exists(LICENSE_PATH) then return nil end

    local h = io.open(LICENSE_PATH, "r")
    if not h then return nil end

    local raw = h:read("*a")
    h:close()

    local parsed = json.decode(raw)
    if type(parsed) ~= "table" then os.remove(LICENSE_PATH); return nil end

    local lk = trim(parsed.license_key or ""):gsub("%s", ""):upper()
    if lk == "" then os.remove(LICENSE_PATH); return nil end

    return lk
end

local function save_license(license_key, hwid, device_label)
    make_dir(LUNEX_ROOT)
    local h = io.open(LICENSE_PATH, "w")
    if not h then return end
    h:write(json.encode({
        license_key  = trim(license_key):gsub("%s", ""):upper(),
        hwid         = hwid,
        device_label = device_label,
        saved_at     = os.time(),
    }))
    h:close()
end

-- ─────────────────────────────────────────────────────────────────────────────
-- API configuration
-- ─────────────────────────────────────────────────────────────────────────────
local function parse_tool_api(spec)
    local api_key, base_url, username, password =
        spec:match("^([^:]+):(https?://.+):([^:]+):([^:]+)$")
    if not api_key then error("Invalid LunexToolAPI format") end
    return { key = api_key, base = base_url:gsub("/+$", ""), username = username, password = password }
end

local TOOL_API = parse_tool_api(LUNEX_TOOL_API)

local function http_post_json(route, payload)
    make_dir(TEMP_ROOT)

    local response_path = temp_path("lunex_response")
    local error_path    = temp_path("lunex_error")
    local body_path     = temp_path("lunex_body")

    local bh = io.open(body_path, "wb")
    if not bh then return nil, { message = "Server unavailable." } end
    bh:write(json.encode(payload))
    bh:close()

    local curl = IS_WINDOWS and "curl.exe" or "curl"
    local cmd = table.concat({
        curl, "-sS", "--ipv4", "--http1.1",
        "--connect-timeout", "10",
        "--max-time", "20",
        "--retry", "2",
        "--retry-delay", "1",
        "-u", shell_escape(TOOL_API.username .. ":" .. TOOL_API.password),
        "-H", shell_escape("X-Lunex-Tool-Api-Key: " .. TOOL_API.key),
        "-H", shell_escape("Accept: application/json"),
        "-H", shell_escape("Content-Type: application/json"),
        "-o", shell_escape(response_path),
        "-w", shell_escape("%{http_code}"),
        "-X", "POST",
        "--data-binary", shell_escape("@" .. body_path),
        shell_escape(TOOL_API.base .. route),
    }, " ")

    local process = io.popen(cmd .. " 2>" .. shell_escape(error_path))
    local status_code = tonumber((process and process:read("*a") or "0"):match("%d+")) or 0
    if process then process:close() end

    local body = ""
    local rh = io.open(response_path, "r")
    if rh then body = rh:read("*a") or ""; rh:close() end

    os.remove(response_path)
    os.remove(error_path)
    os.remove(body_path)

    if status_code == 0 then return nil, { message = "Server unavailable." } end

    local parsed = json.decode(body)
    if type(parsed) ~= "table" then parsed = {} end

    return status_code, parsed
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Authentication API calls
-- ─────────────────────────────────────────────────────────────────────────────
local function check_license(license_key)
    local status_code, response = http_post_json("/api/termux/license-status", {
        licenseKey = license_key,
    })
    if not status_code then return "server", response.message or "Server unavailable." end
    if status_code == 200 then return "valid", response.message or "Valid." end
    if (response.code or "") == "UNAUTHORIZED" or status_code >= 500 then
        return "server", response.message or "Server unavailable."
    end
    return "invalid", response.message or "Invalid."
end

local function auto_login(license_key, hwid, device_label)
    local status_code, response = http_post_json("/api/termux/auto-login", {
        licenseKey = license_key,
        hwid       = hwid,
        hwidLabel  = device_label,
    })
    if not status_code then return "server", response.message or "Server unavailable." end
    if status_code == 200 then return "valid", response.message or "Success" end
    if (response.code or "") == "AUTO_LOGIN_FAILED" then
        return "failed", response.message or "Auto login failed."
    end
    if (response.code or "") == "UNAUTHORIZED" or status_code >= 500 then
        return "server", response.message or "Server unavailable."
    end
    return "invalid", response.message or "Invalid."
end

local function validate_code(license_key, termux_code, hwid, device_label)
    local status_code, response = http_post_json("/api/termux/validate", {
        licenseKey = license_key,
        termuxCode = termux_code,
        hwid       = hwid,
        hwidLabel  = device_label,
    })
    if not status_code then return "server", response.message or "Server unavailable." end
    if status_code == 200 then return "valid", response.message or "Success" end

    local code = response.code or ""
    if code == "INVALID_LICENSE"    then return "invalid_license",    response.message or "Invalid." end
    if code == "EXPIRED"            then return "expired",            response.message or "Expired." end
    if code == "HWID_LIMIT_REACHED" then return "hwid_limit_reached", response.message or "HWID limit reached." end
    if code == "UNAUTHORIZED" or status_code >= 500 then
        return "server", response.message or "Server unavailable."
    end
    return "invalid", response.message or "Invalid."
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Prompt
-- ─────────────────────────────────────────────────────────────────────────────
local function prompt(label)
    io.write("\n  " .. paint("›", UI.cyan, UI.bold) .. "  " .. paint(label, UI.silver, UI.bold) .. "  ")
    io.flush()
    return trim(io.read("*l") or "")
end

local function print_success()
    show_status_screen("Authenticated", "You are now verified. Welcome to Lunex.", UI.success)
    print("Success")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Main
-- ─────────────────────────────────────────────────────────────────────────────
local function main()
    make_dir(LUNEX_ROOT)
    make_dir(TEMP_ROOT)

    local hwid, device_label = device_identity()
    local saved_license = load_saved_license()
    local license_notice = "Waiting for license key."

    if saved_license then
        show_status_screen("Authentication", "Verifying saved session...", UI.border2)
        local status = auto_login(saved_license, hwid, device_label)
        if status == "valid" then
            print_success()
            return
        end
        if status == "server" then
            show_status_screen("Unavailable", "Could not reach the server. Try again later.", UI.danger)
            return
        end
        os.remove(LICENSE_PATH)
        license_notice = "Saved session expired — enter your license key again."
    end

    while true do
        show_license_screen(license_notice)
        local license_key = prompt("License key"):upper()

        if license_key == "" then
            license_notice = "No license key provided."
        else
            show_status_screen("Authentication", "Verifying license key...", UI.border2)
            local license_status = check_license(license_key)

            if license_status == "server" then
                show_status_screen("Unavailable", "Could not reach the server. Try again later.", UI.danger)
                return
            end

            if license_status ~= "valid" then
                license_notice = "That license key is not valid."
            else
                local code_notice = "Waiting for Termux code."

                while true do
                    show_code_screen(device_label, code_notice)
                    local termux_code = prompt("Termux code"):upper()

                    if termux_code == "" then
                        code_notice = "No Termux code provided."
                    else
                        show_status_screen("Verification", "Checking Termux code...", UI.border2)
                        local validation_status = validate_code(license_key, termux_code, hwid, device_label)

                        if validation_status == "server" then
                            show_status_screen("Unavailable", "Could not reach the server. Try again later.", UI.danger)
                            return
                        end

                        if validation_status == "valid" then
                            save_license(license_key, hwid, device_label)
                            print_success()
                            return
                        end

                        if validation_status == "invalid_license" then
                            os.remove(LICENSE_PATH)
                            license_notice = "License is no longer valid."
                            break
                        end

                        if validation_status == "expired" then
                            code_notice = "Code expired — run /get-termux-code again."
                        elseif validation_status == "hwid_limit_reached" then
                            code_notice = "HWID limit reached for this license."
                        else
                            code_notice = "That Termux code was not accepted."
                        end
                    end
                end
            end
        end
    end
end

local ok, err = pcall(main)
if not ok then
    show_status_screen("Error", trim(err), UI.danger)
    print(trim(err))
    os.exit(1)
end
