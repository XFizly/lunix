#!/usr/bin/env sh
_=[[
if command -v lua >/dev/null 2>&1; then
  exec lua "$0" "$@"
fi
exec lua5.4 "$0" "$@"
]]
math.randomseed(os.time())

local HOME=os.getenv("HOME") or "/data/data/com.termux/files/home"
local IS_WIN=package.config:sub(1,1)=="\\"
local DEVNULL=IS_WIN and "NUL" or "/dev/null"
local TEMP_ROOT=IS_WIN and (os.getenv("TEMP") or os.getenv("TMP") or ".") or (os.getenv("TMPDIR") or HOME.."/.lunex-tmp")
local ROOT_DIR=HOME.."/lunex"
local LICENSE_PATH=ROOT_DIR.."/license_key.json"
local DOWNLOAD_DIR=IS_WIN and ((os.getenv("USERPROFILE") or ".").."\\Downloads\\Lunex_Lite_clones") or "/storage/emulated/0/Download/Lunex_Lite_clones"
local TOOL_SPEC="0324241241241:https://lunex-termux-api.vercel.app:lunextool:R9p4K2m8Qx6Z1v3N"
local GF_CODE="ePdGcF"
local GF_PASS="A7K9-X2QM-4RTP-Z8LJ"
local GF_PAGE="https://gofile.io/d/"..GF_CODE
local GF_API="https://api.gofile.io"
local GF_UA="Mozilla/5.0 (Linux; Android 14; Termux)"
local GF_LANG="en-US"
local GF_SFXWT="5d4f7g8sd45fsd"

