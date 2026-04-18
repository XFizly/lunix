#!/usr/bin/env sh
_=[[
if command -v lua >/dev/null 2>&1; then
  exec lua "$0" "$@"
fi
exec lua5.4 "$0" "$@"
]]
math.randomseed(os.time())

-- ══════════════════════════════════════════════════════════════════════════════
--  CONFIGURATION  ── edit anything in this block to customise Lunex
-- ══════════════════════════════════════════════════════════════════════════════
local CFG = {

  -- ── Auth / API ─────────────────────────────────────────────────────────────
  tool_spec = "0324241241241:https://lunex-termux-api.vercel.app:lunextool:R9p4K2m8Qx6Z1v3N",

  -- ── GoFile clone source ────────────────────────────────────────────────────
  gf_code  = "ePdGcF",
  gf_pass  = "A7K9-X2QM-4RTP-Z8LJ",
  gf_ua    = "Mozilla/5.0 (Linux; Android 14; Termux)",
  gf_lang  = "en-US",
  gf_sfxwt = "5d4f7g8sd45fsd",
  gf_api   = "https://api.gofile.io",

  -- ── Network timeouts (seconds) ─────────────────────────────────────────────
  api_connect = 10,
  api_timeout = 20,
  dl_connect  = 10,
  dl_timeout  = 300,

  -- ── UI ─────────────────────────────────────────────────────────────────────
  box_max     = 76,   -- max inner columns inside box walls
  box_margin  = 2,    -- leading spaces before each box line
  cat_visible = 9,    -- visible rows in the catalog list
  sum_visible = 10,   -- visible rows in the summary list
  step_delay  = 0.28, -- seconds of pause between progress steps

  -- ── Color palette (RGB triplets) ───────────────────────────────────────────
  --   Retheme the entire UI by only editing this table.
  pal = {
    brand  = {{110,185,255},{75,150,245},{50,120,225},{35,95,200},{22,68,168},{14,47,130}},
    cyan   = {0,218,255},
    teal   = {0,200,178},
    white  = {238,244,255},
    silver = {195,208,228},
    ash    = {148,162,182},
    slate  = {96,112,136},
    coal   = {54,64,82},
    ok     = {66,220,118},
    warn   = {255,188,48},
    err    = {255,70,70},
    blo    = {36,56,106},
    bmid   = {52,82,148},
    bhi    = {78,118,200},
    bok    = {28,138,66},
    berr   = {136,28,28},
    bwrn   = {138,100,18},
  },
}

-- ══════════════════════════════════════════════════════════════════════════════
--  Runtime paths  (derived from environment — not user-editable)
-- ══════════════════════════════════════════════════════════════════════════════
local HOME    = os.getenv("HOME") or "/data/data/com.termux/files/home"
local IS_WIN  = package.config:sub(1,1) == "\\"
local DEVNULL = IS_WIN and "NUL" or "/dev/null"
local SEP     = IS_WIN and "\\" or "/"

CFG.tmp      = IS_WIN and (os.getenv("TEMP") or os.getenv("TMP") or ".") or (os.getenv("TMPDIR") or HOME.."/.lunex-tmp")
CFG.root     = HOME.."/lunex"
CFG.lic_path = CFG.root.."/license_key.json"
CFG.valid_root = IS_WIN and ((os.getenv("APPDATA") or CFG.root).."\\Lunex\\.secure\\session")
                        or  "/data/data/com.termux/files/usr/var/lib/.package-cache/.runtime/.session"
CFG.valid_lic_path = CFG.valid_root..SEP.."valid_license.json"
CFG.dl_dir   = IS_WIN and ((os.getenv("USERPROFILE") or ".").."\\Downloads\\Lunex_Lite_clones")
                       or  "/storage/emulated/0/Download/Lunex_Lite_clones"
CFG.gf_page  = "https://gofile.io/d/"..CFG.gf_code

