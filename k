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

-- Minimal JSON
local json = {}

local function json_encode(value)
    local value_type = type(value)
    if value_type == "nil" then
        return "null"
    end
    if value_type == "boolean" then
        return value and "true" or "false"
    end
    if value_type == "number" then
        return value ~= value and "null" or ("%.14g"):format(value)
    end
    if value_type == "string" then
        return '"' .. value
            :gsub('[\\"]', function(char) return "\\" .. char end)
            :gsub("\n", "\\n")
            :gsub("\r", "\\r")
            :gsub("\t", "\\t") .. '"'
    end
    if value_type == "table" then
        local is_array = #value > 0
        if is_array then
            for index = 1, #value do
                if value[index] == nil then
                    is_array = false
                    break
                end
            end
        end

        local parts = {}
        if is_array then
            for _, item in ipairs(value) do
                parts[#parts + 1] = json_encode(item)
            end
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
        if byte ~= 32 and byte ~= 9 and byte ~= 10 and byte ~= 13 then
            break
        end
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
        if char == '"' then
            return table.concat(parts), cursor + 1
        end
        if char == "\\" then
            cursor = cursor + 1
            local escaped = raw:sub(cursor, cursor)
            if escaped == '"' then
                parts[#parts + 1] = '"'
            elseif escaped == "\\" then
                parts[#parts + 1] = "\\"
            elseif escaped == "n" then
                parts[#parts + 1] = "\n"
            elseif escaped == "r" then
                parts[#parts + 1] = "\r"
            elseif escaped == "t" then
                parts[#parts + 1] = "\t"
            elseif escaped == "u" then
                local code = tonumber(raw:sub(cursor + 1, cursor + 4), 16) or 63
                parts[#parts + 1] = code < 128 and string.char(code) or "?"
                cursor = cursor + 4
            else
                parts[#parts + 1] = escaped
            end
        else
            parts[#parts + 1] = char
        end
        cursor = cursor + 1
    end
    return table.concat(parts), cursor
end

local function json_array(raw, index)
    local result = {}
    index = json_skip(raw, index)
    if raw:sub(index, index) == "]" then
        return result, index + 1
    end
    while true do
        local item
        item, index = json_value(raw, index)
        result[#result + 1] = item
        index = json_skip(raw, index)
        local char = raw:sub(index, index)
        if char == "]" then
            return result, index + 1
        end
        if char ~= "," then
            break
        end
        index = index + 1
    end
    return result, index
end

local function json_object(raw, index)
    local result = {}
    index = json_skip(raw, index)
    if raw:sub(index, index) == "}" then
        return result, index + 1
    end
    while true do
        index = json_skip(raw, index)
        local key
        key, index = json_string(raw, index)
        index = json_skip(raw, index)
        if raw:sub(index, index) ~= ":" then
            break
        end
        index = index + 1
        local item
        item, index = json_value(raw, index)
        result[key] = item
        index = json_skip(raw, index)
        local char = raw:sub(index, index)
        if char == "}" then
            return result, index + 1
        end
        if char ~= "," then
            break
        end
        index = index + 1
    end
    return result, index
end

json_value = function(raw, index)
    index = json_skip(raw, index)
    local char = raw:sub(index, index)
    if char == '"' then
        return json_string(raw, index)
    end
    if char == "[" then
        return json_array(raw, index + 1)
    end
    if char == "{" then
        return json_object(raw, index + 1)
    end
    if raw:sub(index, index + 3) == "true" then
        return true, index + 4
    end
    if raw:sub(index, index + 4) == "false" then
        return false, index + 5
    end
    if raw:sub(index, index + 3) == "null" then
        return nil, index + 4
    end
    local number = raw:match("^-?%d+%.?%d*[eE]?[+-]?%d*", index)
    if number then
        return tonumber(number), index + #number
    end
    return nil, index + 1
end

function json.decode(raw)
    if type(raw) ~= "string" or raw == "" then
        return nil
    end
    local ok, parsed = pcall(json_value, raw, 1)
    return ok and parsed or nil
end

json.encode = json_encode

-- Core helpers
local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$")
end

local function shell_first_line(command)
    local handle = io.popen(command .. " 2>" .. NULL_DEVICE)
    if not handle then
        return ""
    end
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
    if handle then
        handle:close()
        return true
    end
    return false
end

local function temp_path(prefix)
    local separator = IS_WINDOWS and "\\" or "/"
    return TEMP_ROOT .. separator .. prefix .. "_" .. math.random(999999) .. ".tmp"
end

local function terminal_width()
    local width = tonumber(shell_first_line("tput cols"))
    return math.max(60, width or 80)
end

local function clear_screen()
    if IS_WINDOWS then
        os.execute("cls >" .. NULL_DEVICE .. " 2>&1")
    end
    io.write("\027[3J\027[2J\027[H")
    io.flush()
end

local function visible_length(text)
    return #tostring(text or "")
end

local function center_text(text, width)
    local clean = tostring(text or "")
    local padding = math.max(0, width - visible_length(clean))
    local left = math.floor(padding / 2)
    local right = padding - left
    return string.rep(" ", left) .. clean .. string.rep(" ", right)
end

local function truncate_text(text, width)
    local clean = tostring(text or "")
    if width <= 0 then
        return ""
    end
    if #clean <= width then
        return clean
    end
    return clean:sub(1, math.max(1, width - 3)) .. "..."
end

local function pad_right(text, width)
    local clean = tostring(text or "")
    if #clean >= width then
        return truncate_text(clean, width)
    end
    return clean .. string.rep(" ", width - #clean)
end

local LOGO = {
    "██╗     ██╗   ██╗███╗   ██╗███████╗██╗  ██╗",
    "██║     ██║   ██║████╗  ██║██╔════╝╚██╗██╔╝",
    "██║     ██║   ██║██╔██╗ ██║█████╗   ╚███╔╝ ",
    "██║     ██║   ██║██║╚████║██╔══╝   ██╔██╗ ",
    "███████╗╚██████╔╝██║ ╚███║███████╗██╔╝ ╚██╗",
    "╚══════╝ ╚═════╝ ╚═╝  ╚══╝╚══════╝╚═╝   ╚═╝",
}

local function draw_header(subtitle)
    local width = terminal_width()
    clear_screen()
    io.write("\n")
    for _, line in ipairs(LOGO) do
        io.write(center_text(line, width) .. "\n")
    end
    if subtitle and subtitle ~= "" then
        io.write(center_text(subtitle, width) .. "\n")
    end
    io.write(center_text(string.rep("-", math.min(width - 4, 56)), width) .. "\n\n")
end

local function draw_box(lines)
    local width = terminal_width()
    local inner = math.max(24, math.min(width - 6, 72))
    io.write("  +" .. string.rep("-", inner) .. "+\n")
    for _, line in ipairs(lines) do
        io.write("  |" .. pad_right(tostring(line or ""), inner) .. "|\n")
    end
    io.write("  +" .. string.rep("-", inner) .. "+\n")
end

local function show_license_screen(message)
    draw_header("Authentication")
    draw_box({
        "Enter your license key to continue.",
        "",
        "Run /key_information in the Discord bot if you need your key.",
        "Paste the license key below.",
        "",
        message or "Waiting for license key.",
    })
    io.write("\n")
end

local function show_code_screen(device_label, message)
    draw_header("Verification")
    draw_box({
        "Device: " .. truncate_text(device_label, 54),
        "",
        "Run /get-termux-code in the Discord bot.",
        "Paste the code from your DMs below.",
        "",
        message or "Waiting for Termux code.",
    })
    io.write("\n")
end

local function show_status_screen(title, message)
    draw_header(title)
    draw_box({ message or "" })
    io.write("\n")
end

local function shell_escape(value)
    if IS_WINDOWS then
        return '"' .. tostring(value):gsub('"', '""') .. '"'
    end
    return "'" .. tostring(value):gsub("'", "'\\''") .. "'"
end

local function sha256(value)
    local path = temp_path("lunex_sha")
    local handle = io.open(path, "wb")
    if not handle then
        return ""
    end
    handle:write(value)
    handle:close()

    local digest
    if IS_WINDOWS then
        digest = shell_first_line("powershell -NoProfile -Command \"(Get-FileHash -Algorithm SHA256 " .. shell_escape(path) .. ").Hash\"")
    else
        digest = shell_first_line("openssl dgst -sha256 < " .. shell_escape(path) .. " | awk '{print $NF}'")
    end

    os.remove(path)
    return trim(digest):lower()
end

-- Device fingerprint
local function getprop(name)
    return shell_first_line("getprop " .. name)
end

local function device_identity()
    local parts = {}
    local captured = {}
    local prop_names = {
        "ro.serialno",
        "ro.boot.serialno",
        "ro.product.manufacturer",
        "ro.product.brand",
        "ro.product.model",
        "ro.product.device",
        "ro.product.name",
        "ro.build.fingerprint",
        "ro.hardware",
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

    for _, machine_id_path in ipairs({ "/etc/machine-id", "/var/lib/dbus/machine-id" }) do
        local handle = io.open(machine_id_path, "r")
        if handle then
            local machine_id = trim(handle:read("*l") or "")
            handle:close()
            if machine_id ~= "" then
                parts[#parts + 1] = "machine-id=" .. machine_id
            end
        end
    end

    parts[#parts + 1] = "node=" .. shell_first_line("hostname")
    parts[#parts + 1] = "system=" .. shell_first_line("uname -s")
    parts[#parts + 1] = "machine=" .. shell_first_line("uname -m")

    local digest = sha256(table.concat(parts, "\n")):upper()
    local hwid = digest:sub(1, 32)
    local manufacturer = captured["ro.product.manufacturer"] or captured["ro.product.brand"] or shell_first_line("uname -s")
    local model = captured["ro.product.model"] or captured["ro.product.device"] or shell_first_line("hostname") or "Device"
    local label = ((manufacturer ~= "" and model ~= "") and (manufacturer .. " " .. model))
        or (manufacturer ~= "" and manufacturer)
        or (model ~= "" and model)
        or "Unknown Device"

    return hwid, label:sub(1, 80)
end

-- Local license storage
local function load_saved_license()
    make_dir(LUNEX_ROOT)
    if not file_exists(LICENSE_PATH) then
        return nil
    end

    local handle = io.open(LICENSE_PATH, "r")
    if not handle then
        return nil
    end

    local raw = handle:read("*a")
    handle:close()
    local parsed = json.decode(raw)
    if type(parsed) ~= "table" then
        os.remove(LICENSE_PATH)
        return nil
    end

    local license_key = trim(parsed.license_key or ""):gsub("%s", ""):upper()
    if license_key == "" then
        os.remove(LICENSE_PATH)
        return nil
    end

    return license_key
end

local function save_license(license_key, hwid, device_label)
    make_dir(LUNEX_ROOT)
    local handle = io.open(LICENSE_PATH, "w")
    if not handle then
        return
    end

    handle:write(json.encode({
        license_key = trim(license_key):gsub("%s", ""):upper(),
        hwid = hwid,
        device_label = device_label,
        saved_at = os.time(),
    }))
    handle:close()
end

-- API configuration
local function parse_tool_api(spec)
    local api_key, base_url, username, password = spec:match("^([^:]+):(https?://.+):([^:]+):([^:]+)$")
    if not api_key then
        error("Invalid LunexToolAPI format")
    end
    return {
        key = api_key,
        base = base_url:gsub("/+$", ""),
        username = username,
        password = password,
    }
end

local TOOL_API = parse_tool_api(LUNEX_TOOL_API)

local function http_post_json(route, payload)
    make_dir(TEMP_ROOT)

    local response_path = temp_path("lunex_response")
    local error_path = temp_path("lunex_error")
    local body_path = temp_path("lunex_body")

    local body_handle = io.open(body_path, "wb")
    if not body_handle then
        return nil, { message = "Server unavailable." }
    end
    body_handle:write(json.encode(payload))
    body_handle:close()

    local curl_binary = IS_WINDOWS and "curl.exe" or "curl"
    local command_parts = {
        curl_binary,
        "-sS",
        "--ipv4",
        "--http1.1",
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
    }

    local process = io.popen(table.concat(command_parts, " ") .. " 2>" .. shell_escape(error_path))
    local status_code = tonumber((process and process:read("*a") or "0"):match("%d+")) or 0
    if process then
        process:close()
    end

    local response_body = ""
    local response_handle = io.open(response_path, "r")
    if response_handle then
        response_body = response_handle:read("*a") or ""
        response_handle:close()
    end

    os.remove(response_path)
    os.remove(error_path)
    os.remove(body_path)

    if status_code == 0 then
        return nil, { message = "Server unavailable." }
    end

    local parsed = json.decode(response_body)
    if type(parsed) ~= "table" then
        parsed = {}
    end

    return status_code, parsed
end

-- Authentication calls
local function check_license(license_key)
    local status_code, response = http_post_json("/api/termux/license-status", {
        licenseKey = license_key,
    })
    if not status_code then
        return "server", response.message or "Server unavailable."
    end
    if status_code == 200 then
        return "valid", response.message or "Valid."
    end
    if (response.code or "") == "UNAUTHORIZED" or status_code >= 500 then
        return "server", response.message or "Server unavailable."
    end
    return "invalid", response.message or "Invalid."
end

local function auto_login(license_key, hwid, device_label)
    local status_code, response = http_post_json("/api/termux/auto-login", {
        licenseKey = license_key,
        hwid = hwid,
        hwidLabel = device_label,
    })
    if not status_code then
        return "server", response.message or "Server unavailable."
    end
    if status_code == 200 then
        return "valid", response.message or "Success"
    end
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
        hwid = hwid,
        hwidLabel = device_label,
    })
    if not status_code then
        return "server", response.message or "Server unavailable."
    end
    if status_code == 200 then
        return "valid", response.message or "Success"
    end

    local code = response.code or ""
    if code == "INVALID_LICENSE" then
        return "invalid_license", response.message or "Invalid."
    end
    if code == "EXPIRED" then
        return "expired", response.message or "Expired."
    end
    if code == "HWID_LIMIT_REACHED" then
        return "hwid_limit_reached", response.message or "HWID limit reached."
    end
    if code == "UNAUTHORIZED" or status_code >= 500 then
        return "server", response.message or "Server unavailable."
    end
    return "invalid", response.message or "Invalid."
end

-- Prompts
local function prompt(label)
    io.write(label .. ": ")
    io.flush()
    return trim(io.read("*l") or "")
end

local function print_success()
    show_status_screen("Success", "Authentication completed.")
    print("Success")
end

-- Main
local function main()
    make_dir(LUNEX_ROOT)
    make_dir(TEMP_ROOT)

    local hwid, device_label = device_identity()
    local saved_license = load_saved_license()

    if saved_license then
        show_status_screen("Authentication", "Checking saved license...")
        local status = auto_login(saved_license, hwid, device_label)
        if status == "valid" then
            print_success()
            return
        end
        if status == "server" then
            show_status_screen("Authentication", "Server unavailable.")
            print("Server unavailable.")
            return
        end
        os.remove(LICENSE_PATH)
    end

    while true do
        show_license_screen("Waiting for license key.")
        local license_key = prompt("License key"):upper()
        if license_key == "" then
            show_license_screen("Invalid license key.")
            print("Invalid.")
        else
            show_status_screen("Authentication", "Checking license key...")
            local license_status = check_license(license_key)
            if license_status == "server" then
                show_status_screen("Authentication", "Server unavailable.")
                print("Server unavailable.")
                return
            end
            if license_status ~= "valid" then
                show_license_screen("Invalid license key.")
                print("Invalid.")
            else
                while true do
                    show_code_screen(device_label, "Waiting for Termux code.")
                    local termux_code = prompt("Termux code"):upper()
                    if termux_code == "" then
                        show_code_screen(device_label, "Invalid Termux code.")
                        print("Invalid.")
                    else
                        show_status_screen("Verification", "Checking Termux code...")
                        local validation_status = validate_code(license_key, termux_code, hwid, device_label)
                        if validation_status == "server" then
                            show_status_screen("Verification", "Server unavailable.")
                            print("Server unavailable.")
                            return
                        end
                        if validation_status == "valid" then
                            save_license(license_key, hwid, device_label)
                            print_success()
                            return
                        end
                        if validation_status == "invalid_license" then
                            os.remove(LICENSE_PATH)
                            show_license_screen("Invalid license key.")
                            print("Invalid.")
                            break
                        end
                        if validation_status == "expired" then
                            show_code_screen(device_label, "Code expired. Run /get-termux-code again.")
                            print("Expired.")
                        elseif validation_status == "hwid_limit_reached" then
                            show_code_screen(device_label, "HWID limit reached.")
                            print("HWID limit reached.")
                        else
                            show_code_screen(device_label, "Invalid Termux code.")
                            print("Invalid.")
                        end
                    end
                end
            end
        end
    end
end

local ok, err = pcall(main)
if not ok then
    show_status_screen("Error", trim(err))
    print(trim(err))
    os.exit(1)
end