local json={}
local function jenc(v)
  local t=type(v)
  if t=="nil" then return "null" end
  if t=="boolean" then return v and "true" or "false" end
  if t=="number" then return v~=v and "null" or ("%.14g"):format(v) end
  if t=="string" then return '"'..v:gsub('[\\"]',function(c) return "\\"..c end):gsub("\n","\\n"):gsub("\r","\\r"):gsub("\t","\\t")..'"' end
  if t=="table" then
    local arr=#v>0
    if arr then for i=1,#v do if v[i]==nil then arr=false break end end end
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
      j=j+1 local e=s:sub(j,j)
      if e=='"' then b[#b+1]='"'
      elseif e=='\\' then b[#b+1]='\\'
      elseif e=='n' then b[#b+1]='\n'
      elseif e=='r' then b[#b+1]='\r'
      elseif e=='t' then b[#b+1]='\t'
      elseif e=='u' then local n=tonumber(s:sub(j+1,j+4),16) or 63 b[#b+1]=n<128 and string.char(n) or "?" j=j+4
      else b[#b+1]=e end
    else b[#b+1]=c end
    j=j+1
  end
  return table.concat(b),j
end
local function jarr(s,i)
  local a={} i=jskip(s,i)
  if s:sub(i,i)=="]" then return a,i+1 end
  while true do
    local v v,i=jval(s,i) a[#a+1]=v i=jskip(s,i) local c=s:sub(i,i)
    if c=="]" then return a,i+1 end
    if c~="," then break end
    i=i+1
  end
  return a,i
end
local function jobj(s,i)
  local o={} i=jskip(s,i)
  if s:sub(i,i)=="}" then return o,i+1 end
  while true do
    i=jskip(s,i) local k k,i=jstr(s,i) i=jskip(s,i)
    if s:sub(i,i)~=":" then break end
    i=i+1 local v v,i=jval(s,i) o[k]=v i=jskip(s,i) local c=s:sub(i,i)
    if c=="}" then return o,i+1 end
    if c~="," then break end
    i=i+1
  end
  return o,i
end
jval=function(s,i)
  i=jskip(s,i) local c=s:sub(i,i)
  if c=='"' then return jstr(s,i) end
  if c=="[" then return jarr(s,i+1) end
  if c=="{" then return jobj(s,i+1) end
  if s:sub(i,i+3)=="true" then return true,i+4 end
  if s:sub(i,i+4)=="false" then return false,i+5 end
  if s:sub(i,i+3)=="null" then return nil,i+4 end
  local n=s:match("^-?%d+%.?%d*[eE]?[+-]?%d*",i)
  if n then return tonumber(n),i+#n end
  return nil,i+1
end
function json.decode(s) if type(s)~="string" or s=="" then return nil end local ok,v=pcall(jval,s,1) return ok and v or nil end
json.encode=jenc

local function trim(s) return tostring(s or ""):match("^%s*(.-)%s*$") end
local function mkdir(p) if IS_WIN then os.execute('if not exist "'..p..'" mkdir "'..p..'" >'..DEVNULL..' 2>&1') else os.execute("mkdir -p '"..p:gsub("'","'\\''").."' 2>"..DEVNULL) end end
local function exists(p) local h=io.open(p,"r") if h then h:close() return true end return false end
local function esc(s) if IS_WIN then return '"'..tostring(s):gsub('"','""')..'"' end return "'"..tostring(s):gsub("'","'\\''").."'" end
local function dq(s) return '"'..tostring(s):gsub("\\","\\\\"):gsub('"','\\"')..'"' end
local function temp(name) return TEMP_ROOT..(IS_WIN and "\\" or "/")..name.."_"..math.random(999999)..".tmp" end
local function run1(cmd) local h=io.popen(cmd.." 2>"..DEVNULL) if not h then return "" end local o=trim(h:read("*l") or "") h:close() return o end
local function cmd_exists(c) return run1("command -v "..c)~="" end
local function sleep_s(sec) if IS_WIN then os.execute('powershell -NoProfile -Command "Start-Sleep -Milliseconds '..math.max(1,math.floor(sec*1000))..'" >'..DEVNULL..' 2>&1') else os.execute("sleep "..sec) end end
local function clear() if IS_WIN then os.execute("cls >"..DEVNULL.." 2>&1") end io.write("\27[3J\27[2J\27[H") io.flush() end

local function strip_ansi(s)
  return tostring(s or ""):gsub("\27%[[%d;:]*[A-Za-z]", "")
end

local function width(s)
  local clean = strip_ansi(tostring(s or ""))
  local w, i = 0, 1
  while i <= #clean do
    local b = clean:byte(i)
    w = w + 1
    if b >= 0xF0 then i = i + 4
    elseif b >= 0xE0 then i = i + 3
    elseif b >= 0xC0 then i = i + 2
    else i = i + 1 end
  end
  return w
end

local function pad(s, w)
  s = tostring(s or "")
  local n = width(s)
  return n >= w and s or s .. string.rep(" ", w - n)
end

local function center(s, w)
  local n = width(s)
  local p = math.max(0, w - n)
  local l = math.floor(p / 2)
  return string.rep(" ", l) .. s .. string.rep(" ", p - l)
end

local function trunc(s, w)
  s = strip_ansi(tostring(s or ""))
  if width(s) <= w then return s end
  local out, cw, i = {}, 0, 1
  while i <= #s and cw < w - 1 do
    local b = s:byte(i)
    local bytes = b >= 0xF0 and 4 or b >= 0xE0 and 3 or b >= 0xC0 and 2 or 1
    out[#out + 1] = s:sub(i, i + bytes - 1)
    cw = cw + 1
    i = i + bytes
  end
  return table.concat(out) .. "…"
end

local function cols()
  return math.max(60, tonumber(run1("tput cols")) or 80)
end

local E = "\27[" local R = E .. "0m"
local function tc(r,g,b) return E.."38;2;"..r..";"..g..";"..b.."m" end
local B = E .. "1m"
local function paint(s,...) local codes=table.concat({...}) if codes=="" then return tostring(s or "") end return codes..tostring(s or "")..R end

local C = {
  b1 = tc(110, 185, 255),
  b2 = tc(75, 150, 245),
  b3 = tc(50, 120, 225),
  b4 = tc(35, 95, 200),
  b5 = tc(22, 68, 168),
  b6 = tc(14, 47, 130),
  cyan = tc(0, 218, 255),
  teal = tc(0, 200, 178),
  white = tc(238, 244, 255),
  silver = tc(195, 208, 228),
  ash = tc(148, 162, 182),
  slate = tc(96, 112, 136),
  coal = tc(54, 64, 82),
  muted = tc(148, 162, 182),
  ok = tc(66, 220, 118),
  warn = tc(255, 188, 48),
  err = tc(255, 70, 70),
  border = tc(52, 82, 148),
  soft = tc(36, 56, 106),
  bdr_lo = tc(36, 56, 106),
  bdr_mid = tc(52, 82, 148),
  bdr_hi = tc(78, 118, 200),
  bdr_ok = tc(28, 138, 66),
  bdr_err = tc(136, 28, 28),
  bdr_wrn = tc(138, 100, 18),
}

local BANNER = {
  { C.b1, "  ██╗     ██╗   ██╗███╗  ██╗███████╗██╗  ██╗" },
  { C.b2, "  ██║     ██║   ██║████╗ ██║██╔════╝╚██╗██╔╝" },
  { C.b3, "  ██║     ██║   ██║██╔██╗██║█████╗   ╚███╔╝ " },
  { C.b4, "  ██║     ██║   ██║██║╚████║██╔══╝   ██╔██╗ " },
  { C.b5, "  ███████╗╚██████╔╝██║ ╚███║███████╗██╔╝╚██╗" },
  { C.b6, "  ╚══════╝ ╚═════╝ ╚═╝  ╚══╝╚══════╝╚═╝  ╚═╝" },
}

local BOX = {
  D = { tl="╔", tr="╗", bl="╚", br="╝", h="═", v="║" },
  R = { tl="╭", tr="╮", bl="╰", br="╯", h="─", v="│" },
}

local function header(step)
  local w = cols()
  clear()
  io.write("\n")
  for _, row in ipairs(BANNER) do
    io.write(center(paint(row[2], B, row[1]), w) .. "\n")
  end
  io.write("\n")
  local tag = paint("▸ ", C.bdr_mid)
    .. paint("S E C U R E   ·   V E R I F I E D   ·   A U T H E N T I C A T E D", C.coal)
    .. paint(" ◂", C.bdr_mid)
  io.write(center(tag, w) .. "\n\n")
  io.write(center(paint(string.rep("─", math.min(w - 8, 66)), C.bdr_lo), w) .. "\n")
  if step and step ~= "" then
    io.write("\n")
    io.write(center(paint("  " .. step .. "  ", B, C.cyan), w) .. "\n")
  end
  io.write("\n")
end

local function box(title, rows, color, style)
  local b = BOX[style or "D"] or BOX.D
  local w = math.max(34, math.min(cols() - 6, 78))
  local t = title and (" " .. title .. " ") or ""
  local fill = math.max(0, w - width(t))
  io.write("  " .. paint(b.tl .. t .. string.rep(b.h, fill) .. b.tr, color or C.bdr_mid) .. "\n")
  for _, row in ipairs(rows) do
    io.write("  " .. paint(b.v, color or C.bdr_mid) .. pad(row, w) .. paint(b.v, color or C.bdr_mid) .. "\n")
  end
  io.write("  " .. paint(b.bl .. string.rep(b.h, w) .. b.br, color or C.bdr_mid) .. "\n")
end

local SYM = {
  ok = paint(" ✔ ", B, C.ok),
  err = paint(" ✘ ", B, C.err),
  warn = paint(" ⚠ ", B, C.warn),
  wait = paint(" ◌ ", C.cyan),
  info = paint(" ◈ ", C.cyan),
  bullet = paint(" • ", C.slate),
  key = paint(" ⬡ ", C.teal),
  arrow = paint(" › ", B, C.b2),
}

local function S(sym, parts)
  return sym .. table.concat(parts)
end

local function status(step, title, lines, kind)
  local icon = ({ ok = SYM.ok, err = SYM.err, warn = SYM.warn })[kind] or SYM.info
  local border = ({ ok = C.bdr_ok, err = C.bdr_err, warn = C.bdr_wrn })[kind] or C.bdr_hi
  header((step or ""):upper())
  local rows = { "", S(icon, { paint(title or "", B, C.white) }), "" }
  for _, line in ipairs(lines or {}) do
    rows[#rows + 1] = paint(line, C.silver)
  end
  rows[#rows + 1] = ""
  box(" " .. (step or "") .. " ", rows, border, "D")
  io.write("\n")
end

local function screen_license(msg)
  local problem = msg and msg ~= "Waiting for license key."
  header("LICENSE AUTHENTICATION")
  box(" License Key ", {
    "",
    S(SYM.key, { paint("Enter your license key to continue.", B, C.white) }),
    "",
    S(SYM.bullet, { paint("Use ", C.ash), paint("/key_information", B, C.cyan), paint(" in the Discord bot.", C.ash) }),
    S(SYM.bullet, { paint("Paste the key at the prompt below.", C.ash) }),
    S(SYM.bullet, { paint("Type q to exit.", C.ash) }),
    "",
    S(problem and SYM.warn or SYM.wait, { paint(msg or "Waiting for license key.", problem and C.warn or C.silver) }),
    "",
  }, C.bdr_mid, "D")
  io.write("\n")
  box(nil, {
    S(SYM.bullet, { paint("Saved sessions are checked automatically on startup.", C.slate) }),
    S(SYM.bullet, { paint("If auto-login fails, re-enter your license key.", C.slate) }),
  }, C.bdr_lo, "R")
  io.write("\n")
end

local function screen_code(device, msg)
  local problem = msg and msg ~= "Waiting for Termux code."
  header("DEVICE VERIFICATION")
  box(" Termux Code ", {
    "",
    S(SYM.key, { paint("Device  ", C.ash), paint(trunc(device or "Unknown Device", 54), B, C.white) }),
    "",
    S(SYM.bullet, { paint("Run ", C.ash), paint("/get-termux-code", B, C.cyan), paint(" in the Discord bot.", C.ash) }),
    S(SYM.bullet, { paint("Paste the code sent to your DMs.", C.ash) }),
    S(SYM.bullet, { paint("Type q to exit.", C.ash) }),
    "",
    S(problem and SYM.warn or SYM.wait, { paint(msg or "Waiting for Termux code.", problem and C.warn or C.silver) }),
    "",
  }, C.bdr_mid, "D")
  io.write("\n")
  box(nil, {
    S(SYM.bullet, { paint("This code is tied to your device HWID.", C.slate) }),
    S(SYM.bullet, { paint("If the code expires, run /get-termux-code again.", C.slate) }),
  }, C.bdr_lo, "R")
  io.write("\n")
end

local function ask(label)
  io.write("\n" .. SYM.arrow .. paint(label, B, C.white) .. "  " .. paint("▶  ", C.bdr_mid))
  io.flush()
  local v = trim(io.read("*l") or "")
  if v:lower() == "q" then clear() os.exit(0) end
  return v
end

local function tool_api(spec)
  local key,base,user,pass=spec:match("^([^:]+):(https?://.+):([^:]+):([^:]+)$")
  if not key then error("Invalid LunexToolAPI format") end
  return {key=key,base=base:gsub("/+$",""),user=user,pass=pass}
end
local API=tool_api(TOOL_SPEC)

local function request(method,url,headers,body,opt)
  opt=opt or {}
  mkdir(TEMP_ROOT)
  local rp,ep,bp=temp("resp"),temp("err"),body and temp("body") or nil
  if bp then local h=io.open(bp,"wb") if not h then return nil,"","failed body" end h:write(body) h:close() end
  local parts={IS_WIN and "curl.exe" or "curl","-sS","--ipv4","--http1.1","--connect-timeout",tostring(opt.connect or 10),"--max-time",tostring(opt.max or 60)}
  if opt.follow then parts[#parts+1]="-L" end
  parts[#parts+1]="-o" parts[#parts+1]=esc(rp) parts[#parts+1]="-w" parts[#parts+1]=esc("%{http_code}") parts[#parts+1]="-X" parts[#parts+1]=method
  if opt.auth then parts[#parts+1]="-u" parts[#parts+1]=esc(opt.auth) end
  for _,h in ipairs(headers or {}) do parts[#parts+1]="-H" parts[#parts+1]=esc(h) end
  if bp then parts[#parts+1]="--data-binary" parts[#parts+1]=esc("@"..bp) end
  parts[#parts+1]=esc(url)
  local p=io.popen(table.concat(parts," ").." 2>"..esc(ep))
  local sc=tonumber((p and p:read("*a") or "0"):match("%d+")) or 0
  if p then p:close() end
  local body_txt,err_txt="",""
  local rh=io.open(rp,"rb") if rh then body_txt=rh:read("*a") or "" rh:close() end
  local eh=io.open(ep,"rb") if eh then err_txt=eh:read("*a") or "" eh:close() end
  os.remove(rp) os.remove(ep) if bp then os.remove(bp) end
  if sc==0 then return nil,body_txt,err_txt end
  return sc,body_txt,err_txt
end

local function api_post(route,payload)
  local sc,body=request("POST",API.base..route,{
    "Accept: application/json",
    "Content-Type: application/json",
    "X-Lunex-Tool-Api-Key: "..API.key,
  },json.encode(payload),{auth=API.user..":"..API.pass,max=20})
  if not sc then return nil,{message="Server unavailable."} end
  local parsed=json.decode(body) if type(parsed)~="table" then parsed={} end
  return sc,parsed
end

local function check_license(key)
  local sc,r=api_post("/api/termux/license-status",{licenseKey=key})
  if not sc then return "server",r.message or "Server unavailable." end
  if sc==200 then return "valid",r.message or "Valid." end
  if (r.code or "")=="UNAUTHORIZED" or sc>=500 then return "server",r.message or "Server unavailable." end
  return "invalid",r.message or "Invalid."
end
local function auto_login(key,hwid,label)
  local sc,r=api_post("/api/termux/auto-login",{licenseKey=key,hwid=hwid,hwidLabel=label})
  if not sc then return "server",r.message or "Server unavailable." end
  if sc==200 then return "valid",r.message or "Success" end
  if (r.code or "")=="AUTO_LOGIN_FAILED" then return "failed",r.message or "Auto login failed." end
  if (r.code or "")=="UNAUTHORIZED" or sc>=500 then return "server",r.message or "Server unavailable." end
  return "invalid",r.message or "Invalid."
end
local function validate_code(key,code,hwid,label)
  local sc,r=api_post("/api/termux/validate",{licenseKey=key,termuxCode=code,hwid=hwid,hwidLabel=label})
  if not sc then return "server",r.message or "Server unavailable." end
  if sc==200 then return "valid",r.message or "Success" end
  local c=r.code or ""
  if c=="INVALID_LICENSE" then return "invalid_license",r.message or "Invalid." end
  if c=="EXPIRED" then return "expired",r.message or "Expired." end
  if c=="HWID_LIMIT_REACHED" then return "hwid_limit_reached",r.message or "HWID limit reached." end
  if c=="UNAUTHORIZED" or sc>=500 then return "server",r.message or "Server unavailable." end
  return "invalid",r.message or "Invalid."
end

local function sha256(value)
  local p=temp("sha") local h=io.open(p,"wb") if not h then return "" end h:write(value) h:close()
  local out=IS_WIN and run1("powershell -NoProfile -Command \"(Get-FileHash -Algorithm SHA256 "..esc(p)..").Hash\"") or run1("openssl dgst -sha256 < "..esc(p).." | awk '{print $NF}'")
  os.remove(p) return trim(out):lower()
end
local function getprop(n) return run1("getprop "..n) end
local function device_identity()
  local parts,captured={},{}
  local props={"ro.serialno","ro.boot.serialno","ro.product.manufacturer","ro.product.brand","ro.product.model","ro.product.device","ro.product.name","ro.build.fingerprint","ro.hardware"}
  if cmd_exists("getprop") then for _,n in ipairs(props) do local v=getprop(n) if v~="" then captured[n]=v parts[#parts+1]=n.."="..v end end end
  for _,p in ipairs({"/etc/machine-id","/var/lib/dbus/machine-id"}) do local h=io.open(p,"r") if h then local m=trim(h:read("*l") or "") h:close() if m~="" then parts[#parts+1]="machine-id="..m end end end
  parts[#parts+1]="node="..run1("hostname") parts[#parts+1]="system="..run1("uname -s") parts[#parts+1]="machine="..run1("uname -m")
  local hwid=sha256(table.concat(parts,"\n")):upper():sub(1,32)
  local mfr=captured["ro.product.manufacturer"] or captured["ro.product.brand"] or run1("uname -s")
  local mdl=captured["ro.product.model"] or captured["ro.product.device"] or run1("hostname") or "Device"
  local label=(mfr~="" and mdl~="") and (mfr.." "..mdl) or (mfr~="" and mfr) or (mdl~="" and mdl) or "Unknown Device"
  return hwid,label:sub(1,80)
end

local function load_license()
  mkdir(ROOT_DIR)
  if not exists(LICENSE_PATH) then return nil end
  local h=io.open(LICENSE_PATH,"r") if not h then return nil end
  local raw=h:read("*a") h:close()
  local d=json.decode(raw) if type(d)~="table" then os.remove(LICENSE_PATH) return nil end
  local k=trim(d.license_key or ""):gsub("%s",""):upper()
  if k=="" then os.remove(LICENSE_PATH) return nil end
  return k
end
local function save_license(key,hwid,label)
  mkdir(ROOT_DIR)
  local h=io.open(LICENSE_PATH,"w") if not h then return end
  h:write(json.encode({license_key=trim(key):gsub("%s",""):upper(),hwid=hwid,device_label=label,saved_at=os.time()}))
  h:close()
end

local function urlencode(s) return (tostring(s):gsub("[^%w%-%.%_%~]",function(c) return ("%%%02X"):format(c:byte()) end)) end
local function qstr(t) local p={} for k,v in pairs(t) do p[#p+1]=urlencode(k).."="..urlencode(v) end return table.concat(p,"&") end
local function gf_wt(token) return sha256(GF_UA.."::"..GF_LANG.."::"..token.."::"..math.floor(os.time()/14400).."::"..GF_SFXWT) end
local function gf_kind(sc,r,errtxt)
  local st=tostring(r and r.status or ""):lower()
  local msg=tostring(r and r.message or ""):lower()
  local err=tostring(errtxt or ""):lower()
  if sc==429 or st:find("ratelimit",1,true) or msg:find("ratelimit",1,true) or err:find("429",1,true) then return "rate" end
  return "failed"
end
local function gf_req(method,url,token,wt,body)
  local hdr={"User-Agent: "..GF_UA}
  if token then hdr[#hdr+1]="Authorization: Bearer "..token end
  if wt then hdr[#hdr+1]="X-Website-Token: "..wt hdr[#hdr+1]="X-BL: "..GF_LANG end
  if body then hdr[#hdr+1]="Content-Type: application/json" end
  local sc,raw,err=request(method,url,hdr,body and json.encode(body) or nil,{max=30})
  if not sc then return nil,nil,err end
  local parsed=json.decode(raw) if type(parsed)~="table" then parsed={} end
  return sc,parsed,err
end
local function fetch_catalog()
  local sc,acc,err=gf_req("POST",GF_API.."/accounts",nil,nil,{})
  if not sc or type(acc.data)~="table" or not acc.data.token then return nil,gf_kind(sc or 0,acc or {},err) end
  local token=tostring(acc.data.token) local wt=gf_wt(token) local pwhash=sha256(GF_PASS)
  local url=GF_API.."/contents/"..GF_CODE.."?"..qstr({password=pwhash,page=1,pageSize=200,sortField="name",sortDirection=1})
  local fsc,folder,ferr=gf_req("GET",url,token,wt,nil)
  if not fsc or type(folder.data)~="table" then return nil,gf_kind(fsc or 0,folder or {},ferr) end
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

local function safe_name(s) return tostring(s or ""):gsub('[\\/:*?"<>|]',"_") end
local function format_size(n) n=tonumber(n) or 0 local u={"B","KB","MB","GB"} local i=1 while n>=1024 and i<#u do n=n/1024 i=i+1 end if i==1 then return math.floor(n).." "..u[i] end return ("%.1f %s"):format(n,u[i]) end

local function download_item(session,item)
  mkdir(DOWNLOAD_DIR)
  local dest=DOWNLOAD_DIR..(IS_WIN and "\\" or "/")..safe_name(item.name)
  os.remove(dest)
  local ep=temp("dlerr")
  local parts={
    IS_WIN and "curl.exe" or "curl",
    "-sS","--ipv4","--http1.1",
    "--connect-timeout","10",
    "--max-time","300",
    "-L",
    "-o",esc(dest),
    "-w",esc("%{http_code}"),
    "-H",esc("User-Agent: "..GF_UA),
    "-H",esc("Cookie: accountToken="..session.token),
    "-H",esc("Referer: "..GF_PAGE),
    esc(item.link),
  }
  local p=io.popen(table.concat(parts," ").." 2>"..esc(ep))
  local sc=tonumber((p and p:read("*a") or "0"):match("%d+")) or 0
  if p then p:close() end
  local err=""
  local eh=io.open(ep,"rb") if eh then err=eh:read("*a") or "" eh:close() end
  os.remove(ep)
  if sc==0 then return "failed",nil,trim(err)~="" and trim(err) or "Download failed." end
  if sc==429 then os.remove(dest) return "rate",nil,"Rate limited." end
  if sc<200 or sc>=400 then os.remove(dest) return "failed",nil,"HTTP "..tostring(sc) end
  local h=io.open(dest,"rb") if not h then return "failed",nil,"Downloaded file missing." end
  local size=h:seek("end") h:close()
  if not size or size<=0 then os.remove(dest) return "failed",nil,"Downloaded file is empty." end
  return "ok",dest,nil
end

local function root_run(cmd)
  if not cmd_exists("su") then return false,"Root unavailable." end
  local p=io.popen("su -c "..dq(cmd).." 2>&1")
  local out=p and (p:read("*a") or "") or ""
  if p then p:close() end
  out=trim(out)
  if out:lower():find("success",1,true) then return true,out end
  return false,(out~="" and out or "Command failed.")
end
local function install_apk(path)
  local tries={
    "cmd package install -r --user 0 "..esc(path),
    "pm install -r --user 0 "..esc(path),
    "cmd package install -r "..esc(path),
    "pm install -r "..esc(path),
  }
  local last="Install/update failed."
  for _,cmd in ipairs(tries) do local ok,out=root_run(cmd) if ok then return true,out end last=out or last end
  return false,last
end

local READ_KEY_CMD=[[bash -c 'old=$(stty -g </dev/tty 2>/dev/null); stty -icanon -echo min 1 time 0 </dev/tty 2>/dev/null; IFS= read -r -n1 a </dev/tty 2>/dev/null; IFS= read -r -n6 -t 0.02 b </dev/tty 2>/dev/null; [ -n "$old" ] && stty "$old" </dev/tty 2>/dev/null; printf "%s" "$a$b"' | od -An -tx1 | tr -d " \n\r"]]
local function read_key()
  if IS_WIN then
    io.write(paint("  Command [w/s/space/enter/a/q/1/2]: ",C.muted)) io.flush()
    local v=(io.read("*l") or ""):lower()
    if v=="w" then return "UP" end
    if v=="s" then return "DOWN" end
    if v=="space" then return "SPACE" end
    if v=="a" then return "A" end
    if v=="q" then return "Q" end
    if v=="1" then return "ONE" end
    if v=="2" then return "TWO" end
    return "ENTER"
  end
  local h=io.popen(READ_KEY_CMD) if not h then return "" end
  local hex=trim((h:read("*a") or ""):lower()) h:close()
  if hex=="1b5b41" then return "UP" end
  if hex=="1b5b42" then return "DOWN" end
  if hex=="20" then return "SPACE" end
  if hex=="61" or hex=="41" then return "A" end
  if hex=="71" or hex=="51" then return "Q" end
  if hex=="31" then return "ONE" end
  if hex=="32" then return "TWO" end
  if hex=="0d" or hex=="0a" or hex=="" then return "ENTER" end
  return ""
end

local function menu_screen(cursor,notice)
  header("MAIN MENU")
  local rows={"",paint("Choose what you want to do next.",C.silver),paint("Press q to exit.",C.muted),""}
  if notice and notice~="" then rows[#rows+1]=paint(notice,C.warn) rows[#rows+1]="" end
  local opts={"1. Download & Install/Update Clones","2. Auto Clones Position (SOON)"}
  for i,opt in ipairs(opts) do rows[#rows+1]=paint((cursor==i and "> " or "  ")..opt,B,cursor==i and C.cyan or C.white) end
  rows[#rows+1]="" rows[#rows+1]=paint("Enter select   Up/Down move   q exit",C.muted)
  box(" Lunex Menu ",rows,C.border)
  io.write("\n")
end

local function catalog_screen(items,selected,cursor,scroll,notice)
  header("CLONES CATALOG")
  local rows={"",paint("Folder: "..DOWNLOAD_DIR,C.silver),paint("Choose what should be installed or updated.",C.silver),paint("All clones are still downloaded to reduce expiry risk.",C.silver),paint("Press q to go back.",C.muted),""}
  if notice and notice~="" then rows[#rows+1]=paint(notice,C.warn) rows[#rows+1]="" end
  local vis=8 local last=math.min(#items,scroll+vis-1)
  for i=scroll,last do
    local item=items[i] local mark=selected[i] and "[x]" or "[ ]" local gap=math.max(1,70-#trunc(item.name,52)-#format_size(item.size))
    rows[#rows+1]=paint((cursor==i and "> " or "  ")..mark.." "..trunc(item.name,52)..string.rep(" ",gap)..format_size(item.size),B,cursor==i and C.cyan or C.white)
  end
  if last<#items then rows[#rows+1]=paint("... "..tostring(#items-last).." more clones below ...",C.muted) end
  local base=#items
  rows[#rows+1]="" rows[#rows+1]=paint((cursor==base+1 and "> " or "  ").."[ Start Download & Updating Clones ]",B,cursor==base+1 and C.cyan or C.white)
  rows[#rows+1]=paint((cursor==base+2 and "> " or "  ").."[ Go Back ]",B,cursor==base+2 and C.cyan or C.white)
  rows[#rows+1]="" rows[#rows+1]=paint("Enter toggle/select   Space toggle   A all   q back",C.muted)
  box(" Clones Catalog ",rows,C.border)
  io.write("\n")
end

local function progress_screen(stage,name,idx,total,detail,kind)
  status("CLONE TASK",stage.." "..idx.."/"..total,{
    trunc(name,66),
    trunc(detail or "",66),
  },kind)
end

local function summary_screen(results)
  clear()
  header("SUMMARY")
  local rows={
    "",
    paint("Processed files are cleaned after each task.",C.silver),
    paint("Folder used: "..DOWNLOAD_DIR,C.silver),
    "",
  }
  for _,r in ipairs(results) do
    local color=r.status=="Installed/Updated" and C.ok or r.status=="Downloaded" and C.cyan or r.status=="Rate limited" and C.warn or C.err
    rows[#rows+1]=paint(r.status,B,color)
    rows[#rows+1]=paint("  "..trunc(r.name,64),C.white)
    if r.detail and r.detail~="" then rows[#rows+1]=paint("  "..trunc(r.detail,64),C.muted) end
    rows[#rows+1]=""
  end
  rows[#rows+1]=paint("Press Enter to return to the menu.",C.muted)
  box(" Task Results ",rows,C.border) io.write("\n") io.read("*l")
end

local function process_items(session,items,selected)
  local results={}
  for i,item in ipairs(items) do
    progress_screen("Downloading",item.name,i,#items,"Preparing clone package...",nil)
    local dstate,path,detail=download_item(session,item)
    if dstate=="rate" then
      progress_screen("Rate limited",item.name,i,#items,detail or "Try again later.","warn")
      sleep_s(0.35)
      results[#results+1]={name=item.name,status="Rate limited",detail=detail or "Rate limited."}
    elseif dstate~="ok" then
      progress_screen("Failed",item.name,i,#items,detail or "Download failed.","err")
      sleep_s(0.35)
      results[#results+1]={name=item.name,status="Failed",detail=detail or "Download failed."}
    else
      progress_screen("Downloaded",item.name,i,#items,"Clone package downloaded.",nil)
      sleep_s(0.2)
      if selected[i] then
        progress_screen("Installing/Updating",item.name,i,#items,"Applying install/update with root...",nil)
        local ok,out=install_apk(path)
        os.remove(path)
        if ok then
          progress_screen("Installed/Updated",item.name,i,#items,"Install/update completed.","ok")
          sleep_s(0.25)
          results[#results+1]={name=item.name,status="Installed/Updated",detail=out}
        else
          progress_screen("Failed",item.name,i,#items,out or "Install/update failed.","err")
          sleep_s(0.35)
          results[#results+1]={name=item.name,status="Failed",detail=out or "Install/update failed."}
        end
      else
        os.remove(path)
        results[#results+1]={name=item.name,status="Downloaded",detail="Downloaded and cleaned."}
      end
    end
  end
  summary_screen(results)
end

local function catalog_menu()
  status("CLONES CATALOG","Fetching Lunex Lite Clones",{"Please wait while the catalog is refreshed."},nil)
  local session,problem=fetch_catalog()
  if not session then
    status("CLONES CATALOG",problem=="rate" and "Rate limited while fetching clones." or "Failed to fetch Lunex Lite Clones.",{"Press Enter to go back."},problem=="rate" and "warn" or "err")
    io.read("*l")
    return
  end
  if #session.items==0 then
    status("CLONES CATALOG","No clones were found.",{"Press Enter to go back."},"warn")
    io.read("*l")
    return
  end
  local selected,cursor,scroll,notice={},1,1,""
  local base=#session.items
  while true do
    if cursor<1 then cursor=1 end
    if cursor>base+2 then cursor=base+2 end
    if cursor<=base then
      if cursor<scroll then scroll=cursor end
      if cursor>scroll+7 then scroll=cursor-7 end
    end
    catalog_screen(session.items,selected,cursor,scroll,notice)
    notice=""
    local k=read_key()
    if k=="Q" then return
    elseif k=="UP" then cursor=cursor-1
    elseif k=="DOWN" then cursor=cursor+1
    elseif k=="A" then
      local all=true for i=1,base do if not selected[i] then all=false break end end
      for i=1,base do selected[i]=not all end
    elseif k=="SPACE" or k=="ENTER" then
      if cursor<=base then
        selected[cursor]=not selected[cursor]
      elseif cursor==base+1 then
        local count=0 for i=1,base do if selected[i] then count=count+1 end end
        if count==0 then notice="Choose at least one clone first." else process_items(session,session.items,selected) return end
      else
        return
      end
    end
  end
end

local function main_menu()
  local cursor,notice=1,""
  while true do
    menu_screen(cursor,notice)
    notice=""
    local k=read_key()
    if k=="Q" then clear() os.exit(0)
    elseif k=="UP" then cursor=cursor<=1 and 2 or cursor-1
    elseif k=="DOWN" then cursor=cursor>=2 and 1 or cursor+1
    elseif k=="ONE" then cursor=1 catalog_menu()
    elseif k=="TWO" then cursor=2 notice="This option is marked as SOON."
    elseif k=="ENTER" then
      if cursor==1 then catalog_menu() else notice="This option is marked as SOON." end
    end
  end
end

local function verified()
  status("VERIFICATION COMPLETE","Verification complete.",{"Loading Lunex menu..."}, "ok")
  sleep_s(0.8)
  main_menu()
end

local function main()
  mkdir(ROOT_DIR) mkdir(TEMP_ROOT) mkdir(DOWNLOAD_DIR)
  local hwid,label=device_identity()
  local saved=load_license()
  local lic_notice="Waiting for license key."
  if saved then
    status("AUTHENTICATION","Verifying saved session...",{"Please wait."},nil)
    local st=auto_login(saved,hwid,label)
    if st=="valid" then verified() return end
    if st=="server" then status("UNAVAILABLE","Cannot reach the server.",{"Try again later."},"err") return end
    os.remove(LICENSE_PATH)
    lic_notice="Saved session expired - please enter your license key again."
  end
  while true do
    screen_license(lic_notice)
    local lk=ask("License key"):upper()
    if lk=="" then
      lic_notice="No license key entered. Please try again."
    else
      status("AUTHENTICATION","Verifying license key...",{"Please wait."},nil)
      local lst=check_license(lk)
      if lst=="server" then status("UNAVAILABLE","Cannot reach the server.",{"Try again later."},"err") return end
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
            status("GET TERMUX CODE","Checking Termux code...",{"Please wait."},nil)
            local vst=validate_code(lk,code,hwid,label)
            if vst=="server" then status("UNAVAILABLE","Cannot reach the server.",{"Try again later."},"err") return end
            if vst=="valid" then save_license(lk,hwid,label) verified() return end
            if vst=="invalid_license" then os.remove(LICENSE_PATH) lic_notice="License is no longer valid." break
            elseif vst=="expired" then code_notice="Code expired - run /get-termux-code again."
            elseif vst=="hwid_limit_reached" then code_notice="HWID limit reached for this license."
            else code_notice="That Termux code was not accepted." end
          end
        end
      end
    end
  end
end

local ok,err=pcall(main)
if not ok then
  status("ERROR","An unexpected error occurred.",{trim(err)},"err")
  print(trim(err))
  os.exit(1)
end
