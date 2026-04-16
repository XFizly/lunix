#!/usr/bin/env sh
_=[[
if command -v lua >/dev/null 2>&1; then
  exec lua "$0" "$@"
fi
exec lua5.4 "$0" "$@"
]]
math.randomseed(os.time())

local json = {}

local function je(v)
    local t = type(v)
    if t == "nil" then return "null" end
    if t == "boolean" then return v and "true" or "false" end
    if t == "number" then return v ~= v and "null" or ("%.14g"):format(v) end
    if t == "string" then
        return '"' .. v:gsub('[\\"]', function(c) return '\\' .. c end)
            :gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t') .. '"'
    end
    if t == "table" then
        local is_arr = #v > 0
        if is_arr then
            for i = 1, #v do
                if v[i] == nil then
                    is_arr = false
                    break
                end
            end
        end
        local p = {}
        if is_arr then
            for _, x in ipairs(v) do p[#p + 1] = je(x) end
            return "[" .. table.concat(p, ",") .. "]"
        end
        for k, x in pairs(v) do p[#p + 1] = je(tostring(k)) .. ":" .. je(x) end
        return "{" .. table.concat(p, ",") .. "}"
    end
    return "null"
end

json.encode = je

local function jskip(s, i)
    while i <= #s do
        local b = s:byte(i)
        if b ~= 32 and b ~= 9 and b ~= 10 and b ~= 13 then break end
        i = i + 1
    end
    return i
end

local jval

local function jstr(s, i)
    local b, j = {}, i + 1
    while j <= #s do
        local c = s:sub(j, j)
        if c == '"' then return table.concat(b), j + 1 end
        if c == '\\' then
            j = j + 1
            local e = s:sub(j, j)
            if e == '"' then b[#b + 1] = '"'
            elseif e == '\\' then b[#b + 1] = '\\'
            elseif e == 'n' then b[#b + 1] = '\n'
            elseif e == 'r' then b[#b + 1] = '\r'
            elseif e == 't' then b[#b + 1] = '\t'
            elseif e == 'u' then
                local n = tonumber(s:sub(j + 1, j + 4), 16) or 63
                b[#b + 1] = n < 128 and string.char(n) or '?'
                j = j + 4
            else
                b[#b + 1] = e
            end
        else
            b[#b + 1] = c
        end
        j = j + 1
    end
    return table.concat(b), j
end

local function jarr(s, i)
    local a = {}
    i = jskip(s, i)
    if s:sub(i, i) == ']' then return a, i + 1 end
    while true do
        local v
        v, i = jval(s, i)
        a[#a + 1] = v
        i = jskip(s, i)
        local c = s:sub(i, i)
        if c == ']' then return a, i + 1 end
        if c ~= ',' then break end
        i = i + 1
    end
    return a, i
end

local function jobj(s, i)
    local o = {}
    i = jskip(s, i)
    if s:sub(i, i) == '}' then return o, i + 1 end
    while true do
        i = jskip(s, i)
        local k
        k, i = jstr(s, i)
        i = jskip(s, i)
        if s:sub(i, i) ~= ':' then break end
        i = i + 1
        local v
        v, i = jval(s, i)
        o[k] = v
        i = jskip(s, i)
        local c = s:sub(i, i)
        if c == '}' then return o, i + 1 end
        if c ~= ',' then break end
        i = i + 1
    end
    return o, i
end

jval = function(s, i)
    i = jskip(s, i)
    local c = s:sub(i, i)
    if c == '"' then return jstr(s, i) end
    if c == '[' then return jarr(s, i + 1) end
    if c == '{' then return jobj(s, i + 1) end
    if s:sub(i, i + 3) == 'true' then return true, i + 4 end
    if s:sub(i, i + 4) == 'false' then return false, i + 5 end
    if s:sub(i, i + 3) == 'null' then return nil, i + 4 end
    local n = s:match("^-?%d+%.?%d*[eE]?[+-]?%d*", i)
    if n then return tonumber(n), i + #n end
    return nil, i + 1
end

function json.decode(s)
    if type(s) ~= "string" or s == "" then return nil end
    local ok, v = pcall(jval, s, 1)
    return ok and v or nil
end

local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
local SDIR = (arg[0] or ""):match("^(.+)/[^/]*$") or "."
local LROOT = HOME .. "/lunex"
local LIC_PATH = LROOT .. "/license_key.json"
local DL_ROOT = SDIR .. "/downloads"
local IS_WINDOWS = package.config:sub(1, 1) == "\\"
local NULL_DEVICE = IS_WINDOWS and "NUL" or "/dev/null"
local TEMP_ROOT = IS_WINDOWS
    and (os.getenv("TEMP") or os.getenv("TMP") or ".")
    or (os.getenv("TMPDIR") or (HOME .. "/.lunex-tmp"))
local GF_CODE = "ePdGcF"
local GF_PASS = "A7K9-X2QM-4RTP-Z8LJ"
local GF_PAGE = "https://gofile.io/d/" .. GF_CODE
local GF_API = "https://api.gofile.io"
local GF_UA = "Mozilla/5.0 (Linux; Android 14; Termux)"
local GF_LANG = "en-US"
local GF_SFXWT = "5d4f7g8sd45fsd"
local LunexToolAPI = "0324241241241:https://lunex-termux-api.vercel.app:lunextool:R9p4K2m8Qx6Z1v3N"

local ACTS = {
    "Refreshing secure channels...",
    "Reconciling runtime state...",
    "Synchronising request lanes...",
    "Applying environment checks...",
    "Stabilising package context...",
    "Sealing temporary workspace...",
    "Finalising hidden handoff...",
    "Verifying response envelope...",
}

local BANNER = "\n"
    .. "██╗░░░░░██╗░░░██╗███╗░░██╗███████╗██╗░░██╗\n"
    .. "██║░░░░░██║░░░██║████╗░██║██╔════╝╚██╗██╔╝\n"
    .. "██║░░░░░██║░░░██║██╔██╗██║█████╗░░░╚███╔╝░\n"
    .. "██║░░░░░██║░░░██║██║╚████║██╔══╝░░░██╔██╗░\n"
    .. "███████╗╚██████╔╝██║░╚███║███████╗██╔╝╚██╗\n"
    .. "╚══════╝░╚═════╝░╚═╝░░╚══╝╚══════╝╚═╝░░╚═╝\n"

local P = {
    reset = "\027[0m",
    text = "\027[38;2;228;235;244m",
    muted = "\027[38;2;127;146;170m",
    border = "\027[38;2;45;61;84m",
    accent = "\027[38;2;104;150;223m",
    success = "\027[38;2;114;240;172m",
    warning = "\027[38;2;255;211;102m",
    danger = "\027[38;2;255;125;125m",
    active = "\027[48;2;16;28;46m",
    button = "\027[48;2;11;20;34m",
    bact = "\027[48;2;24;40;66m",
    bold = "\027[1m",
}

local TONES = { success = P.success, warning = P.warning, danger = P.danger, accent = P.accent }

local function parse_tool_api(spec)
    local api_key, base_url, username, password = spec:match("^([^:]+):(https?://.+):([^:]+):([^:]+)$")

    if not api_key or not base_url or not username or not password then
        error("Invalid LunexToolAPI format")
    end

    return {
        key = api_key,
        base = (base_url:gsub("/+$", "")),
        username = username,
        password = password,
    }
end

local TOOL_API = parse_tool_api(LunexToolAPI)
local DEBUG_LOGS = {}
local MAX_DEBUG_LOGS = 48

local function col(s, ...) return table.concat({ ... }) .. s .. P.reset end
local function clear() io.write("\027[2J\027[H"); io.flush() end

local function shl(cmd)
    local f = io.popen(cmd .. " 2>" .. NULL_DEVICE)
    if not f then return "" end
    local r = (f:read("*l") or ""):match("^%s*(.-)%s*$")
    f:close()
    return r
end

local function tw()
    local n = tonumber(shl("tput cols"))
    return math.max(72, n or 96)
end

local function strip(s) return (s:gsub("\027%[[%d;]*m", "")) end
local function vlen(s) return #strip(s) end

local function trunc(s, w)
    if w <= 0 then return "" end
    if #s <= w then return s end
    return s:sub(1, w - 3) .. "..."
end

local function short(s, w)
    s = tostring(s or ""):gsub("[%c]+", " ")
    if #s <= w then return s end
    return s:sub(1, math.max(1, w - 3)) .. "..."
end

local function push_debug(tag, msg)
    local stamp = os.date("%H:%M:%S")
    DEBUG_LOGS[#DEBUG_LOGS + 1] = ("[%s] %s %s"):format(stamp, tag, short(msg, 180))
    while #DEBUG_LOGS > MAX_DEBUG_LOGS do
        table.remove(DEBUG_LOGS, 1)
    end
end

local function hsize(n)
    local u = { "B", "KB", "MB", "GB" }
    local v = n
    local i = 1
    while v >= 1024 and i < #u do
        v = v / 1024
        i = i + 1
    end
    if i == 1 then return math.floor(v) .. " B" end
    return ("%.1f %s"):format(v, u[i])
end

local function sleep(s)
    if IS_WINDOWS then
        os.execute('powershell -NoProfile -Command "Start-Sleep -Milliseconds ' .. math.max(1, math.floor(s * 1000)) .. '" >' .. NULL_DEVICE .. " 2>&1")
        return
    end
    os.execute("sleep " .. s)
end

local function esc(s)
    if IS_WINDOWS then
        return '"' .. tostring(s):gsub('"', '""') .. '"'
    end
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end
local function safename(s) return (s:gsub('[\\/:*?"<>|]', "_")) end
local function mkdirp(p)
    if IS_WINDOWS then
        os.execute('if not exist ' .. esc(p) .. " mkdir " .. esc(p) .. " >" .. NULL_DEVICE .. " 2>&1")
        return
    end
    os.execute("mkdir -p " .. esc(p) .. " 2>" .. NULL_DEVICE)
end

local function fexists(p)
    local f = io.open(p, "r")
    if f then f:close(); return true end
    return false
end

local function banner() print(col(BANNER, P.accent, P.bold)) end

local function temp_path(prefix)
    local sep = IS_WINDOWS and "\\" or "/"
    return TEMP_ROOT .. sep .. prefix .. "_" .. math.random(999999) .. ".tmp"
end

local function box(title, lines)
    local w = tw() - 4
    local hdr = " " .. title .. " "
    print(col("┌" .. hdr .. string.rep("─", math.max(0, w - #hdr)) .. "┐", P.border))
    for _, ln in ipairs(lines) do
        local vl = vlen(ln)
        if vl > w then
            ln = trunc(strip(ln), w)
            vl = #ln
        end
        io.write(col("│", P.border) .. ln .. string.rep(" ", math.max(0, w - vl)) .. col("│", P.border) .. "\n")
    end
    print(col("└" .. string.rep("─", w) .. "┘", P.border))
end

local function status_box(title, msg, tone)
    clear()
    banner()
    box(title, { col(" " .. msg, TONES[tone] or P.muted) })
end

local function show_activity()
    clear()
    banner()
    local lines = { col(" Recent activity", P.accent, P.bold), "" }
    local start_index = math.max(1, #DEBUG_LOGS - 21)
    for i = start_index, #DEBUG_LOGS do
        lines[#lines + 1] = col(" " .. DEBUG_LOGS[i], P.muted)
    end
    if #DEBUG_LOGS == 0 then
        lines[#lines + 1] = col(" No activity recorded.", P.muted)
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = col(" Press Enter to go back.", P.muted)
    box(" Activity ", lines)
    io.read("*l")
end

local function show_error_with_activity(title, msg)
    while true do
        clear()
        banner()
        local lines = {
            col(" " .. msg, P.danger),
            "",
        }
        if #DEBUG_LOGS > 0 then
            lines[#lines + 1] = col(" D Activity   Enter Back", P.muted)
        else
            lines[#lines + 1] = col(" Press Enter to go back.", P.muted)
        end
        box(" " .. title .. " ", lines)
        local value = (io.read("*l") or ""):lower():match("^%s*(.-)%s*$")
        if value == "d" and #DEBUG_LOGS > 0 then
            show_activity()
        else
            return
        end
    end
end

local function prog(title, sub, det, tone)
    clear()
    banner()
    box(" Installer ", {
        col(" " .. title, TONES[tone] or P.accent, P.bold),
        "",
        col(" " .. sub, P.text),
        col(" " .. det, P.muted),
    })
end

local function mprog(pos, tot, seed)
    prog("Processing request", "Selection " .. pos .. "/" .. tot, " " .. ACTS[(seed or 0) % #ACTS + 1])
end

local function mdelay(pos, tot, seed, steps, delay)
    steps = steps or 2
    delay = delay or 0.35
    for i = 0, steps - 1 do
        mprog(pos, tot, seed + i)
        sleep(delay)
    end
end

local function sha256(s)
    local tmp = temp_path("lnx")
    local f = io.open(tmp, "wb")
    if not f then return "" end
    f:write(s)
    f:close()
    local h
    if IS_WINDOWS then
        h = shl("powershell -NoProfile -Command \"(Get-FileHash -Algorithm SHA256 '" .. tmp:gsub("'", "''") .. "').Hash\"")
    else
        h = shl("openssl dgst -sha256 < " .. esc(tmp) .. " | awk '{print $NF}'")
    end
    os.remove(tmp)
    return h:lower()
end

local HAS_GP = shl("command -v getprop") ~= ""

local function gp(n)
    if not HAS_GP then return "" end
    return shl("getprop " .. n)
end

local function device_id()
    local props = {
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
    local vals, got = {}, {}
    for _, n in ipairs(props) do
        local v = gp(n)
        if v ~= "" then
            got[n] = v
            vals[#vals + 1] = n .. "=" .. v
        end
    end
    for _, mp in ipairs({ "/etc/machine-id", "/var/lib/dbus/machine-id" }) do
        local f = io.open(mp, "r")
        if f then
            local mid = (f:read("*l") or ""):match("^%s*(.-)%s*$")
            f:close()
            if mid ~= "" then vals[#vals + 1] = "machine-id=" .. mid end
        end
    end
    vals[#vals + 1] = "node=" .. shl("hostname")
    vals[#vals + 1] = "system=" .. shl("uname -s")
    vals[#vals + 1] = "machine=" .. shl("uname -m")
    local dig = sha256(table.concat(vals, "\n")):upper()
    local hwid = dig:sub(1, 32)
    local mfr = got["ro.product.manufacturer"] or got["ro.product.brand"] or shl("uname -s")
    local mdl = got["ro.product.model"] or got["ro.product.device"] or shl("hostname") or "Device"
    local lbl = ((mfr ~= "" and mdl ~= "") and (mfr .. " " .. mdl)) or (mfr ~= "" and mfr) or (mdl ~= "" and mdl) or "Unknown Device"
    return hwid, lbl:sub(1, 80)
end

local function load_lic()
    mkdirp(LROOT)
    if not fexists(LIC_PATH) then return nil end
    local f = io.open(LIC_PATH, "r")
    if not f then return nil end
    local raw = f:read("*a")
    f:close()
    local d = json.decode(raw)
    if type(d) ~= "table" then
        os.remove(LIC_PATH)
        return nil
    end
    local k = (tostring(d.license_key or "")):gsub("%s", ""):upper()
    return k ~= "" and k or nil
end

local function save_lic(key, hwid, lbl)
    mkdirp(LROOT)
    local f = io.open(LIC_PATH, "w")
    if not f then return end
    f:write(json.encode({
        license_key = key:gsub("%s", ""):upper(),
        hwid = hwid,
        device_label = lbl,
        saved_at = os.time(),
    }))
    f:close()
end

local function http_req(method, url, hdrs, body, use_tool_api)
    local tmp = temp_path("lnx_r")
    local err_tmp = temp_path("lnx_e")
    local body_tmp = body and temp_path("lnx_b") or nil
    if body_tmp then
        local bf = io.open(body_tmp, "wb")
        if not bf then
            push_debug("HTTP", "temp body file open failed at " .. body_tmp)
            return nil, "", {
                stderr = "temp body file open failed",
                close_ok = false,
                close_reason = "temp_open_failed",
                close_code = 0,
            }
        end
        bf:write(body)
        bf:close()
    end
    local parts = {
        IS_WINDOWS and "curl.exe" or "curl",
        "-k",
        "-sS",
        "--ipv4",
        "--http1.1",
        "--connect-timeout", "10",
        "--max-time", "20",
        "--retry", "2",
        "--retry-delay", "1",
        "-o", esc(tmp),
        "-w", esc("%{http_code}"),
        "-X", method,
    }
    if use_tool_api then
        parts[#parts + 1] = "-u"
        parts[#parts + 1] = esc(TOOL_API.username .. ":" .. TOOL_API.password)
        parts[#parts + 1] = "-H"
        parts[#parts + 1] = esc("X-Lunex-Tool-Api-Key: " .. TOOL_API.key)
    end
    for _, h in ipairs(hdrs or {}) do
        parts[#parts + 1] = "-H"
        parts[#parts + 1] = esc(h)
    end
    if body then
        parts[#parts + 1] = "--data-binary"
        parts[#parts + 1] = esc("@" .. body_tmp)
    end
    parts[#parts + 1] = esc(url)
    push_debug("HTTP", method .. " " .. short(url, 96))
    local f = io.popen(table.concat(parts, " ") .. " 2>" .. esc(err_tmp))
    local sc = tonumber((f and f:read("*a") or "0"):match("%d+")) or 0
    local close_ok, close_reason, close_code = true, "exit", 0
    if f then
        close_ok, close_reason, close_code = f:close()
    end
    local raw = ""
    local rf = io.open(tmp, "r")
    if rf then
        raw = rf:read("*a") or ""
        rf:close()
    end
    local err_raw = ""
    local ef = io.open(err_tmp, "r")
    if ef then
        err_raw = ef:read("*a") or ""
        ef:close()
    end
    os.remove(tmp)
    os.remove(err_tmp)
    if body_tmp then os.remove(body_tmp) end
    if sc == 0 then
        push_debug("HTTP", ("curl failed reason=%s code=%s stderr=%s"):format(
            tostring(close_reason),
            tostring(close_code),
            short(err_raw ~= "" and err_raw or "no stderr", 140)
        ))
        return nil, raw, {
            stderr = err_raw,
            close_ok = close_ok,
            close_reason = close_reason,
            close_code = close_code,
        }
    end
    push_debug("HTTP", ("status=%s stderr=%s"):format(
        tostring(sc),
        short(err_raw ~= "" and err_raw or "none", 120)
    ))
    return sc, raw, {
        stderr = err_raw,
        close_ok = close_ok,
        close_reason = close_reason,
        close_code = close_code,
    }
end

local function api_post(route, payload)
    push_debug("API", "POST " .. route)
    local sc, raw, meta = http_req("POST", TOOL_API.base .. route, {
        "Accept: application/json",
        "Content-Type: application/json",
    }, json.encode(payload), true)
    if not sc then return nil, { message = "Server unavailable.", debug = meta } end
    local d = json.decode(raw)
    if type(d) ~= "table" then
        push_debug("API", "invalid json body " .. short(raw, 140))
        d = {}
    end
    push_debug("API", ("response=%s code=%s message=%s"):format(
        tostring(sc),
        tostring(d.code or "-"),
        short(d.message or raw or "", 120)
    ))
    return sc, d
end

local function chk_license(key)
    local sc, d = api_post("/api/termux/license-status", { licenseKey = key })
    if not sc then return "server", d.message or "Server unavailable." end
    if sc == 200 then return "valid", d.message or "Valid." end
    if (d.code or "") == "UNAUTHORIZED" then return "server", d.message or "Unauthorized." end
    if sc >= 500 then return "server", d.message or "Server unavailable." end
    return "invalid", d.message or "Invalid."
end

local function do_autologin(key, hwid, lbl)
    local sc, d = api_post("/api/termux/auto-login", { licenseKey = key, hwid = hwid, hwidLabel = lbl })
    if not sc then return "server", d.message or "Server unavailable." end
    if sc == 200 then return "valid", d.message or "license key valid!" end
    if (d.code or "") == "AUTO_LOGIN_FAILED" then return "auto_login_failed", d.message or "Auto login failed." end
    return "invalid", d.message or "Invalid."
end

local function do_validate(key, tc, hwid, lbl)
    local sc, d = api_post("/api/termux/validate", {
        licenseKey = key,
        termuxCode = tc,
        hwid = hwid,
        hwidLabel = lbl,
    })
    if not sc then return "server", d.message or "Server unavailable." end
    if sc == 200 then return "valid", d.message or "License key valid!" end
    local ec = d.code or ""
    if ec == "INVALID_LICENSE" then return "invalid_license", d.message or "Invalid." end
    if ec == "EXPIRED" then return "expired", d.message or "Expired." end
    if ec == "HWID_LIMIT_REACHED" then return "hwid_limit_reached", d.message or "HWID limit reached." end
    if ec == "UNAUTHORIZED" then return "server", d.message or "Unauthorized." end
    return "invalid", d.message or "Invalid."
end

local function urlencode(s)
    return (s:gsub("[^%w%-%.%_%~]", function(c) return ("%%%02X"):format(c:byte()) end))
end

local function buildq(t)
    local p = {}
    for k, v in pairs(t) do p[#p + 1] = urlencode(tostring(k)) .. "=" .. urlencode(tostring(v)) end
    return table.concat(p, "&")
end

local function gf_wt(token)
    return sha256(GF_UA .. "::" .. GF_LANG .. "::" .. token .. "::" .. math.floor(os.time() / 14400) .. "::" .. GF_SFXWT)
end

local function gf_req(method, url, token, wt, body_tbl)
    local hdrs = { "User-Agent: " .. GF_UA }
    if token then hdrs[#hdrs + 1] = "Authorization: Bearer " .. token end
    if wt then
        hdrs[#hdrs + 1] = "X-Website-Token: " .. wt
        hdrs[#hdrs + 1] = "X-BL: " .. GF_LANG
    end
    local body = body_tbl and json.encode(body_tbl) or nil
    if body then hdrs[#hdrs + 1] = "Content-Type: application/json" end
    local _, raw = http_req(method, url, hdrs, body, false)
    return json.decode(raw) or {}
end

local function gf_new_session()
    local acc = gf_req("POST", GF_API .. "/accounts", nil, nil, {})
    local token = type(acc.data) == "table" and tostring(acc.data.token or "") or ""
    if token == "" then error("Gofile: no token returned") end
    local wt = gf_wt(token)
    local pwhash = sha256(GF_PASS)
    local q = buildq({ password = pwhash, page = 1, pageSize = 200, sortField = "name", sortDirection = 1 })
    local folder = gf_req("GET", GF_API .. "/contents/" .. GF_CODE .. "?" .. q, token, wt)
    local fd = folder.data
    if type(fd) ~= "table" then error("Gofile: bad folder data") end
    local items = {}
    for _, c in pairs(fd.children or {}) do
        if c.type == "file" then
            local n = tostring(c.name or "")
            if n:match("%.apk$") or n:match("%.apk%.apk$") then
                items[#items + 1] = {
                    id = tostring(c.id or ""),
                    name = n,
                    size = tonumber(c.size) or 0,
                    link = tostring(c.link or ""),
                }
            end
        end
    end
    table.sort(items, function(a, b) return a.name:lower() < b.name:lower() end)
    return {
        token = token,
        wt = wt,
        pwhash = pwhash,
        folder = tostring(fd.id or GF_CODE),
    }, items
end

local function gf_refresh(sess)
    sess.wt = gf_wt(sess.token)
    local q = buildq({ password = sess.pwhash, page = 1, pageSize = 200 })
    gf_req("GET", GF_API .. "/contents/" .. sess.folder .. "?" .. q, sess.token, sess.wt)
end

local function dl_apk(sess, apk)
    gf_refresh(sess)
    mkdirp(DL_ROOT)
    local dest = DL_ROOT .. "/" .. safename(apk.name)
    os.remove(dest)
    local cmd = "curl -s -L -o " .. esc(dest)
        .. " -H " .. esc("User-Agent: " .. GF_UA)
        .. " -H " .. esc("Cookie: accountToken=" .. sess.token)
        .. " -H " .. esc("Referer: " .. GF_PAGE)
        .. " " .. esc(apk.link) .. " 2>" .. NULL_DEVICE
    if not os.execute(cmd) then error("curl download failed") end
    local f = io.open(dest, "rb")
    if not f then error("downloaded file missing") end
    local sz = f:seek("end")
    f:close()
    if sz == 0 then
        os.remove(dest)
        error("downloaded file is empty")
    end
    return dest
end

local function inst_apk(path)
    local tries = {}
    if shl("command -v su") ~= "" then
        tries[#tries + 1] = "su -c " .. esc("pm install -r " .. path)
        tries[#tries + 1] = "su -c " .. esc("cmd package install -r " .. path)
    end
    if shl("command -v pm") ~= "" then tries[#tries + 1] = "pm install -r " .. esc(path) end
    if #tries == 0 then return false, "No package installer found." end
    local last = "Install failed."
    for _, cmd in ipairs(tries) do
        local f = io.popen(cmd .. " 2>&1")
        local out = f and (f:read("*a") or "") or ""
        if f then f:close() end
        out = out:match("^%s*(.-)%s*$")
        if out:match("[Ss]uccess") then return true, out end
        if out ~= "" then last = out end
    end
    return false, last
end

local function install_selected(entries, idxs, sess)
    local results, total = {}, #idxs
    for pos, idx in ipairs(idxs) do
        local apk = entries[idx]
        mdelay(pos, total, pos * 3)
        local ok, out, dest = false, "Download failed.", nil
        local dOk, dR = pcall(dl_apk, sess, apk)
        if dOk then
            dest = dR
            mdelay(pos, total, pos * 5)
            local iOk, iSuc, iMsg = pcall(inst_apk, dest)
            if iOk then
                ok = iSuc
                out = iMsg or (iSuc and "Success" or "Install failed.")
            else
                ok = false
                out = tostring(iSuc)
            end
            os.remove(dest)
        else
            out = tostring(dR)
        end
        mdelay(pos, total, pos * 7, 1, 0.25)
        results[#results + 1] = { apk.name, ok, out }
        prog((ok and "Completed" or "Process failed") .. " " .. pos .. "/" .. total, apk.name, out or (ok and "Success" or "Install failed."), ok and "success" or "danger")
        sleep(ok and 0.8 or 1.0)
    end
    return results
end

local READ_KEY_CMD = [[bash -c 'IFS= read -r -s -n1 k </dev/tty 2>/dev/null; IFS= read -r -s -n2 -t0.1 s </dev/tty 2>/dev/null; printf "%s" "$k$s"' 2>/dev/null | od -An -tx1 | tr -d ' \n\r']]

local function read_key()
    if IS_WINDOWS then
        io.write(col("  Command [w/s/space/a/enter/q]: ", P.muted))
        io.flush()
        local value = (io.read("*l") or ""):lower()
        if value == "w" then return "UP" end
        if value == "s" then return "DOWN" end
        if value == "space" then return "SPACE" end
        if value == "a" then return "A" end
        if value == "q" then return "Q" end
        return "ENTER"
    end
    local f = io.popen(READ_KEY_CMD)
    if not f then return "" end
    local h = (f:read("*a") or ""):lower():gsub("[%s\n\r]", "")
    f:close()
    if h == "1b5b41" then return "UP" end
    if h == "1b5b42" then return "DOWN" end
    if h == "" or h == "0d" or h == "0a" then return "ENTER" end
    if h == "20" then return "SPACE" end
    if h == "61" or h == "41" then return "A" end
    if h == "71" or h == "51" or h == "03" then return "Q" end
    return ""
end

local function wait_enter()
    io.write(col("  Press Enter to continue...", P.muted))
    io.flush()
    io.read("*l")
end

local function prompt_val(label)
    io.write(col("  › " .. label .. ": ", P.text, P.bold))
    io.flush()
    local v = io.read("*l") or ""
    return v:match("^%s*(.-)%s*$"):upper()
end

local function mrow(text, sel, act)
    local ic = sel and "[x]" or "[ ]"
    local ct = " " .. ic .. " " .. text .. " "
    if act then return col(ct, P.active, P.accent, P.bold)
    elseif sel then return col(ct, P.button, P.accent)
    else return col(ct, P.button, P.text) end
end

local function arow(lbl, act)
    local ct = " [ " .. lbl .. " ] "
    if act then return col(ct, P.bact, P.accent, P.bold) end
    return col(ct, P.button, P.text)
end

local function render_menu(entries, sel_set, cursor, msg)
    clear()
    banner()
    local selcnt = 0
    for _ in pairs(sel_set) do selcnt = selcnt + 1 end
    local lines = {
        col(" Lunex Delta Lite - [V1]  discord.gg/HQtp9fVqZT", P.accent, P.bold),
        col((" Selected: %d/%d"):format(selcnt, #entries), P.muted),
    }
    if msg then lines[#lines + 1] = col(" " .. msg[2], TONES[msg[1]] or P.muted)
    else lines[#lines + 1] = "" end
    local w = tw() - 12
    for i, e in ipairs(entries) do
        lines[#lines + 1] = mrow(trunc(e.name .. "  -  " .. hsize(e.size), w), sel_set[i] == true, cursor == i)
    end
    local as = #entries + 1
    lines[#lines + 1] = ""
    lines[#lines + 1] = arow("Confirm Install", cursor == as)
    lines[#lines + 1] = arow("Refresh Files", cursor == as + 1)
    lines[#lines + 1] = arow("Exit", cursor == as + 2)
    lines[#lines + 1] = ""
    lines[#lines + 1] = col(" Up/Down Move   Space Select   Enter Confirm   A All   Q Quit", P.muted)
    box(" Lunex Lite Clones ", lines)
end

local function render_summ(results)
    clear()
    banner()
    local lines = { col(" Install summary", P.accent, P.bold), "" }
    for _, r in ipairs(results) do
        local name, ok, out = r[1], r[2], r[3]
        local icon = ok and "✔" or "✖"
        local c = ok and P.success or P.danger
        lines[#lines + 1] = col(" " .. icon .. " " .. name, c)
        if out and out ~= "" then lines[#lines + 1] = col("    " .. trunc(out, tw() - 18), P.muted) end
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = col(" Press Enter to return to the selector.", P.muted)
    box(" Results ", lines)
    wait_enter()
end

local function ensure_access(hwid, lbl)
    local key = load_lic()
    if not key then return "failed", "auto login failed" end
    push_debug("AUTH", "auto login with saved license")
    local st, msg = do_autologin(key, hwid, lbl)
    if st == "valid" then return "valid", msg end
    if st == "server" then return "server", msg end
    os.remove(LIC_PATH)
    return "failed", "auto login failed"
end

local function run_selector(hwid, lbl)
    local msg = nil
    prog("Loading", "Refreshing Lunex Delta Lite Clones...", " Contacting Gofile...")
    local ok_s, sess, items = pcall(gf_new_session)
    if not ok_s then
        push_debug("GOFILE", tostring(sess))
        show_error_with_activity("Load failed", "Unable to fetch clone list.")
        return 1
    end
    if #items == 0 then
        push_debug("GOFILE", "no clone files returned")
        show_error_with_activity("Load failed", "No clones were found.")
        return 1
    end

    local sel_set, cursor = {}, 1
    local total_rows = #items + 3

    while true do
        render_menu(items, sel_set, cursor, msg)
        msg = nil
        local key = read_key()
        local as = #items + 1

        if key == "UP" then
            cursor = ((cursor - 2) % total_rows) + 1
        elseif key == "DOWN" then
            cursor = (cursor % total_rows) + 1
        elseif key == "Q" then
            return 0
        elseif key == "SPACE" then
            if cursor <= #items then sel_set[cursor] = not sel_set[cursor] or nil end
        elseif key == "A" then
            local cnt = 0
            for _ in pairs(sel_set) do cnt = cnt + 1 end
            if cnt == #items then sel_set = {}
            else for i = 1, #items do sel_set[i] = true end end
        elseif key == "ENTER" then
            if cursor <= #items then
                sel_set[cursor] = not sel_set[cursor] or nil
            elseif cursor == as then
                local cnt = 0
                for _ in pairs(sel_set) do cnt = cnt + 1 end
                if cnt == 0 then
                    msg = { "warning", "Select at least one clone first." }
                    goto continue
                end
                local ast, amsg = ensure_access(hwid, lbl)
                if ast == "server" then
                    show_error_with_activity("Access", amsg)
                    return 2
                end
                if ast ~= "valid" then
                    status_box(" Access ", amsg, "danger")
                    sleep(1)
                    return 2
                end
                local idxs = {}
                for i = 1, #items do if sel_set[i] then idxs[#idxs + 1] = i end end
                local results = install_selected(items, idxs, sess)
                render_summ(results)
                sel_set = {}
                msg = { "success", "Install run completed." }
            elseif cursor == as + 1 then
                local ast, amsg = ensure_access(hwid, lbl)
                if ast == "server" then
                    show_error_with_activity("Access", amsg)
                    return 2
                end
                if ast ~= "valid" then
                    status_box(" Access ", amsg, "danger")
                    sleep(1)
                    return 2
                end
                prog("Refreshing", "Refreshing Lunex Delta Lite Clones...", " Contacting Gofile...")
                local rok, rs, ri = pcall(gf_new_session)
                if rok then
                    sess = rs
                    items = ri
                    sel_set = {}
                    cursor = 1
                    msg = { "success", "Clone list refreshed." }
                    total_rows = #items + 3
                else
                    push_debug("GOFILE", "refresh failed " .. tostring(rs))
                    show_error_with_activity("Refresh", "Refresh failed.")
                    return 2
                end
            else
                return 0
            end
        end
        ::continue::
    end
end

local function try_saved_login(hwid, lbl)
    local key = load_lic()
    if not key then return "missing", nil end
    push_debug("AUTH", "checking saved license")
    status_box(" Access ", "Checking saved license...", "warning")
    local st, msg = do_autologin(key, hwid, lbl)
    if st == "valid" then return "valid", key end
    if st == "server" then return "server", msg end
    os.remove(LIC_PATH)
    return "failed", "auto login failed"
end

local function main()
    mkdirp(LROOT)
    mkdirp(TEMP_ROOT)
    local hwid, lbl = device_id()
    push_debug("BOOT", "tool base " .. TOOL_API.base)
    push_debug("BOOT", "device " .. short(lbl, 48) .. " hwid " .. hwid:sub(1, 12))
    local notice = nil

    local sl_st, sl_msg = try_saved_login(hwid, lbl)

    if sl_st == "valid" then
        local r = run_selector(hwid, lbl)
        if r == 2 then notice = { "warning", "↻", "auto login failed" }
        else os.exit(r) end
    end
    if sl_st == "server" then
        show_error_with_activity("Access", tostring(sl_msg))
        os.exit(1)
    end
    if sl_st == "failed" then
        notice = { "warning", "↻", tostring(sl_msg) }
    end

    while true do
        clear()
        banner()
        local lines = {}
        if notice then
            local c = TONES[notice[1]] or P.muted
            lines[#lines + 1] = col(" " .. notice[2] .. " " .. notice[3], c)
            lines[#lines + 1] = ""
        end
        lines[#lines + 1] = col(" Enter your license key to continue.", P.muted)
        box(" Access ", lines)
        notice = nil

        local key = prompt_val("License key")
        if key == "" then
            notice = { "danger", "✖", "No license key provided. Please try again." }
            goto lic_next
        end

        status_box(" Access ", "Checking license...", "warning")
        local ls, lm = chk_license(key)
        if ls == "server" then
            show_error_with_activity("Access", lm)
            os.exit(1)
        end
        if ls ~= "valid" then
            notice = { "danger", "✖", "License key not recognised. Please try again." }
            goto lic_next
        end

        local tc_notice = { "warning", "→", "Run /get-termux-code in the bot, then paste the code from your DMs." }
        while true do
            clear()
            banner()
            local tlines = {}
            if tc_notice then
                local c = TONES[tc_notice[1]] or P.muted
                tlines[#tlines + 1] = col(" " .. tc_notice[2] .. " " .. tc_notice[3], c)
                tlines[#tlines + 1] = ""
            end
            tlines[#tlines + 1] = col(" Device: " .. lbl, P.accent, P.bold)
            box(" Verification ", tlines)

            local tc = prompt_val("Termux code")
            if tc == "" then
                tc_notice = { "danger", "✖", "No code entered. Please try again." }
                goto tc_next
            end

            status_box(" Verification ", "Validating...", "warning")
            local cs, cm = do_validate(key, tc, hwid, lbl)

            if cs == "server" then
                show_error_with_activity("Verification", cm)
                os.exit(1)
            end

            if cs == "valid" then
                save_lic(key, hwid, lbl)
                local r = run_selector(hwid, lbl)
                if r == 2 then
                    notice = { "warning", "↻", "auto login failed" }
                    break
                end
                os.exit(r)
            end

            if cs == "invalid_license" then
                os.remove(LIC_PATH)
                notice = { "danger", "✖", "License is no longer valid. Please re-enter." }
                break
            end
            if cs == "expired" then
                tc_notice = { "warning", "↻", "Code expired. Run /get-termux-code again for a fresh code." }
                goto tc_next
            end
            if cs == "hwid_limit_reached" then
                tc_notice = { "danger", "✖", "HWID limit reached. Reset HWIDs before logging in here." }
                goto tc_next
            end
            tc_notice = { "danger", "✖", "Invalid code. Please try again." }
            ::tc_next::
        end
        ::lic_next::
    end
end

local ok, err = pcall(main)
if not ok then
    io.write("\n[fatal] " .. tostring(err) .. "\n")
    os.exit(1)
end
