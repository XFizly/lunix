#!/usr/bin/env sh
_=[[
if command -v lua >/dev/null 2>&1; then
  exec lua "$0" "$@"
fi
exec lua5.4 "$0" "$@"
]]
math.randomseed(os.time())

-- ─────────────────────────────────────────────────────────────────────────────
-- Config
-- ─────────────────────────────────────────────────────────────────────────────
local HOME           = os.getenv("HOME") or "/data/data/com.termux/files/home"
local IS_WIN         = package.config:sub(1, 1) == "\\"
local DEVNULL        = IS_WIN and "NUL" or "/dev/null"
local TEMP_ROOT      = IS_WIN
    and (os.getenv("TEMP") or os.getenv("TMP") or ".")
    or  (os.getenv("TMPDIR") or HOME .. "/.lunex-tmp")
local LUNEX_ROOT     = HOME .. "/lunex"
local LICENSE_PATH   = LUNEX_ROOT .. "/license_key.json"
local LUNEX_TOOL_API = "0324241241241:https://lunex-termux-api.vercel.app:lunextool:R9p4K2m8Qx6Z1v3N"

-- ─────────────────────────────────────────────────────────────────────────────
-- Minimal JSON
-- ─────────────────────────────────────────────────────────────────────────────
local json = {}

local function json_encode(v)
    local t = type(v)
    if t == "nil"     then return "null" end
    if t == "boolean" then return v and "true" or "false" end
    if t == "number"  then return v ~= v and "null" or ("%.14g"):format(v) end
    if t == "string"  then
        return '"' .. v:gsub('[\\"]', function(c) return "\\" .. c end)
                      :gsub("\n","\\n"):gsub("\r","\\r"):gsub("\t","\\t") .. '"'
    end
    if t == "table" then
        local arr = #v > 0
        if arr then
            for i = 1, #v do if v[i] == nil then arr = false; break end end
        end
        local p = {}
        if arr then
            for _, x in ipairs(v) do p[#p+1] = json_encode(x) end
            return "[" .. table.concat(p, ",") .. "]"
        end
        for k, x in pairs(v) do
            p[#p+1] = json_encode(tostring(k)) .. ":" .. json_encode(x)
        end
        return "{" .. table.concat(p, ",") .. "}"
    end
    return "null"
end

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
    local p, c = {}, i + 1
    while c <= #s do
        local ch = s:sub(c, c)
        if ch == '"' then return table.concat(p), c + 1 end
        if ch == "\\" then
            c = c + 1; local e = s:sub(c, c)
            if e == '"' then p[#p+1] = '"'
            elseif e == "\\" then p[#p+1] = "\\"
            elseif e == "n"  then p[#p+1] = "\n"
            elseif e == "r"  then p[#p+1] = "\r"
            elseif e == "t"  then p[#p+1] = "\t"
            elseif e == "u"  then
                local code = tonumber(s:sub(c+1, c+4), 16) or 63
                p[#p+1] = code < 128 and string.char(code) or "?"
                c = c + 4
            else p[#p+1] = e end
        else p[#p+1] = ch end
        c = c + 1
    end
    return table.concat(p), c
end

local function jarr(s, i)
    local r = {}; i = jskip(s, i)
    if s:sub(i,i) == "]" then return r, i+1 end
    while true do
        local x; x, i = jval(s, i); r[#r+1] = x
        i = jskip(s, i)
        local ch = s:sub(i,i)
        if ch == "]" then return r, i+1 end
        if ch ~= "," then break end
        i = i + 1
    end
    return r, i
end

local function jobj(s, i)
    local r = {}; i = jskip(s, i)
    if s:sub(i,i) == "}" then return r, i+1 end
    while true do
        i = jskip(s, i)
        local k; k, i = jstr(s, i)
        i = jskip(s, i)
        if s:sub(i,i) ~= ":" then break end
        i = i + 1
        local x; x, i = jval(s, i)
        r[k] = x; i = jskip(s, i)
        local ch = s:sub(i,i)
        if ch == "}" then return r, i+1 end
        if ch ~= "," then break end
        i = i + 1
    end
    return r, i
end

jval = function(s, i)
    i = jskip(s, i)
    local ch = s:sub(i,i)
    if ch == '"' then return jstr(s, i) end
    if ch == '[' then return jarr(s, i+1) end
    if ch == '{' then return jobj(s, i+1) end
    if s:sub(i,i+3) == "true"  then return true,  i+4 end
    if s:sub(i,i+4) == "false" then return false, i+5 end
    if s:sub(i,i+3) == "null"  then return nil,   i+4 end
    local n = s:match("^-?%d+%.?%d*[eE]?[+-]?%d*", i)
    if n then return tonumber(n), i+#n end
    return nil, i+1
end

function json.decode(s)
    if type(s) ~= "string" or s == "" then return nil end
    local ok, r = pcall(jval, s, 1)
    return ok and r or nil
end
json.encode = json_encode

-- ─────────────────────────────────────────────────────────────────────────────
-- Shell helpers
-- ─────────────────────────────────────────────────────────────────────────────
local function trim(s) return tostring(s or ""):match("^%s*(.-)%s*$") end

local function run_line(cmd)
    local h = io.popen(cmd .. " 2>" .. DEVNULL)
    if not h then return "" end
    local o = trim(h:read("*l") or "")
    h:close(); return o
end

local function run_all(cmd)
    local h = io.popen(cmd .. " 2>" .. DEVNULL)
    if not h then return "" end
    local o = h:read("*a") or ""
    h:close(); return o
end

local function make_dir(path)
    if IS_WIN then
        os.execute('if not exist "' .. path .. '" mkdir "' .. path .. '" >' .. DEVNULL .. ' 2>&1')
        return
    end
    os.execute("mkdir -p '" .. path:gsub("'", "'\\''") .. "' 2>" .. DEVNULL)
end

local function file_exists(path)
    local h = io.open(path, "r")
    if h then h:close(); return true end
    return false
end

local function shell_escape(s)
    if IS_WIN then return '"' .. tostring(s):gsub('"', '""') .. '"' end
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function temp_path(pfx)
    return TEMP_ROOT .. (IS_WIN and "\\" or "/") .. pfx .. "_" .. math.random(999999) .. ".tmp"
end

local function cmd_exists(c) return run_line("command -v " .. c) ~= "" end

-- ─────────────────────────────────────────────────────────────────────────────
-- ANSI / UTF-8  WIDTH  SYSTEM
--
--   THE KEY FIX:  Lua's # operator counts *bytes*, not terminal columns.
--   ANSI escape sequences are multi-byte but 0 columns wide.
--   UTF-8 multi-byte chars are 2-4 bytes but typically 1 column wide.
--   This system always measures in *terminal columns*, never raw bytes.
-- ─────────────────────────────────────────────────────────────────────────────

-- Strip all ANSI/VT escape sequences from a string.
local function strip_ansi(s)
    -- Matches ESC [ ... m  (CSI sequences used for color/style)
    -- and ESC [ ... H/J/K  (cursor movement — just in case)
    return (tostring(s or "")):gsub("\27%[[%d;:]*[A-Za-z]", "")
end

-- Count the number of terminal *columns* a string occupies.
-- Handles: ANSI escape codes (0 columns), multi-byte UTF-8 (1 column per codepoint).
-- Note: CJK wide chars are 2 columns in real terminals; we don't handle them here
-- because our content never contains them.  Everything we render is 1 col/codepoint.
local function col_width(s)
    local clean = strip_ansi(tostring(s or ""))
    local w, i  = 0, 1
    while i <= #clean do
        local b = clean:byte(i)
        -- Count one column per codepoint, skip continuation bytes
        w = w + 1
        if     b >= 0xF0 then i = i + 4   -- 4-byte sequence
        elseif b >= 0xE0 then i = i + 3   -- 3-byte sequence  (box-drawing, block glyphs)
        elseif b >= 0xC0 then i = i + 2   -- 2-byte sequence
        else                   i = i + 1  -- ASCII
        end
    end
    return w
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Colors
-- ─────────────────────────────────────────────────────────────────────────────
local E = "\27["
local R = E .. "0m"

local function tc(r, g, b) return E .. "38;2;" .. r .. ";" .. g .. ";" .. b .. "m" end
local function bc(r, g, b) return E .. "48;2;" .. r .. ";" .. g .. ";" .. b .. "m" end
local BOLD   = E .. "1m"
local DIM    = E .. "2m"
local ITALIC = E .. "3m"

-- Wrap text in ANSI color codes, always reset after.
local function paint(text, ...)
    local codes = table.concat({ ... })
    if codes == "" then return tostring(text or "") end
    return codes .. tostring(text or "") .. R
end

local C = {
    -- Brand blues (logo gradient, top → bottom)
    b1 = tc(110, 185, 255),
    b2 = tc( 75, 150, 245),
    b3 = tc( 50, 120, 225),
    b4 = tc( 35,  95, 200),
    b5 = tc( 22,  68, 168),
    b6 = tc( 14,  47, 130),

    -- Accent spectrum
    cyan   = tc(  0, 218, 255),
    teal   = tc(  0, 200, 178),
    violet = tc(150, 110, 255),
    gold   = tc(255, 198,  48),

    -- Neutrals
    white   = tc(238, 244, 255),
    silver  = tc(195, 208, 228),
    ash     = tc(148, 162, 182),
    slate   = tc( 96, 112, 136),
    coal    = tc( 54,  64,  82),

    -- Semantic
    ok   = tc( 66, 220, 118),
    warn = tc(255, 188,  48),
    err  = tc(255,  70,  70),

    -- Border shades (for boxes)
    bdr_lo  = tc( 36,  56, 106),
    bdr_mid = tc( 52,  82, 148),
    bdr_hi  = tc( 78, 118, 200),
    bdr_ok  = tc( 28, 138,  66),
    bdr_err = tc(136,  28,  28),
    bdr_wrn = tc(138, 100,  18),
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Layout helpers  (all column-aware via col_width)
-- ─────────────────────────────────────────────────────────────────────────────
local function term_cols()
    return math.max(60, tonumber(run_line("tput cols")) or 80)
end

-- Pad/trim a string to exactly `w` terminal columns.
-- Preserves ANSI codes; padding is via plain spaces appended after the content.
local function pad_col(s, w)
    s = tostring(s or "")
    local cw = col_width(s)
    if cw >= w then return s end          -- never truncate; caller must pass safe content
    return s .. string.rep(" ", w - cw)
end

-- Center a string (which may contain ANSI codes) within `w` columns.
local function center_col(s, w)
    local cw  = col_width(tostring(s or ""))
    local pad = math.max(0, w - cw)
    return string.rep(" ", math.floor(pad / 2)) .. s .. string.rep(" ", math.ceil(pad / 2))
end

-- Truncate plain text to at most `w` visual columns, appending "…".
local function trunc_plain(s, w)
    s = strip_ansi(tostring(s or ""))
    if col_width(s) <= w then return s end
    -- Walk byte-by-byte counting codepoints until we reach w-1 columns
    local out, cw, i = {}, 0, 1
    while i <= #s and cw < w - 1 do
        local b     = s:byte(i)
        local bytes = b >= 0xF0 and 4 or b >= 0xE0 and 3 or b >= 0xC0 and 2 or 1
        out[#out+1] = s:sub(i, i + bytes - 1)
        cw = cw + 1
        i  = i + bytes
    end
    return table.concat(out) .. "…"
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Logo  (toilet → figlet → built-in block-letter fallback)
--
--   Install in Termux for best results:
local BUILTIN_LOGO = {
    { C.b1, " ██╗      ██╗   ██╗███╗   ██╗███████╗██╗  ██╗ " },
    { C.b2, " ██║      ██║   ██║████╗  ██║██╔════╝╚██╗██╔╝ " },
    { C.b3, " ██║      ██║   ██║██╔██╗ ██║█████╗   ╚███╔╝  " },
    { C.b4, " ██║      ██║   ██║██║╚██╗██║██╔══╝   ██╔██╗  " },
    { C.b5, " ███████╗ ╚██████╔╝██║ ╚████║███████╗██╔╝╚██╗ " },
    { C.b6, " ╚══════╝  ╚═════╝ ╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝ " },
    { C.b5, "            L U N E X   A U T H   S U I T E            " },
}

local function split_lines(s)
    local lines = {}
    for ln in (s .. "\n"):gmatch("([^\n]*)\n") do lines[#lines+1] = ln end
    while #lines > 0 and not lines[#lines]:match("%S") do lines[#lines] = nil end
    return lines
end

local LOGO_CACHE, LOGO_PRE_COLORED = nil, false

local function build_logo_cache()
    LOGO_CACHE      = BUILTIN_LOGO
    LOGO_PRE_COLORED = false
end

local function render_logo(w)
    if not LOGO_CACHE then build_logo_cache() end
    local colors = { C.b1, C.b2, C.b3, C.b4, C.b5, C.b6 }

    if LOGO_PRE_COLORED then
        -- lolcat already embedded ANSI codes; just center by stripped width
        for _, line in ipairs(LOGO_CACHE) do
            io.write(center_col(line, w) .. R .. "\n")
        end
    elseif type(LOGO_CACHE[1]) == "table" then
        -- Built-in: each entry is { color, text }
        for i, row in ipairs(LOGO_CACHE) do
            local col = row[1] or colors[((i-1) % #colors) + 1]
            io.write(center_col(paint(row[2], BOLD, col), w) .. "\n")
        end
    else
        -- figlet/toilet plain text: apply our blue gradient
        for i, line in ipairs(LOGO_CACHE) do
            local col = colors[((i-1) % #colors) + 1]
            io.write(center_col(paint(line, BOLD, col), w) .. "\n")
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Box drawing
-- ─────────────────────────────────────────────────────────────────────────────
local BOX = {
    -- double-line  (primary content panels)
    D = { tl="╔", tr="╗", bl="╚", br="╝", h="═", v="║", sl="╠", sr="╣" },
    -- single-line  (note/hint strips)
    S = { tl="┌", tr="┐", bl="└", br="┘", h="─", v="│", sl="├", sr="┤" },
    -- rounded      (soft secondary panels)
    R = { tl="╭", tr="╮", bl="╰", br="╯", h="─", v="│", sl="├", sr="┤" },
}

-- Draw a complete box, writing directly to stdout.
-- `inner`  : number of *terminal columns* between the two vertical walls
-- `title`  : plain-text title (nil = no title gap in top border)
-- `rows`   : list of strings (may contain ANSI codes)
-- `bc`     : border color code string
-- `bstyle` : "D", "S", or "R"
-- `margin` : number of leading spaces before each line
local function draw_box_raw(inner, title, rows, bc, bstyle, margin)
    local b   = BOX[bstyle or "D"] or BOX.D
    local pad = string.rep(" ", margin or 2)
    bc = bc or C.bdr_mid

    -- ── Top border ──────────────────────────────────────────────────────────
    local title_str = title and (" " .. title .. " ") or ""
    -- title_str is always plain ASCII so col_width == #title_str, but use
    -- col_width to stay correct if someone passes a Unicode title later.
    local title_cw  = col_width(title_str)
    local h_fill    = math.max(0, inner - title_cw)
    io.write(pad .. paint(b.tl .. title_str .. string.rep(b.h, h_fill) .. b.tr, bc) .. "\n")

    -- ── Content rows ─────────────────────────────────────────────────────────
    for _, row in ipairs(rows) do
        local content = tostring(row or "")
        -- pad_col pads based on col_width (ANSI-aware, UTF-8-aware)
        io.write(pad .. paint(b.v, bc) .. pad_col(content, inner) .. paint(b.v, bc) .. "\n")
    end

    -- ── Bottom border ────────────────────────────────────────────────────────
    io.write(pad .. paint(b.bl .. string.rep(b.h, inner) .. b.br, bc) .. "\n")
end

-- High-level wrapper that auto-calculates inner width from terminal.
local function draw_box(title, rows, bc, bstyle, margin)
    local w     = term_cols()
    local m     = margin or 2
    local inner = math.max(34, math.min(w - m * 2 - 2, 78))
    draw_box_raw(inner, title, rows, bc, bstyle, m)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Header
-- ─────────────────────────────────────────────────────────────────────────────
local function clear_screen()
    if IS_WIN then os.execute("cls >" .. DEVNULL .. " 2>&1") end
    io.write("\027[3J\027[2J\027[H"); io.flush()
end

local function draw_header(step)
    local w = term_cols()
    clear_screen()
    io.write("\n")
    render_logo(w)
    io.write("\n")

    -- Tagline
    local tag = paint("▸ ", C.bdr_mid)
              .. paint("L U N E X   ·   L I T E  C L O N E S   ·   V E R S I O N 1.0.0", C.coal)
              .. paint(" ◂", C.bdr_mid)
    io.write(center_col(tag, w) .. "\n\n")

    -- Rule
    local rule_w = math.min(w - 8, 66)
    io.write(center_col(paint(string.rep("─", rule_w), C.bdr_lo), w) .. "\n")

    -- Step badge
    if step and step ~= "" then
        io.write("\n")
        local badge = "  " .. step .. "  "
        io.write(center_col(paint(badge, BOLD, C.cyan), w) .. "\n")
    end
    io.write("\n")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Symbols
-- ─────────────────────────────────────────────────────────────────────────────
--  Each symbol string has a specific col_width; keep them consistent so that
--  content lines line up cleanly inside the box.
local SYM = {
    ok     = paint(" ✔ ", BOLD, C.ok),    -- 3 cols
    err    = paint(" ✘ ", BOLD, C.err),   -- 3 cols
    warn   = paint(" ⚠ ", BOLD, C.warn),  -- 3 cols
    wait   = paint(" ◌ ", C.cyan),        -- 3 cols
    info   = paint(" ◈ ", C.cyan),        -- 3 cols
    bullet = paint(" • ", C.slate),       -- 3 cols
    key    = paint(" ⬡ ", C.teal),        -- 3 cols
    arrow  = paint(" › ", BOLD, C.b2),    -- 3 cols
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Screen layouts
-- ─────────────────────────────────────────────────────────────────────────────
local function S(sym, text_parts)
    -- Build a single row: sym  +  concatenated text parts  (already painted)
    return sym .. table.concat(text_parts)
end

local function show_license_screen(notice)
    local problem = notice and notice ~= "Waiting for license key."
    draw_header("LICENSE AUTHENTICATION")
    draw_box(" License Key ", {
        "",
        S(SYM.key,  { paint("Enter your license key to continue.", BOLD, C.white) }),
        "",
        S(SYM.bullet, { paint("Use ", C.ash), paint("/key_information", BOLD, C.cyan), paint(" in the Discord bot.", C.ash) }),
        S(SYM.bullet, { paint("Paste the key at the prompt below.", C.ash) }),
        "",
        S(problem and SYM.warn or SYM.wait,
          { paint(notice or "Waiting for license key.", problem and C.warn or C.silver) }),
        "",
    }, C.bdr_mid, "D")

    io.write("\n")

    draw_box(nil, {
        S(SYM.bullet, { paint("Saved sessions are checked automatically on startup.", C.slate) }),
        S(SYM.bullet, { paint("If auto-login fails, re-enter your license key.", C.slate) }),
    }, C.bdr_lo, "R")

    io.write("\n")
end

local function show_code_screen(device_label, notice)
    local problem = notice and notice ~= "Waiting for Termux code."
    draw_header("DEVICE VERIFICATION")
    draw_box(" Termux Code ", {
        "",
        S(SYM.key,  { paint("Device  ", C.ash), paint(trunc_plain(device_label or "Unknown", 54), BOLD, C.white) }),
        "",
        S(SYM.bullet, { paint("Run ", C.ash), paint("/get-termux-code", BOLD, C.cyan), paint(" in the Discord bot.", C.ash) }),
        S(SYM.bullet, { paint("Paste the code sent to your DMs.", C.ash) }),
        "",
        S(problem and SYM.warn or SYM.wait,
          { paint(notice or "Waiting for Termux code.", problem and C.warn or C.silver) }),
        "",
    }, C.bdr_mid, "D")

    io.write("\n")

    draw_box(nil, {
        S(SYM.bullet, { paint("This code is tied to your device HWID.", C.slate) }),
        S(SYM.bullet, { paint("If the code expires, run /get-termux-code again.", C.slate) }),
    }, C.bdr_lo, "R")

    io.write("\n")
end

local function show_status_screen(title, message, kind)
    -- kind: "ok" | "err" | "warn" | nil (info/default)
    local icon = ({ ok=SYM.ok, err=SYM.err, warn=SYM.warn })[kind] or SYM.info
    local bdr  = ({ ok=C.bdr_ok, err=C.bdr_err, warn=C.bdr_wrn })[kind] or C.bdr_hi

    draw_header(title:upper())
    draw_box(" " .. title .. " ", {
        "",
        S(icon, { paint(message or "", BOLD, C.white) }),
        "",
    }, bdr, "D")
    io.write("\n")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Prompt
-- ─────────────────────────────────────────────────────────────────────────────
local function prompt(label)
    io.write("\n" .. SYM.arrow .. paint(label, BOLD, C.white) .. "  " .. paint("▶  ", C.bdr_mid))
    io.flush()
    return trim(io.read("*l") or "")
end

local function print_success()
    show_status_screen("Authenticated", "Verification complete. Welcome to Lunex.", "ok")
    print("Success")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Crypto  (SHA-256 via openssl / PowerShell)
-- ─────────────────────────────────────────────────────────────────────────────
local function sha256(value)
    local path = temp_path("lunex_sha")
    local h = io.open(path, "wb")
    if not h then return "" end
    h:write(value); h:close()
    local digest
    if IS_WIN then
        digest = run_line("powershell -NoProfile -Command \"(Get-FileHash -Algorithm SHA256 " ..
            shell_escape(path) .. ").Hash\"")
    else
        digest = run_line("openssl dgst -sha256 < " .. shell_escape(path) .. " | awk '{print $NF}'")
    end
    os.remove(path)
    return trim(digest):lower()
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Device fingerprint
-- ─────────────────────────────────────────────────────────────────────────────
local function getprop(n) return run_line("getprop " .. n) end

local function device_identity()
    local parts, captured = {}, {}
    local props = {
        "ro.serialno","ro.boot.serialno","ro.product.manufacturer",
        "ro.product.brand","ro.product.model","ro.product.device",
        "ro.product.name","ro.build.fingerprint","ro.hardware",
    }
    if cmd_exists("getprop") then
        for _, n in ipairs(props) do
            local v = getprop(n)
            if v ~= "" then captured[n] = v; parts[#parts+1] = n .. "=" .. v end
        end
    end
    for _, p in ipairs({ "/etc/machine-id", "/var/lib/dbus/machine-id" }) do
        local h = io.open(p, "r")
        if h then
            local mid = trim(h:read("*l") or ""); h:close()
            if mid ~= "" then parts[#parts+1] = "machine-id=" .. mid end
        end
    end
    parts[#parts+1] = "node="    .. run_line("hostname")
    parts[#parts+1] = "system="  .. run_line("uname -s")
    parts[#parts+1] = "machine=" .. run_line("uname -m")

    local hwid  = sha256(table.concat(parts, "\n")):upper():sub(1, 32)
    local mfr   = captured["ro.product.manufacturer"] or captured["ro.product.brand"] or run_line("uname -s")
    local model = captured["ro.product.model"] or captured["ro.product.device"] or run_line("hostname") or "Device"
    local label = (mfr ~= "" and model ~= "") and (mfr .. " " .. model)
                or (mfr ~= "" and mfr) or (model ~= "" and model) or "Unknown Device"
    return hwid, label:sub(1, 80)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- License storage
-- ─────────────────────────────────────────────────────────────────────────────
local function load_saved_license()
    make_dir(LUNEX_ROOT)
    if not file_exists(LICENSE_PATH) then return nil end
    local h = io.open(LICENSE_PATH, "r")
    if not h then return nil end
    local raw = h:read("*a"); h:close()
    local parsed = json.decode(raw)
    if type(parsed) ~= "table" then os.remove(LICENSE_PATH); return nil end
    local lk = trim(parsed.license_key or ""):gsub("%s",""):upper()
    if lk == "" then os.remove(LICENSE_PATH); return nil end
    return lk
end

local function save_license(lk, hwid, label)
    make_dir(LUNEX_ROOT)
    local h = io.open(LICENSE_PATH, "w")
    if not h then return end
    h:write(json.encode({ license_key=trim(lk):gsub("%s",""):upper(), hwid=hwid, device_label=label, saved_at=os.time() }))
    h:close()
end

-- ─────────────────────────────────────────────────────────────────────────────
-- HTTP  (curl)
-- ─────────────────────────────────────────────────────────────────────────────
local function parse_tool_api(spec)
    local key, base, user, pass = spec:match("^([^:]+):(https?://.+):([^:]+):([^:]+)$")
    if not key then error("Invalid LunexToolAPI format") end
    return { key=key, base=base:gsub("/+$",""), username=user, password=pass }
end

local API = parse_tool_api(LUNEX_TOOL_API)

local function http_post(route, payload)
    make_dir(TEMP_ROOT)
    local rp = temp_path("lunex_resp")
    local ep = temp_path("lunex_err")
    local bp = temp_path("lunex_body")

    local bh = io.open(bp, "wb")
    if not bh then return nil, { message = "Server unavailable." } end
    bh:write(json.encode(payload)); bh:close()

    local curl = IS_WIN and "curl.exe" or "curl"
    local cmd  = table.concat({
        curl, "-sS", "--ipv4", "--http1.1",
        "--connect-timeout", "10", "--max-time", "20", "--retry", "2", "--retry-delay", "1",
        "-u",  shell_escape(API.username .. ":" .. API.password),
        "-H",  shell_escape("X-Lunex-Tool-Api-Key: " .. API.key),
        "-H",  shell_escape("Accept: application/json"),
        "-H",  shell_escape("Content-Type: application/json"),
        "-o",  shell_escape(rp),
        "-w",  shell_escape("%{http_code}"),
        "-X",  "POST",
        "--data-binary", shell_escape("@" .. bp),
        shell_escape(API.base .. route),
    }, " ")

    local proc = io.popen(cmd .. " 2>" .. shell_escape(ep))
    local sc   = tonumber((proc and proc:read("*a") or "0"):match("%d+")) or 0
    if proc then proc:close() end

    local body = ""
    local rh = io.open(rp, "r")
    if rh then body = rh:read("*a") or ""; rh:close() end
    os.remove(rp); os.remove(ep); os.remove(bp)

    if sc == 0 then return nil, { message = "Server unavailable." } end
    local parsed = json.decode(body)
    if type(parsed) ~= "table" then parsed = {} end
    return sc, parsed
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Auth calls
-- ─────────────────────────────────────────────────────────────────────────────
local function check_license(lk)
    local sc, r = http_post("/api/termux/license-status", { licenseKey = lk })
    if not sc then return "server", r.message or "Server unavailable." end
    if sc == 200 then return "valid", r.message or "Valid." end
    if (r.code or "") == "UNAUTHORIZED" or sc >= 500 then return "server", r.message or "Server unavailable." end
    return "invalid", r.message or "Invalid."
end

local function auto_login(lk, hwid, label)
    local sc, r = http_post("/api/termux/auto-login", { licenseKey=lk, hwid=hwid, hwidLabel=label })
    if not sc then return "server", r.message or "Server unavailable." end
    if sc == 200 then return "valid", r.message or "Success" end
    if (r.code or "") == "AUTO_LOGIN_FAILED" then return "failed", r.message or "Auto login failed." end
    if (r.code or "") == "UNAUTHORIZED" or sc >= 500 then return "server", r.message or "Server unavailable." end
    return "invalid", r.message or "Invalid."
end

local function validate_code(lk, code, hwid, label)
    local sc, r = http_post("/api/termux/validate", { licenseKey=lk, termuxCode=code, hwid=hwid, hwidLabel=label })
    if not sc then return "server", r.message or "Server unavailable." end
    if sc == 200 then return "valid", r.message or "Success" end
    local rc = r.code or ""
    if rc == "INVALID_LICENSE"    then return "invalid_license",    r.message or "Invalid." end
    if rc == "EXPIRED"            then return "expired",            r.message or "Expired." end
    if rc == "HWID_LIMIT_REACHED" then return "hwid_limit_reached", r.message or "HWID limit reached." end
    if rc == "UNAUTHORIZED" or sc >= 500 then return "server", r.message or "Server unavailable." end
    return "invalid", r.message or "Invalid."
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Main
-- ─────────────────────────────────────────────────────────────────────────────
local function main()
    make_dir(LUNEX_ROOT)
    make_dir(TEMP_ROOT)

    local hwid, device_label = device_identity()
    local saved = load_saved_license()
    local lic_notice = "Waiting for license key."

    -- Try auto-login with saved key
    if saved then
        show_status_screen("Authentication", "Verifying saved session…", nil)
        local status = auto_login(saved, hwid, device_label)
        if status == "valid"  then print_success(); return end
        if status == "server" then
            show_status_screen("Unavailable", "Cannot reach the server. Try again later.", "err"); return
        end
        os.remove(LICENSE_PATH)
        lic_notice = "Saved session expired — please enter your license key again."
    end

    -- License key loop
    while true do
        show_license_screen(lic_notice)
        local lk = prompt("License key"):upper()

        if lk == "" then
            lic_notice = "No license key entered. Please try again."
        else
            show_status_screen("Authentication", "Verifying license key…", nil)
            local lstatus = check_license(lk)

            if lstatus == "server" then
                show_status_screen("Unavailable", "Cannot reach the server. Try again later.", "err"); return
            end

            if lstatus ~= "valid" then
                lic_notice = "That license key was not accepted."
            else
                -- Code verification loop
                local code_notice = "Waiting for Termux code."
                while true do
                    show_code_screen(device_label, code_notice)
                    local code = prompt("Termux code"):upper()

                    if code == "" then
                        code_notice = "No code entered. Please try again."
                    else
                        show_status_screen("Verification", "Checking Termux code…", nil)
                        local vstatus = validate_code(lk, code, hwid, device_label)

                        if vstatus == "server" then
                            show_status_screen("Unavailable", "Cannot reach the server. Try again later, or contact me!", "err"); return
                        end
                        if vstatus == "valid" then
                            save_license(lk, hwid, device_label)
                            print_success(); return
                        end
                        if vstatus == "invalid_license" then
                            os.remove(LICENSE_PATH)
                            lic_notice = "License is no longer valid."
                            break
                        end
                        if vstatus == "expired" then
                            code_notice = "Code expired — run /get-termux-code again."
                        elseif vstatus == "hwid_limit_reached" then
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
    show_status_screen("Error", trim(err), "err")
    print(trim(err))
    os.exit(1)
end