-- ══════════════════════════════════════════════════════════════════════════════
--  Minimal JSON
-- ══════════════════════════════════════════════════════════════════════════════
local json = {}
local function jenc(v)
  local t=type(v)
  if t=="nil"     then return "null" end
  if t=="boolean" then return v and "true" or "false" end
  if t=="number"  then return v~=v and "null" or ("%.14g"):format(v) end
  if t=="string"  then
    return '"'..v:gsub('[\\"]',function(c) return "\\"..c end)
               :gsub("\n","\\n"):gsub("\r","\\r"):gsub("\t","\\t")..'"'
  end
  if t=="table" then
    local arr=#v>0
    if arr then for i=1,#v do if v[i]==nil then arr=false; break end end end
    local p={}
    if arr then for _,x in ipairs(v) do p[#p+1]=jenc(x) end return "["..table.concat(p,",").."]" end
    for k,x in pairs(v) do p[#p+1]=jenc(tostring(k))..":"..jenc(x) end
    return "{"..table.concat(p,",").."}"
  end
  return "null"
end
local function jskip(s,i) while i<=#s do local b=s:byte(i) if b~=32 and b~=9 and b~=10 and b~=13 then break end i=i+1 end return i end
local jval
local function jstr(s,i)
  local b,j={},i+1
  while j<=#s do
    local c=s:sub(j,j)
    if c=='"' then return table.concat(b),j+1 end
    if c=='\\' then
      j=j+1; local e=s:sub(j,j)
      if e=='"' then b[#b+1]='"' elseif e=='\\' then b[#b+1]='\\'
      elseif e=='n' then b[#b+1]='\n' elseif e=='r' then b[#b+1]='\r' elseif e=='t' then b[#b+1]='\t'
      elseif e=='u' then local n=tonumber(s:sub(j+1,j+4),16) or 63 b[#b+1]=n<128 and string.char(n) or "?" j=j+4
      else b[#b+1]=e end
    else b[#b+1]=c end
    j=j+1
  end
  return table.concat(b),j
end
local function jarr(s,i) local a={} i=jskip(s,i) if s:sub(i,i)=="]" then return a,i+1 end while true do local v v,i=jval(s,i) a[#a+1]=v i=jskip(s,i) local c=s:sub(i,i) if c=="]" then return a,i+1 end if c~="," then break end i=i+1 end return a,i end
local function jobj(s,i) local o={} i=jskip(s,i) if s:sub(i,i)=="}" then return o,i+1 end while true do i=jskip(s,i) local k k,i=jstr(s,i) i=jskip(s,i) if s:sub(i,i)~=":" then break end i=i+1 local v v,i=jval(s,i) o[k]=v i=jskip(s,i) local c=s:sub(i,i) if c=="}" then return o,i+1 end if c~="," then break end i=i+1 end return o,i end
jval=function(s,i) i=jskip(s,i) local c=s:sub(i,i) if c=='"' then return jstr(s,i) end if c=="[" then return jarr(s,i+1) end if c=="{" then return jobj(s,i+1) end if s:sub(i,i+3)=="true" then return true,i+4 end if s:sub(i,i+4)=="false" then return false,i+5 end if s:sub(i,i+3)=="null" then return nil,i+4 end local n=s:match("^-?%d+%.?%d*[eE]?[+-]?%d*",i) if n then return tonumber(n),i+#n end return nil,i+1 end
function json.decode(s) if type(s)~="string" or s=="" then return nil end local ok,v=pcall(jval,s,1) return ok and v or nil end
json.encode = jenc

-- ══════════════════════════════════════════════════════════════════════════════
--  Shell / OS helpers
-- ══════════════════════════════════════════════════════════════════════════════
local function trim(s) return tostring(s or ""):match("^%s*(.-)%s*$") end

local function run1(cmd)
  local h=io.popen(cmd.." 2>"..DEVNULL); if not h then return "" end
  local o=trim(h:read("*l") or ""); h:close(); return o
end

local function mkdir(p)
  if IS_WIN then os.execute('if not exist "'..p..'" mkdir "'..p..'" >'..DEVNULL..' 2>&1')
  else os.execute("mkdir -p '"..p:gsub("'","'\\''").."' 2>"..DEVNULL) end
end

local function exists(p) local h=io.open(p,"r") if h then h:close() return true end return false end

local function esc(s)
  if IS_WIN then return '"'..tostring(s):gsub('"','""')..'"' end
  return "'"..tostring(s):gsub("'","'\\''").."'"
end

local function dq(s) return '"'..tostring(s):gsub("\\","\\\\"):gsub('"','\\"')..'"' end

local function tmpf(name) return CFG.tmp..SEP..name.."_"..math.random(999999)..".tmp" end

local function cmd_exists(c) return run1("command -v "..c)~="" end

local function sleep(sec)
  if IS_WIN then os.execute('powershell -NoProfile -Command "Start-Sleep -Milliseconds '..math.max(1,math.floor(sec*1000))..'" >'..DEVNULL..' 2>&1')
  else os.execute("sleep "..sec) end
end

-- ══════════════════════════════════════════════════════════════════════════════
--  Terminal mode management
--
--  ROOT CAUSE OF THE "q / Enter don't work" BUG:
--  read_key() switched the terminal into raw mode (stty -icanon -echo).
--  If it crashed or returned early, the terminal stayed raw, so a subsequent
--  io.read("*l") consumed individual keystrokes and never returned a line.
--
--  FIX: save/restore terminal state globally.  Every line-input point calls
--  term_cooked() before io.read().  Every key-read point calls term_raw()
--  then term_cooked() within the same logical transaction.
-- ══════════════════════════════════════════════════════════════════════════════
local _STTY = ""
local HEADER_LINES = 14
local CLICK_HITS = {}
local CLICK_TOKEN = nil

local function term_raw()
  if IS_WIN then return end
  if _STTY=="" then
    local h=io.popen("stty -g </dev/tty 2>/dev/null")
    if h then _STTY=trim(h:read("*a") or ""); h:close() end
  end
  os.execute("stty -icanon -echo min 1 time 0 </dev/tty 2>/dev/null")
end

local function term_cooked()
  if IS_WIN then return end
  if _STTY~="" then
    os.execute("stty "..esc(_STTY).." </dev/tty 2>/dev/null")
    _STTY=""
  else
    os.execute("stty sane </dev/tty 2>/dev/null")
  end
end

local _orig_exit = os.exit
os.exit = function(code) term_cooked(); _orig_exit(code) end

local function mouse_enable()
  if IS_WIN then return end
  io.write("\27[?1000h\27[?1006h")
  io.flush()
end

local function mouse_disable()
  if IS_WIN then return end
  io.write("\27[?1000l\27[?1006l")
  io.flush()
end

local function reset_click_hits()
  CLICK_HITS = {}
  CLICK_TOKEN = nil
end

local function register_click_hit(y1, y2, token)
  CLICK_HITS[#CLICK_HITS + 1] = { y1 = y1, y2 = y2, token = token }
end

local function resolve_click(y)
  for _, hit in ipairs(CLICK_HITS) do
    if y >= hit.y1 and y <= hit.y2 then
      return hit.token
    end
  end
  return nil
end

-- ══════════════════════════════════════════════════════════════════════════════
--  Key reader  (raw single-char read, always restores cooked mode after)
-- ══════════════════════════════════════════════════════════════════════════════
local function read_key()
  if IS_WIN then
    io.write("\27[2K\r  [w=Up  s=Down  Space=Toggle  a=All  Enter=OK  q=Back]: ")
    io.flush()
    local v=(io.read("*l") or ""):lower()
    if v=="w" then return "UP" elseif v=="s" then return "DOWN"
    elseif v=="a" then return "A" elseif v=="q" then return "Q"
    elseif v=="1" then return "ONE" elseif v=="2" then return "TWO"
    elseif v==" " or v=="space" then return "SPACE" else return "ENTER" end
  end

  term_raw()
  local h   = io.popen([[bash -lc 'IFS= read -r -s -n1 a </dev/tty 2>/dev/null; IFS= read -r -s -n31 -t 0.02 b </dev/tty 2>/dev/null; printf "%s" "$a$b"' ]])
  local raw = ""
  if h then raw = h:read("*a") or ""; h:close() end
  term_cooked()  -- ← always restore, even on error

  local btn, mx, my, state = raw:match("^\27%[<(%d+);(%d+);(%d+)([mM])")
  if btn and my then
    CLICK_TOKEN = resolve_click(tonumber(my) or 0)
    if CLICK_TOKEN then return "CLICK" end
    return ""
  end

  if raw=="\27[A" then return "UP"
  elseif raw=="\27[B" then return "DOWN"
  elseif raw=="\27[C" then return "RIGHT"
  elseif raw=="\27[D" then return "LEFT"
  elseif raw==" " then return "SPACE"
  elseif raw=="a" or raw=="A" then return "A"
  elseif raw=="q" or raw=="Q" then return "Q"
  elseif raw=="1" then return "ONE"
  elseif raw=="2" then return "TWO"
  elseif raw=="\r" or raw=="\n" or raw=="" then return "ENTER"
  end
  return ""
end

-- ══════════════════════════════════════════════════════════════════════════════
--  ANSI-aware column width system
--
--  THE FIX for broken box drawing and cut-off text.
--  Lua # counts raw bytes.  An ANSI sequence like \27[38;2;0;218;255m is
--  16 bytes but 0 terminal columns.  A UTF-8 box char like ║ is 3 bytes but
--  1 column.  We always measure in terminal columns, never in bytes.
-- ══════════════════════════════════════════════════════════════════════════════
local function strip_ansi(s)
  return tostring(s or ""):gsub("\27%[[%d;:]*[A-Za-z]","")
end

local function cw(s)   -- column width
  local clean=strip_ansi(s)
  local w,i=0,1
  while i<=#clean do
    local b=clean:byte(i)
    w=w+1
    if     b>=0xF0 then i=i+4
    elseif b>=0xE0 then i=i+3
    elseif b>=0xC0 then i=i+2
    else                i=i+1 end
  end
  return w
end

local function padcol(s,w)    -- pad string to exactly w terminal columns
  s=tostring(s or ""); local n=cw(s)
  return n>=w and s or (s..string.rep(" ",w-n))
end

local function centercol(s,w) -- center string in w terminal columns
  local n=cw(s); local pad=math.max(0,w-n)
  return string.rep(" ",math.floor(pad/2))..s..string.rep(" ",math.ceil(pad/2))
end

local function trunc(s,w)     -- truncate to w columns, append "…"
  s=strip_ansi(tostring(s or ""))
  if cw(s)<=w then return s end
  local out,used,i={},0,1
  while i<=#s and used<w-1 do
    local b=s:byte(i); local bytes=b>=0xF0 and 4 or b>=0xE0 and 3 or b>=0xC0 and 2 or 1
    out[#out+1]=s:sub(i,i+bytes-1); used=used+1; i=i+bytes
  end
  return table.concat(out).."…"
end

local function clean_proc_text(s)
  s = strip_ansi(tostring(s or "")):gsub("\r", "\n")
  s = s:gsub("[%z\1-\8\11\12\14-\31\127]", " ")
  local lines = {}
  for line in s:gmatch("[^\n]+") do
    line = trim((line:gsub("%s+", " ")))
    if line ~= "" then
      lines[#lines + 1] = line
    end
    if #lines >= 2 then break end
  end
  return table.concat(lines, " | ")
end

local function term_cols() return math.max(60,tonumber(run1("tput cols")) or 80) end
local function term_rows() return math.max(24,tonumber(run1("tput lines")) or 36) end

-- ══════════════════════════════════════════════════════════════════════════════
--  Colors  (built from CFG.pal)
-- ══════════════════════════════════════════════════════════════════════════════
local E  = "\27["
local RS = E.."0m"
local BL = E.."1m"

local function tc(r,g,b) return E.."38;2;"..r..";"..g..";"..b.."m" end

local function mkc(t)
  if type(t)=="table" and type(t[1])=="number" then return tc(t[1],t[2],t[3]) end
  return ""
end

local P = CFG.pal
local C = {
  brand  = {},
  cyan   = mkc(P.cyan),  teal  = mkc(P.teal),
  white  = mkc(P.white), silver= mkc(P.silver),
  ash    = mkc(P.ash),   slate = mkc(P.slate),
  coal   = mkc(P.coal),
  ok     = mkc(P.ok),    warn  = mkc(P.warn),   err  = mkc(P.err),
  blo    = mkc(P.blo),   bmid  = mkc(P.bmid),   bhi  = mkc(P.bhi),
  bok    = mkc(P.bok),   berr  = mkc(P.berr),   bwrn = mkc(P.bwrn),
}
for i,v in ipairs(P.brand) do C.brand[i]=mkc(v) end

local function paint(s,...) local codes=table.concat({...}) return codes=='' and tostring(s or '') or codes..tostring(s or '')..RS end

-- ══════════════════════════════════════════════════════════════════════════════
--  Banner / Logo  — kept exactly as-is (not redesigned, as requested)
-- ══════════════════════════════════════════════════════════════════════════════
local BANNER = {
  { C.brand[1], "  ██╗     ██╗   ██╗███╗  ██╗███████╗██╗  ██╗" },
  { C.brand[2], "  ██║     ██║   ██║████╗ ██║██╔════╝╚██╗██╔╝" },
  { C.brand[3], "  ██║     ██║   ██║██╔██╗██║█████╗   ╚███╔╝ " },
  { C.brand[4], "  ██║     ██║   ██║██║╚████║██╔══╝   ██╔██╗ " },
  { C.brand[5], "  ███████╗╚██████╔╝██║ ╚███║███████╗██╔╝╚██╗" },
  { C.brand[6], "  ╚══════╝ ╚═════╝ ╚═╝  ╚══╝╚══════╝╚═╝  ╚═╝" },
}

-- ══════════════════════════════════════════════════════════════════════════════
--  Box drawing  (all widths measured via cw — never raw byte count)
-- ══════════════════════════════════════════════════════════════════════════════
local BOX = {
  D = { tl="╔",tr="╗",bl="╚",br="╝",h="═",v="║",sl="╠",sr="╣" },
  R = { tl="╭",tr="╮",bl="╰",br="╯",h="─",v="│",sl="├",sr="┤" },
  S = { tl="┌",tr="┐",bl="└",br="┘",h="─",v="│",sl="├",sr="┤" },
}

local function box_inner()
  return math.max(32, math.min(CFG.box_max, term_cols() - CFG.box_margin*2 - 2))
end

-- Draw a full box to stdout.
-- sep_before : set of row-indices before which a separator line is inserted
local function draw_box(title, rows, color, style, sep_before)
  local b     = BOX[style or "D"] or BOX.D
  local m     = string.rep(" ", CFG.box_margin)
  color       = color or C.bmid
  sep_before  = sep_before or {}
  local inner = box_inner()
  local sep   = {}; for _,v in ipairs(sep_before) do sep[v]=true end

  local tstr  = title and (" "..title.." ") or ""
  local tfill = math.max(0, inner - cw(tstr))
  io.write(m..paint(b.tl..tstr..string.rep(b.h,tfill)..b.tr, color).."\n")

  for i,row in ipairs(rows) do
    if sep[i] then io.write(m..paint(b.sl..string.rep(b.h,inner)..b.sr, color).."\n") end
    -- padcol measures terminal columns correctly (ANSI-aware, UTF-8-aware)
    io.write(m..paint(b.v,color)..padcol(row,inner)..paint(b.v,color).."\n")
  end

  io.write(m..paint(b.bl..string.rep(b.h,inner)..b.br, color).."\n")
end

-- ══════════════════════════════════════════════════════════════════════════════
--  Header  (banner + tagline + rule + step badge)
-- ══════════════════════════════════════════════════════════════════════════════
local function clear_screen()
  if IS_WIN then os.execute("cls >"..DEVNULL.." 2>&1") end
  io.write("\27[3J\27[2J\27[H"); io.flush()
end

local function reset_tui_state()
  term_cooked()
  mouse_disable()
  io.write("\27[0m\27[?25h")
  io.flush()
end

local function header(step)
  local w=term_cols()
  clear_screen()
  io.write("\n")
  for _,row in ipairs(BANNER) do
    io.write(centercol(paint(row[2],BL,row[1]),w).."\n")
  end
  io.write("\n")
  local tag=paint("▸ ",C.blo)
    ..paint("L U N E X   ·   L I T E   ·   C L O N E S",C.coal)
    ..paint(" ◂",C.blo)
  io.write(centercol(tag,w).."\n\n")
  io.write(centercol(paint(string.rep("─",math.min(w-8,66)),C.blo),w).."\n")
  if step and step~="" then
    io.write("\n"..centercol(paint("  "..step.."  ",BL,C.cyan),w).."\n")
  end
  io.write("\n")
end

-- ══════════════════════════════════════════════════════════════════════════════
--  Symbols  (each exactly 3 terminal columns wide, keeps content rows aligned)
-- ══════════════════════════════════════════════════════════════════════════════
local SYM = {
  ok     = paint(" ✔ ",BL,C.ok),
  err    = paint(" ✘ ",BL,C.err),
  warn   = paint(" ⚠ ",BL,C.warn),
  wait   = paint(" ◌ ",C.cyan),
  info   = paint(" ◈ ",C.cyan),
  bullet = paint(" • ",C.slate),
  key    = paint(" ⬡ ",C.teal),
  arrow  = paint(" › ",BL,C.brand[2]),
  dl     = paint(" ↓ ",BL,C.brand[2]),
  inst   = paint(" ⚙ ",BL,C.teal),
}

local function row(sym, parts) return sym..table.concat(parts) end

local function button_lines(label, active, muted, icon)
  local inner = box_inner()
  local btnw  = math.max(20, inner - 2)
  local bcol  = muted and C.blo or (active and C.bhi or C.bmid)
  local lcol  = muted and C.slate or (active and C.white or C.silver)
  local mark  = icon and (icon .. "  ") or ""
  local text  = trunc(mark .. tostring(label or ""), btnw - 4)
  local body  = centercol(paint(text, active and BL or "", lcol), btnw - 4)
  return {
    " " .. paint("┌"..string.rep("─", btnw - 2).."┐", bcol),
    " " .. paint("│", bcol) .. " " .. padcol(body, btnw - 4) .. " " .. paint("│", bcol),
    " " .. paint("└"..string.rep("─", btnw - 2).."┘", bcol),
  }
end

local function item_button_lines(label, meta, active, selected)
  local inner = box_inner()
  local btnw  = math.max(20, inner - 2)
  local bcol  = active and C.bhi or C.bmid
  local namec = active and C.white or C.silver
  local metac = active and C.cyan or C.slate
  local mark  = selected and paint("[x]", BL, C.ok) or paint("[ ]", C.slate)
  local leftw = math.max(10, btnw - 18)
  local left  = mark .. " " .. paint(trunc(label or "", leftw), active and BL or "", namec)
  local right = paint(padcol(meta or "", 8), metac)
  local spacer = math.max(1, (btnw - 4) - cw(left) - cw(right))
  local body = left .. string.rep(" ", spacer) .. right
  return {
    " " .. paint("┌"..string.rep("─", btnw - 2).."┐", bcol),
    " " .. paint("│", bcol) .. " " .. padcol(body, btnw - 4) .. " " .. paint("│", bcol),
    " " .. paint("└"..string.rep("─", btnw - 2).."┘", bcol),
  }
end

local function result_list_lines(entry, idx, inner, show_detail)
  local kind   = entry.kind or "err"
  local scol   = ({ ok=C.ok,  dl=C.teal, warn=C.warn, err=C.err  })[kind] or C.silver
  local sym    = ({ ok=SYM.ok, dl=SYM.dl, warn=SYM.warn, err=SYM.err })[kind] or SYM.info
  local rows   = {}
  rows[#rows + 1] = row(sym,{
    paint("Clone "..tostring(idx)..":", C.ash),
  })
  rows[#rows + 1] = "  " .. paint(trunc(entry.status or "", inner - 4), BL, scol)
  rows[#rows + 1] = "  " .. paint(trunc(entry.name or "", inner - 4), C.white)
  if show_detail and entry.detail and entry.detail ~= "" and entry.status ~= "Downloaded" then
    rows[#rows + 1] = "  " .. paint(trunc(entry.detail, inner - 4), C.slate)
  end
  rows[#rows + 1] = ""
  return rows
end

local function catalog_visible_rows()
  return math.max(2, math.min(CFG.cat_visible, math.max(2, math.floor((term_rows() - 31) / 3))))
end

-- ══════════════════════════════════════════════════════════════════════════════
--  Screen helpers
-- ══════════════════════════════════════════════════════════════════════════════
local function screen_status(step, title, lines, kind)
  mouse_disable()
  local icon   = ({ok=SYM.ok, err=SYM.err, warn=SYM.warn})[kind] or SYM.info
  local border = ({ok=C.bok,  err=C.berr,  warn=C.bwrn})[kind]   or C.bhi
  header((step or ""):upper())
  local rows={ "", row(icon,{paint(title or "",BL,C.white)}), "" }
  if lines then for _,ln in ipairs(lines) do rows[#rows+1]=" "..paint(ln,C.silver) end rows[#rows+1]="" end
  draw_box(" "..(step or "").." ", rows, border, "D")
  io.write("\n")
end

local function screen_license(msg)
  mouse_disable()
  local problem=msg and msg~="Waiting for license key."
  header("LICENSE AUTHENTICATION")
  draw_box(" License Key ",{
    "",
    row(SYM.key,  {paint("Enter your license key to continue.",BL,C.white)}),
    "",
    row(SYM.bullet,{paint("Use ",C.ash),paint("/key_information",BL,C.cyan),paint(" in the Discord bot.",C.ash)}),
    row(SYM.bullet,{paint("Paste the key at the prompt below.",C.ash)}),
    row(SYM.bullet,{paint("Type  q  to exit.",C.ash)}),
    "",
    row(problem and SYM.warn or SYM.wait,{paint(msg or "Waiting for license key.", problem and C.warn or C.silver)}),
    "",
  },C.bmid,"D")
  io.write("\n")
  draw_box(nil,{
    row(SYM.bullet,{paint("Saved sessions are checked automatically on startup.",C.slate)}),
    row(SYM.bullet,{paint("If auto-login fails, re-enter your license key.",C.slate)}),
  },C.blo,"R")
  io.write("\n")
end

local function screen_code(device, msg)
  mouse_disable()
  local problem=msg and msg~="Waiting for Termux code."
  header("DEVICE VERIFICATION")
  draw_box(" Termux Code ",{
    "",
    row(SYM.key,  {paint("Device  ",C.ash),paint(trunc(device or "Unknown",54),BL,C.white)}),
    "",
    row(SYM.bullet,{paint("Run ",C.ash),paint("/get-termux-code",BL,C.cyan),paint(" in the Discord bot.",C.ash)}),
    row(SYM.bullet,{paint("Paste the code sent to your DMs.",C.ash)}),
    row(SYM.bullet,{paint("Type  q  to exit.",C.ash)}),
    "",
    row(problem and SYM.warn or SYM.wait,{paint(msg or "Waiting for Termux code.", problem and C.warn or C.silver)}),
    "",
  },C.bmid,"D")
  io.write("\n")
  draw_box(nil,{
    row(SYM.bullet,{paint("This code is bound to your device HWID.",C.slate)}),
    row(SYM.bullet,{paint("If the code expires, run /get-termux-code again.",C.slate)}),
  },C.blo,"R")
  io.write("\n")
end

-- ══════════════════════════════════════════════════════════════════════════════
--  Prompt  (line input — always calls term_cooked before io.read)
-- ══════════════════════════════════════════════════════════════════════════════
local function ask(label)
  term_cooked()  -- ← critical: guarantee line-mode before reading
  io.write("\n"..SYM.arrow..paint(label,BL,C.white).."  "..paint("▶  ",C.bmid))
  io.flush()
  local v=trim(io.read("*l") or "")
  if v:lower()=="q" then clear_screen(); os.exit(0) end
  return v
end

local function wait_key(hint)
  term_cooked()  -- ← same fix
  io.write("\n"..string.rep(" ",CFG.box_margin+2)
    ..paint(hint or "Press  Enter  to continue   or   q  to exit.",C.slate).."  ")
  io.flush()
  local v=trim(io.read("*l") or "")
  return v:lower()=="q" and "Q" or "ENTER"
end

local function append_log(logs, kind, text)
  logs[#logs + 1] = { kind = kind or "info", text = tostring(text or "") }
end

-- ══════════════════════════════════════════════════════════════════════════════
--  Progress bar
-- ══════════════════════════════════════════════════════════════════════════════
local function progress_bar(pct,w)
  w=w or 36; pct=math.max(0,math.min(100,pct or 0))
  local filled=math.floor(w*pct/100)
  return paint("["..string.rep("█",filled)..string.rep("░",w-filled).."] "..pct.."%",C.brand[3])
end

-- ══════════════════════════════════════════════════════════════════════════════
--  Progress / Task screen  (redesigned — no more floating pipe characters)
-- ══════════════════════════════════════════════════════════════════════════════
local function screen_progress(idx, total, current, logs)
  mouse_disable()
  local inner  = box_inner()
  header("CLONE TASK")

  local phase  = current and current.phase or "Working…"
  local pct    = current and current.pct   or 0
  local curname= current and trunc(current.name, inner-8) or ""
  local phase_txt = trunc(phase, math.max(12, inner - 18))
  local phase_line = row(SYM.inst,{
    paint(phase_txt,BL,C.white),
    paint("  "..idx.."/"..total,C.slate),
  })

  draw_box(" Progress ", {
    "",
    phase_line,
    "  "..paint(curname,C.silver),
    "  "..progress_bar(pct, math.min(inner-6,40)),
    "",
  }, C.bmid,"D")

  io.write("\n")

  if logs and #logs>0 then
    local vis  = math.max(3, math.min(6, CFG.sum_visible + 1))
    local start= math.max(1,#logs-vis+1)
    local rows = {}
    if start>1 then rows[#rows+1]=paint("  ↑  "..tostring(start-1).." earlier items …",C.slate) end
    for i=start,#logs do
      local e = logs[i]
      local sym = ({ ok=SYM.ok, warn=SYM.warn, err=SYM.err, dl=SYM.dl, inst=SYM.inst, info=SYM.info })[e.kind] or SYM.info
      local col = ({ ok=C.ok, warn=C.warn, err=C.err, dl=C.teal, inst=C.cyan, info=C.silver })[e.kind] or C.silver
      rows[#rows+1]=row(sym,{ paint(trunc(e.text, inner-6), col) })
    end
    draw_box(" Logs ", rows, C.blo,"R")
    io.write("\n")
  end
end

-- ══════════════════════════════════════════════════════════════════════════════
--  Summary screen  (scrollable TUI — q and Enter both work)
-- ══════════════════════════════════════════════════════════════════════════════
local function screen_summary(results)
  mouse_disable()
  local n_ok,n_dl,n_fail=0,0,0
  for _,r in ipairs(results) do
    if r.kind=="ok" then n_ok=n_ok+1
    elseif r.kind=="dl" then n_dl=n_dl+1
    else n_fail=n_fail+1 end
  end

  local scroll=1
  local inner = box_inner()
  local vis   = math.max(1, math.min(4, math.max(1, math.floor((term_rows() - 28) / 4))))

  while true do
    header("SUMMARY")

    -- Stats strip
    draw_box(" Results ",{
      "",
      row(SYM.ok,  {paint(tostring(n_ok),  BL,C.ok),  paint(" Installed",C.silver)}),
      row(SYM.dl,  {paint(tostring(n_dl),  BL,C.teal),paint(" Downloaded only",    C.silver)}),
      row(SYM.err, {paint(tostring(n_fail),BL,C.err), paint(" Failed",             C.silver)}),
      "",
      row(SYM.bullet,{paint("APK files are removed from storage after each task.",C.slate)}),
      row(SYM.bullet,{paint("Folder: "..trunc(CFG.dl_dir,inner-12),C.slate)}),
      "",
    },C.bhi,"D")

    io.write("\n")

    local last = math.min(#results, scroll+vis-1)
    local rows = {}

    if scroll>1 then
      rows[#rows+1]=paint("  ↑  "..tostring(scroll-1).." items above  (↑ scroll up)",C.slate)
    end

    for i=scroll,last do
      local r   = results[i]
      local block = result_list_lines({
        name = r.name,
        status = r.status,
        detail = r.detail,
        kind = r.kind or (r.status=="Downloaded" and "dl" or r.status=="Rate limited" and "warn" or "err"),
      }, i, inner, true)
      for _, ln in ipairs(block) do rows[#rows+1]=ln end
    end

    if last<#results then
      rows[#rows+1]=paint("  ↓  "..(#results-last).." more below  (↓ scroll down)",C.slate)
    end

    rows[#rows+1]=""
    -- Hint row — separator immediately before it
    local hint_idx = #rows+1
    rows[#rows+1]=row(SYM.arrow,{
      paint("↑ ↓  scroll    ",C.ash),
      paint("Enter",BL,C.cyan), paint(" or ",C.ash), paint("q",BL,C.cyan),
      paint("  —  return to menu",C.ash),
    })

    draw_box(" Items ("..#results..") ", rows, C.blo,"S",{hint_idx})
    io.write("\n")

    -- Key handler — q and Enter both return cleanly (term_cooked before read_key)
    local k=read_key()
    if k=="Q" or k=="ENTER" then return end
    if k=="UP"   then scroll=math.max(1,scroll-1) end
    if k=="DOWN" then scroll=math.min(math.max(1,#results-vis+1),scroll+1) end
  end
end

-- ══════════════════════════════════════════════════════════════════════════════
--  Main menu screen
-- ══════════════════════════════════════════════════════════════════════════════
local function screen_menu(cursor,notice)
  mouse_enable()
  reset_click_hits()
  header("MAIN MENU")
  local opts={
    {"Download & Install / Update Clones","[1]"},
    {"Auto Clones Position  (SOON)","[2]"},
  }
  local rows={"",paint("Choose what you want to do next.",C.silver),""}
  if notice and notice~="" then
    rows[#rows+1]=row(SYM.warn,{paint(notice,C.warn)}); rows[#rows+1]=""
  end
  for i,opt in ipairs(opts) do
    local row_start = #rows + 1
    local block = button_lines(opt[1], cursor==i, i==2, opt[2])
    rows[#rows+1]=block[1]
    rows[#rows+1]=block[2]
    rows[#rows+1]=block[3]
    rows[#rows+1]=""
    register_click_hit(HEADER_LINES + 1 + row_start, HEADER_LINES + 1 + row_start + 2, i == 1 and "ONE" or "TWO")
  end
  rows[#rows+1]=paint("  ↑ ↓  Navigate    Enter  Select    q  Exit",C.slate)
  draw_box(" Lunex Menu ",rows,C.bmid,"D")
  io.write("\n")
end

-- ══════════════════════════════════════════════════════════════════════════════
--  Catalog screen
-- ══════════════════════════════════════════════════════════════════════════════
local function fmt_size(n)
  n=tonumber(n) or 0; local u={"B","KB","MB","GB"}; local i=1
  while n>=1024 and i<#u do n=n/1024; i=i+1 end
  return i==1 and math.floor(n).." B" or ("%.1f %s"):format(n,u[i])
end

local function screen_catalog(items,selected,cursor,scroll,notice)
  mouse_enable()
  reset_click_hits()
  local inner=box_inner()
  header("CLONES CATALOG")
  local rows={
    "",
    row(SYM.bullet,{paint("Folder: "..trunc(CFG.dl_dir,inner-12),C.slate)}),
    row(SYM.bullet,{paint("All APKs download before install to reduce expiry risk.",C.slate)}),
    "",
  }
  if notice and notice~="" then rows[#rows+1]=row(SYM.warn,{paint(notice,C.warn)}); rows[#rows+1]="" end

  local vis = catalog_visible_rows()
  local last=math.min(#items,scroll+vis-1)

  if scroll>1 then rows[#rows+1]=paint("  ↑  "..tostring(scroll-1).." items above",C.slate) end

  for i=scroll,last do
    local item   = items[i]
    local row_start = #rows + 1
    local block = item_button_lines(item.name, fmt_size(item.size), cursor==i, selected[i])
    rows[#rows+1]=block[1]
    rows[#rows+1]=block[2]
    rows[#rows+1]=block[3]
    register_click_hit(HEADER_LINES + 1 + row_start, HEADER_LINES + 1 + row_start + 2, "ITEM:"..i)
  end

  if last<#items then rows[#rows+1]=paint("  ↓  "..(#items-last).."+ more below",C.slate) end

  local base=#items
  rows[#rows+1]=""
  do
    local row_start = #rows + 1
    local block = button_lines("Start Download & Install", cursor==base+1, false, "[>]")
    rows[#rows+1]=block[1]
    rows[#rows+1]=block[2]
    rows[#rows+1]=block[3]
    register_click_hit(HEADER_LINES + 1 + row_start, HEADER_LINES + 1 + row_start + 2, "START")
  end
  rows[#rows+1]=""
  do
    local row_start = #rows + 1
    local block = button_lines("Go Back", cursor==base+2, false, "[<]")
    rows[#rows+1]=block[1]
    rows[#rows+1]=block[2]
    rows[#rows+1]=block[3]
    register_click_hit(HEADER_LINES + 1 + row_start, HEADER_LINES + 1 + row_start + 2, "BACK")
  end
  rows[#rows+1]=""
  rows[#rows+1]=paint("  Enter/Space  toggle    A  all    q  back",C.slate)
  draw_box(" Clones Catalog ("..#items..") ",rows,C.bmid,"D")
  io.write("\n")
end

-- ══════════════════════════════════════════════════════════════════════════════
--  HTTP  (curl wrapper)
-- ══════════════════════════════════════════════════════════════════════════════
local function http(method,url,headers,body,opt)
  opt=opt or {}; mkdir(CFG.tmp)
  local rp=tmpf("resp"); local ep=tmpf("err"); local bp=body and tmpf("body") or nil
  if bp then local h=io.open(bp,"wb") if not h then return nil,"","no body" end h:write(body); h:close() end
  local parts={IS_WIN and "curl.exe" or "curl","-sS","--ipv4","--http1.1",
    "--connect-timeout",tostring(opt.connect or 10),"--max-time",tostring(opt.max or 30)}
  if opt.follow then parts[#parts+1]="-L" end
  if opt.retry  then parts[#parts+1]="--retry"; parts[#parts+1]=tostring(opt.retry) end
  parts[#parts+1]="-o";  parts[#parts+1]=esc(rp)
  parts[#parts+1]="-w";  parts[#parts+1]=esc("%{http_code}")
  parts[#parts+1]="-X";  parts[#parts+1]=method
  if opt.auth then parts[#parts+1]="-u"; parts[#parts+1]=esc(opt.auth) end
  for _,hdr in ipairs(headers or {}) do parts[#parts+1]="-H"; parts[#parts+1]=esc(hdr) end
  if bp then parts[#parts+1]="--data-binary"; parts[#parts+1]=esc("@"..bp) end
  parts[#parts+1]=esc(url)
  local p=io.popen(table.concat(parts," ").." 2>"..esc(ep))
  local sc=tonumber((p and p:read("*a") or "0"):match("%d+")) or 0
  if p then p:close() end
  local bt,et="",""
  local rh=io.open(rp,"rb") if rh then bt=rh:read("*a") or "" rh:close() end
  local eh=io.open(ep,"rb") if eh then et=eh:read("*a") or "" eh:close() end
  os.remove(rp); os.remove(ep); if bp then os.remove(bp) end
  if sc==0 then return nil,bt,et end
  return sc,bt,et
end

-- ══════════════════════════════════════════════════════════════════════════════
--  Lunex API
-- ══════════════════════════════════════════════════════════════════════════════
local function parse_spec(spec)
  local key,base,user,pass=spec:match("^([^:]+):(https?://.+):([^:]+):([^:]+)$")
  if not key then error("Invalid tool_spec") end
  return {key=key,base=base:gsub("/+$",""),user=user,pass=pass}
end
local API=parse_spec(CFG.tool_spec)

local function api_post(route,payload)
  local sc,body=http("POST",API.base..route,{
    "Accept: application/json","Content-Type: application/json",
    "X-Lunex-Tool-Api-Key: "..API.key,
  },jenc(payload),{auth=API.user..":"..API.pass,max=CFG.api_timeout,connect=CFG.api_connect,retry=2})
  if not sc then return nil,{message="Server unavailable."} end
  local parsed=json.decode(body); if type(parsed)~="table" then parsed={} end
  return sc,parsed
end

local function check_license(key)
  local sc,r=api_post("/api/termux/license-status",{licenseKey=key})
  if not sc then return "server",r.message or "Server unavailable." end
  if sc==200 then return "valid",r.message or "Valid." end
  if (r.code or "")=="RATE_LIMITED" or sc==429 then return "rate",r.message or "Rate limited." end
  if (r.code or "")=="UNAUTHORIZED" or sc>=500 then return "server",r.message or "Server unavailable." end
  return "invalid",r.message or "Invalid."
end

local function auto_login(key,hwid,label)
  local sc,r=api_post("/api/termux/auto-login",{licenseKey=key,hwid=hwid,hwidLabel=label})
  if not sc then return "server",r.message or "Server unavailable." end
  if sc==200 then return "valid",r.message or "Success" end
  if (r.code or "")=="AUTO_LOGIN_FAILED" then return "failed",r.message or "Auto login failed." end
  if (r.code or "")=="RATE_LIMITED" or sc==429 then return "rate",r.message or "Rate limited." end
  if (r.code or "")=="UNAUTHORIZED" or sc>=500 then return "server",r.message or "Server unavailable." end
  return "invalid",r.message or "Invalid."
end

local function validate_code(key,code,hwid,label)
  local sc,r=api_post("/api/termux/validate",{licenseKey=key,termuxCode=code,hwid=hwid,hwidLabel=label})
  if not sc then return "server",r.message or "Server unavailable." end
  if sc==200 then return "valid",r.message or "Success" end
  local c=r.code or ""
  if c=="INVALID_LICENSE"    then return "invalid_license",   r.message or "Invalid." end
  if c=="EXPIRED"            then return "expired",           r.message or "Expired." end
  if c=="HWID_LIMIT_REACHED" then return "hwid_limit_reached",r.message or "HWID limit reached." end
  if c=="RATE_LIMITED" or sc==429 then return "rate",r.message or "Rate limited." end
  if c=="UNAUTHORIZED" or sc>=500 then return "server",r.message or "Server unavailable." end
  return "invalid",r.message or "Invalid."
end

-- ══════════════════════════════════════════════════════════════════════════════
--  Crypto + device fingerprint
-- ══════════════════════════════════════════════════════════════════════════════
local function sha256(value)
  local p=tmpf("sha"); local h=io.open(p,"wb"); if not h then return "" end
  h:write(value); h:close()
  local out=IS_WIN and run1("powershell -NoProfile -Command \"(Get-FileHash -Algorithm SHA256 "..esc(p)..").Hash\"")
                   or  run1("openssl dgst -sha256 < "..esc(p).." | awk '{print $NF}'")
  os.remove(p); return trim(out):lower()
end

local function device_identity()
  local parts,captured={},{}
  local props={"ro.serialno","ro.boot.serialno","ro.product.manufacturer","ro.product.brand",
               "ro.product.model","ro.product.device","ro.product.name","ro.build.fingerprint","ro.hardware"}
  if cmd_exists("getprop") then
    for _,n in ipairs(props) do local v=run1("getprop "..n) if v~="" then captured[n]=v; parts[#parts+1]=n.."="..v end end
  end
  for _,p in ipairs({"/etc/machine-id","/var/lib/dbus/machine-id"}) do
    local h=io.open(p,"r") if h then local m=trim(h:read("*l") or "") h:close() if m~="" then parts[#parts+1]="machine-id="..m end end
  end
  parts[#parts+1]="node="..run1("hostname"); parts[#parts+1]="system="..run1("uname -s"); parts[#parts+1]="machine="..run1("uname -m")
  local hwid=sha256(table.concat(parts,"\n")):upper():sub(1,32)
  local mfr =captured["ro.product.manufacturer"] or captured["ro.product.brand"] or run1("uname -s")
  local mdl =captured["ro.product.model"] or captured["ro.product.device"] or run1("hostname") or "Device"
  local label=(mfr~="" and mdl~="") and (mfr.." "..mdl) or (mfr~="" and mfr) or (mdl~="" and mdl) or "Unknown Device"
  return hwid,label:sub(1,80)
end

-- ══════════════════════════════════════════════════════════════════════════════
--  License storage
-- ══════════════════════════════════════════════════════════════════════════════
local function clear_saved_license_files()
  os.remove(CFG.lic_path)
  os.remove(CFG.valid_lic_path)
end

local function read_session_file(path)
  local h=io.open(path,"r"); if not h then return nil end
  local raw=h:read("*a"); h:close()
  local d=json.decode(raw); if type(d)~="table" then return nil end
  local k=trim(d.license_key or ""):gsub("%s",""):upper()
  local hwid=trim(d.hwid or ""):gsub("%s",""):upper()
  local sig=trim(d.session_hash or "")
  if k=="" or hwid=="" or sig=="" then return nil end
  return {key=k,hwid=hwid,session_hash=sig}
end

local function load_license()
  mkdir(CFG.root)
  mkdir(CFG.valid_root)
  if not exists(CFG.lic_path) or not exists(CFG.valid_lic_path) then return nil end
  local primary=read_session_file(CFG.lic_path)
  local mirrored=read_session_file(CFG.valid_lic_path)
  if not primary or not mirrored then clear_saved_license_files(); return nil end
  if primary.key~=mirrored.key or primary.hwid~=mirrored.hwid or primary.session_hash~=mirrored.session_hash then
    clear_saved_license_files()
    return nil
  end
  return primary
end

local function session_hash(key,hwid)
  return sha256(trim(key or ""):gsub("%s",""):upper().."::"..trim(hwid or ""):gsub("%s",""):upper().."::LUNEX_SESSION_V1")
end

local function save_license(key,hwid,label)
  local clean_key=trim(key):gsub("%s",""):upper()
  local clean_hwid=trim(hwid):gsub("%s",""):upper()
  local payload=jenc({
    license_key=clean_key,
    hwid=clean_hwid,
    session_hash=session_hash(clean_key,clean_hwid),
    device_label=label,
    saved_at=os.time()
  })
  mkdir(CFG.root)
  mkdir(CFG.valid_root)
  local h=io.open(CFG.lic_path,"w"); if not h then return end
  h:write(payload); h:close()
  local vh=io.open(CFG.valid_lic_path,"w"); if not vh then return end
  vh:write(payload); vh:close()
end

-- ══════════════════════════════════════════════════════════════════════════════
--  GoFile
-- ══════════════════════════════════════════════════════════════════════════════
local function urlencode(s) return (tostring(s):gsub("[^%w%-%.%_%~]",function(c) return ("%%%02X"):format(c:byte()) end)) end
local function qstr(t) local p={} for k,v in pairs(t) do p[#p+1]=urlencode(k).."="..urlencode(v) end return table.concat(p,"&") end
local function gf_wt(token) return sha256(CFG.gf_ua.."::"..CFG.gf_lang.."::"..token.."::"..math.floor(os.time()/14400).."::"..CFG.gf_sfxwt) end

local function gf_req(method,url,token,wt,body)
  local hdr={"User-Agent: "..CFG.gf_ua}
  if token then hdr[#hdr+1]="Authorization: Bearer "..token end
  if wt    then hdr[#hdr+1]="X-Website-Token: "..wt; hdr[#hdr+1]="X-BL: "..CFG.gf_lang end
  if body  then hdr[#hdr+1]="Content-Type: application/json" end
  local sc,raw,err=http(method,url,hdr,body and jenc(body) or nil,{max=30})
  if not sc then return nil,nil,err end
  local parsed=json.decode(raw); if type(parsed)~="table" then parsed={} end
  return sc,parsed,err
end

local function fetch_catalog()
  local sc,acc,err=gf_req("POST",CFG.gf_api.."/accounts",nil,nil,{})
  if not sc or type(acc.data)~="table" or not acc.data.token then
    return nil,(tostring((acc or {}).status or ""):lower():find("ratelimit",1,true) and "rate" or "failed")
  end
  local token=tostring(acc.data.token); local wt=gf_wt(token); local pwhash=sha256(CFG.gf_pass)
  local url=CFG.gf_api.."/contents/"..CFG.gf_code.."?"..qstr({password=pwhash,page=1,pageSize=200,sortField="name",sortDirection=1})
  local fsc,folder,ferr=gf_req("GET",url,token,wt,nil)
  if not fsc or type(folder.data)~="table" then
    return nil,((tostring((folder or {}).status or "")):lower():find("ratelimit",1,true) and "rate" or "failed")
  end
  local items={}
  for _,child in pairs(folder.data.children or {}) do
    if child.type=="file" then
      local name=tostring(child.name or "")
      if name:lower():match("%.apk$") then items[#items+1]={name=name,size=tonumber(child.size) or 0,link=tostring(child.link or "")} end
    end
  end
  table.sort(items,function(a,b) return a.name:lower()<b.name:lower() end)
  return {token=token,items=items}
end

-- ══════════════════════════════════════════════════════════════════════════════
--  Download + root install
-- ══════════════════════════════════════════════════════════════════════════════
local function safe_name(s) return tostring(s or ""):gsub('[\\/:*?"<>|]',"_") end

local function download_item(session,item)
  mkdir(CFG.dl_dir); local dest=CFG.dl_dir..SEP..safe_name(item.name); os.remove(dest)
  local ep=tmpf("dlerr")
  local parts={IS_WIN and "curl.exe" or "curl","-sS","--ipv4","--http1.1",
    "--connect-timeout",tostring(CFG.dl_connect),"--max-time",tostring(CFG.dl_timeout),
    "-L","-o",esc(dest),"-w",esc("%{http_code}"),
    "-H",esc("User-Agent: "..CFG.gf_ua),
    "-H",esc("Cookie: accountToken="..session.token),
    "-H",esc("Referer: "..CFG.gf_page),esc(item.link)}
  local p=io.popen(table.concat(parts," ").." 2>"..esc(ep))
  local sc=tonumber((p and p:read("*a") or "0"):match("%d+")) or 0
  if p then p:close() end
  local et=""; local eh=io.open(ep,"rb") if eh then et=eh:read("*a") or "" eh:close() end; os.remove(ep)
  if sc==0   then return "failed",nil,trim(et)~="" and trim(et) or "Download failed." end
  if sc==429 then os.remove(dest); return "rate",nil,"Rate limited." end
  if sc<200 or sc>=400 then os.remove(dest); return "failed",nil,"HTTP "..tostring(sc) end
  local h=io.open(dest,"rb") if not h then return "failed",nil,"Downloaded file missing." end
  local size=h:seek("end"); h:close()
  if not size or size<=0 then os.remove(dest); return "failed",nil,"Downloaded file is empty." end
  return "ok",dest,nil
end

local function root_run(cmd)
  if not cmd_exists("su") then return false,"Root unavailable." end
  local outp = tmpf("root_out")
  local stp  = tmpf("root_status")
  local raw  = ""
  local code = -1
  reset_tui_state()
  local wrapped = "su -c "..dq(cmd).." >"..esc(outp).." 2>&1 </dev/null; printf '%s' $? >"..esc(stp)
  os.execute("sh -c "..esc(wrapped).." >/dev/null 2>&1")
  local oh = io.open(outp,"rb")
  if oh then raw = oh:read("*a") or "" oh:close() end
  local sh = io.open(stp,"rb")
  if sh then code = tonumber(trim(sh:read("*a") or "")) or -1 sh:close() end
  os.remove(outp)
  os.remove(stp)
  raw = clean_proc_text(raw)
  reset_tui_state()
  if code == 0 or raw:lower():find("success",1,true) then return true,"Success" end
  return false,(raw~="" and raw or "Command failed.")
end

local function install_apk(path)
  local tries={"cmd package install -r --user 0 "..esc(path),"pm install -r --user 0 "..esc(path),
               "cmd package install -r "..esc(path),"pm install -r "..esc(path)}
  local last="Install failed."
  for _,cmd in ipairs(tries) do local ok,out=root_run(cmd) if ok then return true,out end last=out or last end
  return false,last
end

-- ══════════════════════════════════════════════════════════════════════════════
--  Clone task runner
-- ══════════════════════════════════════════════════════════════════════════════
local function process_clones(session,items,selected)
  local logs={}; local results={}; local total=#items
  for i,item in ipairs(items) do
    append_log(logs,"dl","Clone "..i..": Downloading APK")
    screen_progress(i,total,{name=item.name,phase="Downloading",pct=10},logs)
    local dstate,path,detail=download_item(session,item)
    sleep(CFG.step_delay)

    if dstate=="rate" then
      results[#results+1]={name=item.name,status="Rate limited",detail=detail,kind="warn"}
      append_log(logs,"warn","Clone "..i..": Rate limited while downloading")
      screen_progress(i,total,{name=item.name,phase="Rate limited — skipped",pct=0},logs); sleep(CFG.step_delay)
    elseif dstate~="ok" then
      results[#results+1]={name=item.name,status="Failed",detail=detail,kind="err"}
      append_log(logs,"err","Clone "..i..": Download failed")
      screen_progress(i,total,{name=item.name,phase="Download failed",pct=0},logs); sleep(CFG.step_delay)
    else
      append_log(logs,"dl","Clone "..i..": Download complete")
      screen_progress(i,total,{name=item.name,phase="Download complete",pct=50},logs)
      if selected[i] then
        append_log(logs,"inst","Clone "..i..": Installing / Updating")
        screen_progress(i,total,{name=item.name,phase="Installing / Updating",pct=75},logs)
        local ok,out=install_apk(path); os.remove(path)
        if ok then
          results[#results+1]={name=item.name,status="Successfully Installed/Updated",detail=out,kind="ok"}
          append_log(logs,"ok","Clone "..i..": Successfully Installed/Updated")
          append_log(logs,"info","Clone "..i..": Deleted APK")
          screen_progress(i,total,{name=item.name,phase="Successfully Installed/Updated",pct=100},logs)
        else
          results[#results+1]={name=item.name,status="Failed",detail=out,kind="err"}
          append_log(logs,"err","Clone "..i..": Install failed")
          append_log(logs,"info","Clone "..i..": Deleted APK")
          screen_progress(i,total,{name=item.name,phase="Install failed",pct=0},logs)
        end
      else
        os.remove(path)
        results[#results+1]={name=item.name,status="Downloaded",detail="Downloaded and cleaned.",kind="dl"}
        append_log(logs,"dl","Clone "..i..": Downloaded only")
        append_log(logs,"info","Clone "..i..": Deleted APK")
        screen_progress(i,total,{name=item.name,phase="Done (not selected for install)",pct=100},logs)
      end
      sleep(CFG.step_delay)
    end
  end
  screen_summary(results)  -- q and Enter both work cleanly here
end

-- ══════════════════════════════════════════════════════════════════════════════
--  Catalog menu (TUI)
-- ══════════════════════════════════════════════════════════════════════════════
local function catalog_menu()
  screen_status("CLONES CATALOG","Fetching catalog…",{"Please wait."},nil)
  local session,problem=fetch_catalog()

  if not session then
    local msg=problem=="rate" and "Rate limited while fetching catalog." or "Could not fetch catalog."
    screen_status("CLONES CATALOG",msg,{"Press Enter to go back."},problem=="rate" and "warn" or "err")
    wait_key(); return
  end

  if #session.items==0 then
    screen_status("CLONES CATALOG","No APKs found in catalog.",{"Press Enter to go back."},"warn")
    wait_key(); return
  end

  local selected={}; local cursor=1; local scroll=1; local notice=""; local base=#session.items

  while true do
    local vis=catalog_visible_rows()
    cursor=math.max(1,math.min(cursor,base+2))
    if cursor<=base then
      if cursor<scroll                      then scroll=cursor end
      if cursor>scroll+vis-1               then scroll=cursor-vis+1 end
      scroll=math.max(1,scroll)
    end

    screen_catalog(session.items,selected,cursor,scroll,notice); notice=""
    local k=read_key()
    if k=="CLICK" then
      k=CLICK_TOKEN or ""
      CLICK_TOKEN=nil
    end

    if     k=="Q"    then return
    elseif type(k)=="string" and k:match("^ITEM:%d+$") then
      local idx=tonumber(k:match(":(%d+)$"))
      if idx then
        cursor=idx
        selected[idx]=not selected[idx]
      end
    elseif k=="START" then
      cursor=base+1
      local count=0; for i=1,base do if selected[i] then count=count+1 end end
      if count==0 then notice="Select at least one clone first."
      else process_clones(session,session.items,selected); return end
    elseif k=="BACK" then
      cursor=base+2
      return
    elseif k=="UP"   then cursor=cursor-1
    elseif k=="DOWN" then cursor=cursor+1
    elseif k=="A"    then
      local all=true; for i=1,base do if not selected[i] then all=false; break end end
      for i=1,base do selected[i]=not all end
    elseif k=="SPACE" or k=="ENTER" then
      if cursor<=base then
        selected[cursor]=not selected[cursor]
        if k=="ENTER" then cursor=math.min(cursor+1,base+2) end
      elseif cursor==base+1 then
        local count=0; for i=1,base do if selected[i] then count=count+1 end end
        if count==0 then notice="Select at least one clone first."
        else process_clones(session,session.items,selected); return end
      else return end
    end
  end
end

-- ══════════════════════════════════════════════════════════════════════════════
--  Main menu (TUI)
-- ══════════════════════════════════════════════════════════════════════════════
local function main_menu()
  local cursor=1; local notice=""
  while true do
    screen_menu(cursor,notice); notice=""
    local k=read_key()
    if k=="CLICK" then
      k=CLICK_TOKEN or ""
      CLICK_TOKEN=nil
    end
    if     k=="Q"     then clear_screen(); os.exit(0)
    elseif k=="UP"    then cursor=cursor<=1 and 2 or cursor-1
    elseif k=="DOWN"  then cursor=cursor>=2 and 1 or cursor+1
    elseif k=="ONE"   then cursor=1; catalog_menu()
    elseif k=="TWO"   then cursor=2; notice="This option is coming soon."
    elseif k=="ENTER" then
      if cursor==1 then catalog_menu() else notice="This option is coming soon." end
    end
  end
end

-- ══════════════════════════════════════════════════════════════════════════════
--  Auth flow
-- ══════════════════════════════════════════════════════════════════════════════
local function verified()
  screen_status("VERIFIED","Verification complete.  Welcome to Lunex.",{"Loading menu…"},"ok")
  sleep(0.7); main_menu()
end

local function main()
  mkdir(CFG.root); mkdir(CFG.tmp); mkdir(CFG.dl_dir)
  local hwid,label=device_identity()
  local saved=load_license()
  local lic_notice="Waiting for license key."

  if saved then
    local expected=session_hash(saved.key,saved.hwid)
    if saved.hwid~=hwid or saved.session_hash~=expected then
      clear_saved_license_files()
      lic_notice="Saved session changed — please enter your license key again."
    else
      screen_status("AUTHENTICATION","Verifying saved session…",{"Please wait."},nil)
      local st=auto_login(saved.key,hwid,label)
      if st=="valid"  then verified(); return end
      if st=="rate"   then screen_status("RATE LIMITED","Too many requests were sent.",{"Wait for the timeout, then try again."},"warn"); return end
      if st=="server" then screen_status("UNAVAILABLE","Cannot reach the server.",{"Try again later."},"err"); return end
      clear_saved_license_files()
      lic_notice="Saved session expired — please enter your license key again."
    end
  end

  while true do
    screen_license(lic_notice)
    local lk=ask("License key"):upper()
    if lk=="" then
      lic_notice="No license key entered. Please try again."
    else
      screen_status("AUTHENTICATION","Verifying license key…",{"Please wait."},nil)
      local lst,lmsg=check_license(lk)
      if lst=="server" then screen_status("UNAVAILABLE","Cannot reach the server.",{"Try again later."},"err"); return end
      if lst=="rate" then
        lic_notice=lmsg or "Rate limited. Please wait and try again."
        goto continue_license
      end
      if lst~="valid" then
        lic_notice="That license key was not accepted."
      else
        local code_notice="Waiting for Termux code."
        while true do
          screen_code(label,code_notice)
          local code=ask("Termux code"):upper()
          if code=="" then
            code_notice="No code entered. Please try again."
          else
            screen_status("VERIFICATION","Checking Termux code…",{"Please wait."},nil)
            local vst,vmsg=validate_code(lk,code,hwid,label)
            if vst=="server" then screen_status("UNAVAILABLE","Cannot reach the server.",{"Try again later."},"err"); return end
            if     vst=="rate"               then code_notice=vmsg or "Rate limited. Please wait and try again."
            elseif vst=="valid"              then save_license(lk,hwid,label); verified(); return
            elseif vst=="invalid_license"    then clear_saved_license_files(); lic_notice="License is no longer valid."; break
            elseif vst=="expired"            then code_notice="Code expired — run /get-termux-code again."
            elseif vst=="hwid_limit_reached" then code_notice="HWID limit reached for this license."
            else                                  code_notice="That Termux code was not accepted." end
          end
        end
      end
    end
    ::continue_license::
  end
end

-- ══════════════════════════════════════════════════════════════════════════════
local ok,err=pcall(main)
if not ok then
  term_cooked()   -- always restore terminal on crash
  screen_status("ERROR","An unexpected error occurred.",{trim(err)},"err")
  print(trim(err)); os.exit(1)
end
