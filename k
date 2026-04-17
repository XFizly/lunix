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
    local t=type(v)
    if t=="nil"     then return "null" end
    if t=="boolean" then return v and "true" or "false" end
    if t=="number"  then return v~=v and "null" or ("%.14g"):format(v) end
    if t=="string"  then
        return '"'..v:gsub('[\\"]',function(c) return '\\'..c end)
                     :gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t')..'"'
    end
    if t=="table" then
        local is_arr=#v>0
        if is_arr then for i=1,#v do if v[i]==nil then is_arr=false; break end end end
        local p={}
        if is_arr then for _,x in ipairs(v) do p[#p+1]=je(x) end; return "["..table.concat(p,",").."]" end
        for k,x in pairs(v) do p[#p+1]=je(tostring(k))..":"..je(x) end
        return "{"..table.concat(p,",").."}"
    end
    return "null"
end
json.encode=je
local function jskip(s,i)
    while i<=#s do local b=s:byte(i); if b~=32 and b~=9 and b~=10 and b~=13 then break end; i=i+1 end; return i
end
local jval
local function jstr(s,i)
    local b,j={},i+1
    while j<=#s do
        local c=s:sub(j,j)
        if c=='"' then return table.concat(b),j+1 end
        if c=='\\' then
            j=j+1; local e=s:sub(j,j)
            if     e=='"'  then b[#b+1]='"'
            elseif e=='\\' then b[#b+1]='\\'
            elseif e=='n'  then b[#b+1]='\n'
            elseif e=='r'  then b[#b+1]='\r'
            elseif e=='t'  then b[#b+1]='\t'
            elseif e=='u'  then local n=tonumber(s:sub(j+1,j+4),16) or 63; b[#b+1]=n<128 and string.char(n) or '?'; j=j+4
            else b[#b+1]=e end
        else b[#b+1]=c end; j=j+1
    end; return table.concat(b),j
end
local function jarr(s,i)
    local a={}; i=jskip(s,i)
    if s:sub(i,i)==']' then return a,i+1 end
    while true do
        local v; v,i=jval(s,i); a[#a+1]=v; i=jskip(s,i)
        local c=s:sub(i,i); if c==']' then return a,i+1 end; if c~=',' then break end; i=i+1
    end; return a,i
end
local function jobj(s,i)
    local o={}; i=jskip(s,i)
    if s:sub(i,i)=='}' then return o,i+1 end
    while true do
        i=jskip(s,i); local k; k,i=jstr(s,i); i=jskip(s,i)
        if s:sub(i,i)~=':' then break end; i=i+1
        local v; v,i=jval(s,i); o[k]=v; i=jskip(s,i)
        local c=s:sub(i,i); if c=='}' then return o,i+1 end; if c~=',' then break end; i=i+1
    end; return o,i
end
jval=function(s,i)
    i=jskip(s,i); local c=s:sub(i,i)
    if c=='"' then return jstr(s,i) end
    if c=='[' then return jarr(s,i+1) end
    if c=='{' then return jobj(s,i+1) end
    if s:sub(i,i+3)=='true'  then return true, i+4 end
    if s:sub(i,i+4)=='false' then return false,i+5 end
    if s:sub(i,i+3)=='null'  then return nil,  i+4 end
    local n=s:match("^-?%d+%.?%d*[eE]?[+-]?%d*",i)
    if n then return tonumber(n),i+#n end
    return nil,i+1
end
function json.decode(s)
    if type(s)~="string" or s=="" then return nil end
    local ok,v=pcall(jval,s,1); return ok and v or nil
end

local HOME        = os.getenv("HOME") or "/data/data/com.termux/files/home"
local SDIR        = (arg[0] or ""):match("^(.+)/[^/]*$") or "."
local LROOT       = HOME.."/lunex"
local LIC_PATH    = LROOT.."/license_key.json"
local CFG_PATH    = LROOT.."/clone_config.json"
local DL_ROOT     = SDIR.."/downloads"
local IS_WINDOWS  = package.config:sub(1,1)=="\\"
local NULL_DEV    = IS_WINDOWS and "NUL" or "/dev/null"
local TEMP_ROOT   = IS_WINDOWS
    and (os.getenv("TEMP") or os.getenv("TMP") or ".")
    or  (os.getenv("TMPDIR") or (HOME.."/.lunex-tmp"))

local GF_CODE  = "ePdGcF"
local GF_PASS  = "A7K9-X2QM-4RTP-Z8LJ"
local GF_PAGE  = "https://gofile.io/d/"..GF_CODE
local GF_API   = "https://api.gofile.io"
local GF_UA    = "Mozilla/5.0 (Linux; Android 14; Termux)"
local GF_LANG  = "en-US"
local GF_SFXWT = "5d4f7g8sd45fsd"
local LunexToolAPI = "0324241241241:https://lunex-termux-api.vercel.app:lunextool:R9p4K2m8Qx6Z1v3N"

local ACTS = {
    "Refreshing secure channels...","Reconciling runtime state...",
    "Synchronising request lanes...","Applying environment checks...",
    "Stabilising package context...","Sealing temporary workspace...",
    "Finalising hidden handoff...","Verifying response envelope...",
}

local C = {
    reset="",text="",muted="",dim="",
    border="",border_hi="",title="",accent="",
    success="",warning="",danger="",soon="",installed="",
    bg_row="",bg_sel="",bg_hi="",bg_inst="",bold="",italic="",
}
C.reset     ="\027[0m"
C.text      ="\027[38;2;225;235;248m"
C.muted     ="\027[38;2;110;132;162m"
C.dim       ="\027[38;2;60;80;110m"
C.border    ="\027[38;2;38;55;82m"
C.border_hi ="\027[38;2;70;118;200m"
C.title     ="\027[38;2;120;185;255m"
C.accent    ="\027[38;2;100;170;255m"
C.success   ="\027[38;2;100;220;155m"
C.warning   ="\027[38;2;255;205;80m"
C.danger    ="\027[38;2;255;105;105m"
C.soon      ="\027[38;2;155;120;255m"
C.installed ="\027[38;2;80;200;140m"
C.bg_row    ="\027[48;2;11;19;33m"
C.bg_sel    ="\027[48;2;16;30;54m"
C.bg_hi     ="\027[48;2;20;38;68m"
C.bg_inst   ="\027[48;2;12;34;24m"
C.bold      ="\027[1m"
C.italic    ="\027[3m"
local TONES={success=C.success,warning=C.warning,danger=C.danger,accent=C.accent,soon=C.soon}

local LOGO={
    "  ##  ##  ##  ##  ## ###  ## ###  ##  ## ##  ",
    "  ##  ##  ##  ##  ## #  # ##  ##   ####  #   ",
    "  ##  ##  ##  ##  ## #  # ## ###    ##   ##  ",
    "  ##  ##  ##  ##  ## ###  ##  ##   ####  #   ",
    "  ###### ######   ## #  # ##  ##  ##  ## ##  ",
}

local DEBUG_LOGS={}
local MAX_DBG=48
local DEVICE_LABEL="Unknown Device"

local function parse_tool_api(spec)
    local ak,bu,un,pw=spec:match("^([^:]+):(https?://.+):([^:]+):([^:]+)$")
    if not ak then error("Invalid LunexToolAPI format") end
    return {key=ak,base=bu:gsub("/+$",""),username=un,password=pw}
end
local TOOL_API=parse_tool_api(LunexToolAPI)

local function col(s,...) return table.concat({...})..s..C.reset end
local function clear()
    if IS_WINDOWS then os.execute("cls >"..NULL_DEV.." 2>&1") end
    io.write("\027[3J\027[2J\027[H"); io.flush()
end
local function shl(cmd)
    local f=io.popen(cmd.." 2>"..NULL_DEV); if not f then return "" end
    local r=(f:read("*l") or ""):match("^%s*(.-)%s*$"); f:close(); return r
end
local function shl_full(cmd)
    local f=io.popen(cmd.." 2>&1"); if not f then return 1,"" end
    local out=f:read("*a") or ""; local ok,_,code=f:close()
    return (ok and code or 1),out:match("^%s*(.-)%s*$")
end
local function tw() return math.max(60,tonumber(shl("tput cols")) or 80) end
local function strip(s) return (s:gsub("\027%[[%d;]*m","")) end
local function vlen(s) return #strip(s) end
local function trunc(s,w)
    if w<=0 then return "" end; if #s<=w then return s end; return s:sub(1,w-3).."..."
end
local function short(s,w)
    s=tostring(s or ""):gsub("[%c]+"," "); if #s<=w then return s end
    return s:sub(1,math.max(1,w-3)).."..."
end
local function pad_r(s,w) return s..string.rep(" ",math.max(0,w-vlen(s))) end
local function pad_c(s,w)
    local p=math.max(0,w-vlen(s)); local l=math.floor(p/2)
    return string.rep(" ",l)..s..string.rep(" ",p-l)
end
local function push_debug(tag,msg)
    local t=os.date("%H:%M:%S")
    DEBUG_LOGS[#DEBUG_LOGS+1]=("[%s] %s %s"):format(t,tag,short(msg,180))
    while #DEBUG_LOGS>MAX_DBG do table.remove(DEBUG_LOGS,1) end
end
local function hsize(n)
    local u={"B","KB","MB","GB"}; local v=n; local i=1
    while v>=1024 and i<#u do v=v/1024; i=i+1 end
    if i==1 then return math.floor(v).." B" end
    return ("%.1f %s"):format(v,u[i])
end
local function sleep(s)
    if IS_WINDOWS then
        os.execute('powershell -NoProfile -Command "Start-Sleep -Milliseconds '..math.max(1,math.floor(s*1000))..'" >'..NULL_DEV.." 2>&1")
        return
    end; os.execute("sleep "..s)
end
local function esc(s)
    if IS_WINDOWS then return '"'..tostring(s):gsub('"','""')..'"' end
    return "'"..tostring(s):gsub("'","'\\''").."'"
end
local function safename(s) return (s:gsub('[\\/:*?"<>|%s]',"_")) end
local function mkdirp(p)
    if IS_WINDOWS then os.execute('if not exist '..esc(p).." mkdir "..esc(p).." >"..NULL_DEV.." 2>&1"); return end
    os.execute("mkdir -p "..esc(p).." 2>"..NULL_DEV)
end
local function fexists(p) local f=io.open(p,"r"); if f then f:close(); return true end; return false end
local function temp_path(pfx)
    local sep=IS_WINDOWS and "\\" or "/"
    return TEMP_ROOT..sep..pfx.."_"..math.random(999999)..".tmp"
end

-- clone config
local function load_clone_cfg()
    if not fexists(CFG_PATH) then return {installed={}} end
    local f=io.open(CFG_PATH,"r"); if not f then return {installed={}} end
    local raw=f:read("*a"); f:close()
    local d=json.decode(raw); if type(d)~="table" then return {installed={}} end
    if type(d.installed)~="table" then d.installed={} end
    return d
end
local function save_clone_cfg(cfg)
    mkdirp(LROOT); local f=io.open(CFG_PATH,"w"); if not f then return end
    f:write(json.encode(cfg)); f:close()
end
local function get_installed_set()
    local cfg=load_clone_cfg(); local s={}
    for _,name in ipairs(cfg.installed) do s[name]=true end
    return s
end
local function mark_installed(name)
    local cfg=load_clone_cfg()
    for _,n in ipairs(cfg.installed) do if n==name then cfg.last_install=os.time(); save_clone_cfg(cfg); return end end
    cfg.installed[#cfg.installed+1]=name; cfg.last_install=os.time(); save_clone_cfg(cfg)
end

-- draw
local function box(title,rows,bc)
    local w=tw(); local inn=w-2; bc=bc or C.border
    if title and title~="" then
        local t=" "..title.." "; local dash=math.max(0,inn-vlen(t)-2)
        local llen=math.floor(dash/2); local rlen=dash-llen
        io.write(col("+-"..string.rep("-",llen).."-+",bc)..col(t,C.title,C.bold)..col("+-"..string.rep("-",rlen).."-+",bc).."\n")
    else io.write(col("+"..string.rep("-",inn).."+",bc).."\n") end
    for _,row in ipairs(rows) do
        if row=="" then io.write(col("|"..string.rep(" ",inn).."|",bc).."\n")
        else
            local vis=vlen(row); if vis>inn-2 then row=trunc(strip(row),inn-2); vis=#row end
            io.write(col("|",bc).." "..pad_r(row,inn-2).." "..col("|",bc).."\n")
        end
    end
    io.write(col("+"..string.rep("-",inn).."+",bc).."\n")
end

local function draw_header(subtitle)
    local w=tw()
    io.write("\n")
    for _,line in ipairs(LOGO) do io.write(pad_c(col(line,C.title,C.bold),w).."\n") end
    io.write(pad_c(col("Delta Lite  v1.1  discord.gg/HQtp9fVqZT",C.muted),w).."\n")
    if subtitle and subtitle~="" then io.write(pad_c(col("[ "..subtitle.." ]",C.dim),w).."\n") end
    io.write("\n")
end

local function notice_row(tone,msg)
    local icons={success="OK",danger="!!",warning="!!",accent="->",soon="**"}
    local fg=TONES[tone] or C.muted
    return col((icons[tone] or "**").." ",fg,C.bold)..col(msg,fg)
end
local function kv_row(k,v,vfg,w)
    local key=col(k,C.muted); local val=col(v,vfg or C.accent)
    local gap=math.max(1,(w-2)-vlen(key)-vlen(val)-2)
    return key..string.rep(" ",gap)..val
end

local function prog(title,sub,det,tone)
    clear(); draw_header()
    local fg=TONES[tone] or C.accent
    local rows={pad_c(col(title,fg,C.bold),tw()-2),""}
    if sub~="" then rows[#rows+1]=pad_c(col(sub,C.text),tw()-2) end
    if det~="" then rows[#rows+1]=pad_c(col(det,C.muted),tw()-2) end
    box("",rows,fg)
end
local function status_box(t,m,tone) prog(t,m,"",tone) end

local function mprog(pos,tot,seed)
    local w=math.max(10,math.min(30,tw()-38))
    local fill=math.max(0,math.min(w,math.floor((pos/math.max(1,tot))*w+0.5)))
    local bar=col("["..string.rep("#",fill)..string.rep(".",w-fill).."]",C.accent)
    prog("Installing","Item "..pos.." / "..tot,bar.."  "..ACTS[(seed or 0)%#ACTS+1],"accent")
end
local function mdelay(pos,tot,seed,steps,delay)
    steps=steps or 2; delay=delay or 0.35
    for i=0,steps-1 do mprog(pos,tot,seed+i); sleep(delay) end
end

local function show_activity()
    clear(); draw_header("Activity Log"); local rows={}
    local si=math.max(1,#DEBUG_LOGS-18)
    for i=si,#DEBUG_LOGS do rows[#rows+1]=col(DEBUG_LOGS[i],C.muted) end
    if #DEBUG_LOGS==0 then rows[#rows+1]=col("No activity recorded yet.",C.muted) end
    rows[#rows+1]=""; rows[#rows+1]=col("Press Enter to go back.",C.dim)
    box("Recent Activity",rows,C.border_hi); io.read("*l")
end

local function show_error(title,msg)
    while true do
        clear(); draw_header()
        local rows={notice_row("danger",msg),""}
        if #DEBUG_LOGS>0 then rows[#rows+1]=col("Type D for the activity log. Enter to go back.",C.muted)
        else rows[#rows+1]=col("Press Enter to go back.",C.muted) end
        box(title,rows,C.danger)
        local v=(io.read("*l") or ""):lower():match("^%s*(.-)%s*$")
        if v=="d" and #DEBUG_LOGS>0 then show_activity() else return end
    end
end

local READ_KEY_CMD=[[bash -c 'IFS= read -r -s -n1 k </dev/tty 2>/dev/null; IFS= read -r -s -n2 -t0.1 s </dev/tty 2>/dev/null; printf "%s" "$k$s"' 2>/dev/null | od -An -tx1 | tr -d ' \n\r']]
local READ_KEY_WIN=[[powershell -NoProfile -Command "$k=[Console]::ReadKey($true); switch($k.Key.ToString()){ 'UpArrow'{'UP'} 'DownArrow'{'DOWN'} 'Enter'{'ENTER'} 'Spacebar'{'SPACE'} 'A'{'A'} 'Q'{'Q'} default{''} }"]]
local function read_key()
    if IS_WINDOWS then
        local f=io.popen(READ_KEY_WIN); if not f then return "" end
        local v=(f:read("*a") or ""):match("^%s*(.-)%s*$"); f:close(); return v
    end
    local f=io.popen(READ_KEY_CMD); if not f then return "" end
    local h=(f:read("*a") or ""):lower():gsub("[%s\n\r]",""); f:close()
    if h=="1b5b41" then return "UP" end
    if h=="1b5b42" then return "DOWN" end
    if h=="" or h=="0d" or h=="0a" then return "ENTER" end
    if h=="20" then return "SPACE" end
    if h=="61" or h=="41" then return "A" end
    if h=="71" or h=="51" or h=="03" then return "Q" end
    return ""
end
local function prompt_val(label)
    io.write("\n"..col("  > ",C.accent,C.bold)..col(label..": ",C.text))
    io.flush(); local v=io.read("*l") or ""; return v:match("^%s*(.-)%s*$"):upper()
end

local function sha256(s)
    local tmp=temp_path("lnx"); local f=io.open(tmp,"wb"); if not f then return "" end; f:write(s); f:close()
    local h
    if IS_WINDOWS then h=shl("powershell -NoProfile -Command \"(Get-FileHash -Algorithm SHA256 '"..tmp:gsub("'","''").."').Hash\"")
    else h=shl("openssl dgst -sha256 < "..esc(tmp).." | awk '{print $NF}'") end
    os.remove(tmp); return h:lower()
end
local HAS_GP=shl("command -v getprop")~=""
local function gp(n) if not HAS_GP then return "" end; return shl("getprop "..n) end
local function device_id()
    local props={"ro.serialno","ro.boot.serialno","ro.product.manufacturer","ro.product.brand",
        "ro.product.model","ro.product.device","ro.product.name","ro.build.fingerprint","ro.hardware"}
    local vals,got={},{}
    for _,n in ipairs(props) do local v=gp(n); if v~="" then got[n]=v; vals[#vals+1]=n.."="..v end end
    for _,mp in ipairs({"/etc/machine-id","/var/lib/dbus/machine-id"}) do
        local f=io.open(mp,"r")
        if f then local mid=(f:read("*l") or ""):match("^%s*(.-)%s*$"); f:close()
            if mid~="" then vals[#vals+1]="machine-id="..mid end end
    end
    vals[#vals+1]="node="..shl("hostname"); vals[#vals+1]="system="..shl("uname -s"); vals[#vals+1]="machine="..shl("uname -m")
    local dig=sha256(table.concat(vals,"\n")):upper(); local hwid=dig:sub(1,32)
    local mfr=got["ro.product.manufacturer"] or got["ro.product.brand"] or shl("uname -s")
    local mdl=got["ro.product.model"] or got["ro.product.device"] or shl("hostname") or "Device"
    local lbl=((mfr~="" and mdl~="") and (mfr.." "..mdl)) or (mfr~="" and mfr) or (mdl~="" and mdl) or "Unknown Device"
    return hwid,lbl:sub(1,80)
end

local function load_lic()
    mkdirp(LROOT); if not fexists(LIC_PATH) then return nil end
    local f=io.open(LIC_PATH,"r"); if not f then return nil end
    local raw=f:read("*a"); f:close()
    local d=json.decode(raw); if type(d)~="table" then os.remove(LIC_PATH); return nil end
    local k=(tostring(d.license_key or "")):gsub("%s",""):upper(); return k~="" and k or nil
end
local function save_lic(key,hwid,lbl)
    mkdirp(LROOT); local f=io.open(LIC_PATH,"w"); if not f then return end
    f:write(json.encode({license_key=key:gsub("%s",""):upper(),hwid=hwid,device_label=lbl,saved_at=os.time()})); f:close()
end

local function http_req(method,url,hdrs,body,use_auth)
    local tmp=temp_path("lnx_r"); local err_tmp=temp_path("lnx_e")
    local body_tmp=body and temp_path("lnx_b") or nil
    if body_tmp then
        local bf=io.open(body_tmp,"wb"); if not bf then return nil,"",{} end
        bf:write(body); bf:close()
    end
    local p={IS_WINDOWS and "curl.exe" or "curl","-k","-sS","--ipv4","--http1.1",
        "--connect-timeout","15","--max-time","30","--retry","3","--retry-delay","2",
        "-o",esc(tmp),"-w",esc("%{http_code}"),"-X",method}
    if use_auth then
        p[#p+1]="-u"; p[#p+1]=esc(TOOL_API.username..":"..TOOL_API.password)
        p[#p+1]="-H"; p[#p+1]=esc("X-Lunex-Tool-Api-Key: "..TOOL_API.key)
    end
    for _,h in ipairs(hdrs or {}) do p[#p+1]="-H"; p[#p+1]=esc(h) end
    if body then p[#p+1]="--data-binary"; p[#p+1]=esc("@"..body_tmp) end
    p[#p+1]=esc(url)
    push_debug("HTTP",method.." "..short(url,96))
    local f=io.popen(table.concat(p," ").." 2>"..esc(err_tmp))
    local sc=tonumber((f and f:read("*a") or "0"):match("%d+")) or 0
    local cok,creason,ccode=true,"exit",0; if f then cok,creason,ccode=f:close() end
    local raw,err_raw="",""
    local rf=io.open(tmp,"r"); if rf then raw=rf:read("*a") or ""; rf:close() end
    local ef=io.open(err_tmp,"r"); if ef then err_raw=ef:read("*a") or ""; ef:close() end
    os.remove(tmp); os.remove(err_tmp); if body_tmp then os.remove(body_tmp) end
    if sc==0 then push_debug("HTTP","curl failed stderr="..short(err_raw,80)); return nil,raw,{} end
    push_debug("HTTP","status="..sc); return sc,raw,{}
end
local function api_post(route,payload)
    push_debug("API","POST "..route)
    local sc,raw,meta=http_req("POST",TOOL_API.base..route,
        {"Accept: application/json","Content-Type: application/json"},json.encode(payload),true)
    if not sc then return nil,{message="Server unavailable.",debug=meta} end
    local d=json.decode(raw); if type(d)~="table" then d={} end
    push_debug("API","response="..tostring(sc).." msg="..short(d.message or "",80))
    return sc,d
end
local function chk_license(key)
    local sc,d=api_post("/api/termux/license-status",{licenseKey=key})
    if not sc then return "server",d.message or "Server unavailable." end
    if sc==200 then return "valid",d.message or "Valid." end
    if (d.code or "")=="UNAUTHORIZED" then return "server",d.message or "Unauthorized." end
    if sc>=500 then return "server",d.message or "Server unavailable." end
    return "invalid",d.message or "Invalid."
end
local function do_autologin(key,hwid,lbl)
    local sc,d=api_post("/api/termux/auto-login",{licenseKey=key,hwid=hwid,hwidLabel=lbl})
    if not sc then return "server",d.message or "Server unavailable." end
    if sc==200 then return "valid",d.message or "license key valid!" end
    if (d.code or "")=="AUTO_LOGIN_FAILED" then return "auto_login_failed",d.message or "Auto login failed." end
    return "invalid",d.message or "Invalid."
end
local function do_validate(key,tc,hwid,lbl)
    local sc,d=api_post("/api/termux/validate",{licenseKey=key,termuxCode=tc,hwid=hwid,hwidLabel=lbl})
    if not sc then return "server",d.message or "Server unavailable." end
    if sc==200 then return "valid",d.message or "License key valid!" end
    local ec=d.code or ""
    if ec=="INVALID_LICENSE"    then return "invalid_license",d.message or "Invalid." end
    if ec=="EXPIRED"            then return "expired",d.message or "Expired." end
    if ec=="HWID_LIMIT_REACHED" then return "hwid_limit_reached",d.message or "HWID limit reached." end
    if ec=="UNAUTHORIZED"       then return "server",d.message or "Unauthorized." end
    return "invalid",d.message or "Invalid."
end

local function urlencode(s) return (s:gsub("[^%w%-%.%_%~]",function(c) return ("%%%02X"):format(c:byte()) end)) end
local function buildq(t)
    local p={} for k,v in pairs(t) do p[#p+1]=urlencode(tostring(k)).."="..urlencode(tostring(v)) end
    return table.concat(p,"&")
end
local function gf_wt(token)
    return sha256(GF_UA.."::"..GF_LANG.."::"..token.."::"..math.floor(os.time()/14400).."::"..GF_SFXWT)
end
local function gf_req(method,url,token,wt,body_tbl)
    local hdrs={"User-Agent: "..GF_UA}
    if token then hdrs[#hdrs+1]="Authorization: Bearer "..token end
    if wt    then hdrs[#hdrs+1]="X-Website-Token: "..wt; hdrs[#hdrs+1]="X-BL: "..GF_LANG end
    local body=body_tbl and json.encode(body_tbl) or nil
    if body then hdrs[#hdrs+1]="Content-Type: application/json" end
    local _,raw=http_req(method,url,hdrs,body,false); return json.decode(raw) or {}
end
local function gf_new_session()
    local acc=gf_req("POST",GF_API.."/accounts",nil,nil,{})
    local token=type(acc.data)=="table" and tostring(acc.data.token or "") or ""
    if token=="" then error("Gofile: no token") end
    local wt=gf_wt(token); local pwhash=sha256(GF_PASS)
    local q=buildq({password=pwhash,page=1,pageSize=200,sortField="name",sortDirection=1})
    local folder=gf_req("GET",GF_API.."/contents/"..GF_CODE.."?"..q,token,wt)
    local fd=folder.data; if type(fd)~="table" then error("Gofile: bad folder data") end
    local items={}
    for _,c in pairs(fd.children or {}) do
        if c.type=="file" then
            local n=tostring(c.name or "")
            if n:match("%.apk$") or n:match("%.apk%.apk$") then
                items[#items+1]={id=tostring(c.id or ""),name=n,size=tonumber(c.size) or 0,link=tostring(c.link or "")}
            end
        end
    end
    table.sort(items,function(a,b) return a.name:lower()<b.name:lower() end)
    return {token=token,wt=wt,pwhash=pwhash,folder=tostring(fd.id or GF_CODE)},items
end
local function gf_refresh(sess)
    sess.wt=gf_wt(sess.token)
    gf_req("GET",GF_API.."/contents/"..sess.folder.."?"..buildq({password=sess.pwhash,page=1,pageSize=200}),sess.token,sess.wt)
end

local function dl_apk(sess,apk,pos,tot)
    gf_refresh(sess); mkdirp(DL_ROOT)
    local dest=DL_ROOT.."/"..safename(apk.name); os.remove(dest)
    prog("Downloading "..pos.."/"..tot,apk.name,"Size: "..hsize(apk.size),"accent")
    local cmd="curl -L --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 300"
        .." -o "..esc(dest)
        .." -H "..esc("User-Agent: "..GF_UA)
        .." -H "..esc("Cookie: accountToken="..sess.token)
        .." -H "..esc("Referer: "..GF_PAGE)
        .." "..esc(apk.link).." 2>"..NULL_DEV
    local ret=os.execute(cmd)
    local ok=(ret==true) or (type(ret)=="number" and ret==0)
    local f=io.open(dest,"rb")
    if not f then push_debug("DL","file missing: "..dest); error("Downloaded file is missing") end
    local sz=f:seek("end"); f:close()
    if sz==0 then os.remove(dest); error("Downloaded file is empty") end
    if sz<1024 then
        local ff=io.open(dest,"r"); local head=ff and (ff:read(256) or "") or ""; if ff then ff:close() end
        if head:match("^%s*<!") or (head:match("^%s*{") and not head:match("PK")) then
            os.remove(dest); push_debug("DL","got non-APK sz="..sz); error("Server returned non-APK (token expired?)") end
    end
    push_debug("DL","ok size="..hsize(sz)); return dest
end

local function inst_apk(path)
    local HAS_SU=shl("command -v su")~=""
    local HAS_PM=shl("command -v pm")~=""
    local HAS_ADB=shl("command -v adb")~=""
    push_debug("INST","path="..path.." su="..tostring(HAS_SU).." pm="..tostring(HAS_PM))
    local tries={}
    if HAS_SU then
        tries[#tries+1]={"su+pm-g",    "su -c 'pm install -r -g "..path.."'"}
        tries[#tries+1]={"su+pm",      "su -c 'pm install -r "..path.."'"}
        tries[#tries+1]={"su+cmd-pkg", "su -c 'cmd package install -r -g "..path.."'"}
    end
    if HAS_PM then
        tries[#tries+1]={"pm-g",       "pm install -r -g "..esc(path)}
        tries[#tries+1]={"pm",         "pm install -r "..esc(path)}
        tries[#tries+1]={"pm-dk",      "pm install --dont-kill -r "..esc(path)}
    end
    if HAS_ADB then
        tries[#tries+1]={"adb",        "adb install -r "..esc(path)}
    end
    if #tries==0 then return false,"No install method found (no su/pm/adb)" end
    local last_err="Install failed."
    for _,t in ipairs(tries) do
        push_debug("INST","try "..t[1])
        local code,out=shl_full(t[2])
        push_debug("INST","code="..tostring(code).." out="..short(out,120))
        local out_l=out:lower()
        if out:match("[Ss]uccess") or out:match("INSTALL_SUCCEEDED") then
            return true,"Installed via "..t[1] end
        if code==0 and out=="" then return true,"Installed via "..t[1].." (silent)" end
        if out_l:match("already") and out_l:match("installed") then return true,"Already up to date" end
        if out~="" then last_err=out:gsub("\n"," "):sub(1,200) end
        if out_l:match("signatures do not match") then last_err="Signature mismatch — uninstall existing app first."; break end
        if out_l:match("install_failed_version_downgrade") then last_err="Version downgrade blocked — uninstall first."; break end
    end
    return false,last_err
end

local function install_selected(entries,idxs,sess)
    local results,total={},#idxs
    for pos,idx in ipairs(idxs) do
        local apk=entries[idx]; local ok,out=false,"Download failed."
        local dOk,dR=pcall(dl_apk,sess,apk,pos,total)
        if not dOk then push_debug("DL","err: "..tostring(dR)); out="Download error: "..short(tostring(dR),120)
        else
            mdelay(pos,total,pos*5)
            local iOk,iSuc,iMsg=pcall(inst_apk,dR)
            if iOk then ok=iSuc; out=iMsg or (iSuc and "Success" or "Failed")
            else ok=false; out="Install error: "..short(tostring(iSuc),120); push_debug("INST","err: "..tostring(iSuc)) end
            os.remove(dR)
        end
        if ok then mark_installed(apk.name) end
        mdelay(pos,total,pos*7,1,0.2)
        results[#results+1]={apk.name,ok,out}
        prog((ok and "Installed " or "Failed ")..pos.."/"..total,apk.name,out,ok and "success" or "danger")
        sleep(ok and 0.6 or 1.2)
    end
    return results
end

local ACT_INSTALL=1; local ACT_REFRESH=2; local ACT_BACK=3; local ACT_COUNT=3

local function render_catalog(entries,sel_set,cursor,msg,inst_set)
    clear(); draw_header("Download Clones"); local w=tw(); local inn=w-2
    local sel_cnt=0; local sel_sz=0; local tot_sz=0; local inst_cnt=0
    for _ in pairs(sel_set) do sel_cnt=sel_cnt+1 end
    for i,e in ipairs(entries) do
        tot_sz=tot_sz+(e.size or 0); if sel_set[i] then sel_sz=sel_sz+(e.size or 0) end
        if inst_set[e.name] then inst_cnt=inst_cnt+1 end
    end
    box("Session",{
        kv_row("Device",short(DEVICE_LABEL,36),C.text,w),
        kv_row("Selected",sel_cnt.."/"..#entries.."  ("..hsize(sel_sz)..")",C.accent,w),
        kv_row("Installed locally",tostring(inst_cnt).."/"..#entries,inst_cnt>0 and C.installed or C.muted,w),
    },C.border_hi)
    if msg then box("",{notice_row(msg[1],msg[2])},TONES[msg[1]] or C.border_hi) end

    io.write(col("+-- Catalog "..string.rep("-",math.max(0,inn-12)).."+",C.border_hi).."\n")
    for i,e in ipairs(entries) do
        local active=cursor==i; local sel=sel_set[i]==true; local installed=inst_set[e.name]==true
        local marker=sel and col("[x]",C.success,C.bold) or col("[ ]",C.muted)
        local inst_tag=installed and col(" *",C.installed) or ""
        local arrow=active and col(" > ",C.accent,C.bold) or "   "
        local right=col(hsize(e.size),C.muted)
        local nw=inn-3-vlen(marker)-1-vlen(right)-vlen(inst_tag)-3
        local name=trunc(e.name,math.max(8,nw))
        local gap=string.rep(" ",math.max(1,inn-2-3-vlen(marker)-1-vlen(name)-vlen(inst_tag)-vlen(right)-1))
        local line=arrow..marker.." "
            ..(active and col(name,C.accent,C.bold) or (installed and col(name,C.installed) or col(name,C.text)))
            ..inst_tag..gap..right
        local bg=active and C.bg_hi or (sel and C.bg_sel or (installed and C.bg_inst or C.bg_row))
        io.write(col("|",C.border_hi)..bg..pad_r(line,inn-2)..C.reset..col("|",C.border_hi).."\n")
    end
    io.write(col("+--"..string.rep("-",inn-2).."+",C.border_hi).."\n")
    local actions={{ACT_INSTALL,"[+]","  Install / Update selected",C.success},{ACT_REFRESH,"[~]","  Refresh catalog",C.accent},{ACT_BACK,"[<]","  Back to menu",C.danger}}
    for _,ac in ipairs(actions) do
        local idx=#entries+ac[1]; local active=cursor==idx
        local ico=col(ac[2].." ",ac[4],active and C.bold or "")
        local lbl=active and col(ac[3],C.accent,C.bold) or col(ac[3],C.text)
        local line=(active and col(" > ",C.accent,C.bold) or "   ")..ico..lbl
        local bg=active and C.bg_hi or C.bg_row
        io.write(col("|",C.border_hi)..bg..pad_r(line,inn-2)..C.reset..col("|",C.border_hi).."\n")
    end
    io.write(col("+"..string.rep("-",inn).."+",C.border_hi).."\n")
    box("",{pad_c(col("Up/Down",C.accent).." Move  "..col("Space",C.accent).." Toggle  "..col("A",C.accent).." All  "..col("Enter",C.accent).." Confirm  "..col("Q",C.accent).." Back  "..col("*",C.installed).."=installed",tw()-2)},C.border)
end

local function render_summ(results)
    clear(); draw_header("Install Summary"); local ok_n,fail_n=0,0
    for _,r in ipairs(results) do if r[2] then ok_n=ok_n+1 else fail_n=fail_n+1 end end
    local rows={kv_row("Installed/Updated",tostring(ok_n),C.success,tw()),kv_row("Failed",tostring(fail_n),fail_n>0 and C.danger or C.muted,tw()),""}
    for _,r in ipairs(results) do
        local icon=r[2] and col("[OK] ",C.success,C.bold) or col("[!!] ",C.danger,C.bold)
        rows[#rows+1]=icon..col(trunc(r[1],tw()-10),r[2] and C.text or C.warning)
        if r[3] and r[3]~="" then rows[#rows+1]=col("     > "..trunc(r[3],tw()-12),C.muted) end
    end
    rows[#rows+1]=""; rows[#rows+1]=col("Press Enter to return.",C.dim)
    box("Results",rows,C.border_hi)
    io.write("\n"..col("  > ",C.accent)); io.flush(); io.read("*l")
end

local function ensure_access(hwid,lbl)
    local key=load_lic(); if not key then return "failed","auto login failed" end
    push_debug("AUTH","auto login")
    local st,msg=do_autologin(key,hwid,lbl)
    if st=="valid" then return "valid",msg end
    if st=="server" then return "server",msg end
    os.remove(LIC_PATH); return "failed","auto login failed"
end

local function run_catalog(hwid,lbl)
    local msg=nil
    prog("Loading","Fetching clone catalog...","Contacting Gofile...","accent")
    local ok_s,sess,items=pcall(gf_new_session)
    if not ok_s then push_debug("GOFILE",tostring(sess)); show_error("Load Failed","Unable to fetch clone list: "..short(tostring(sess),80)); return "back" end
    if #items==0 then push_debug("GOFILE","empty"); show_error("Load Failed","No clones were found."); return "back" end

    local sel_set={}; local cursor=1; local total=#items+ACT_COUNT
    local inst_set=get_installed_set()
    for i,e in ipairs(items) do if inst_set[e.name] then sel_set[i]=true end end

    while true do
        inst_set=get_installed_set()
        render_catalog(items,sel_set,cursor,msg,inst_set); msg=nil
        local key=read_key()
        if     key=="UP"    then cursor=((cursor-2)%total)+1
        elseif key=="DOWN"  then cursor=(cursor%total)+1
        elseif key=="Q"     then return "back"
        elseif key=="SPACE" then if cursor<=#items then sel_set[cursor]=not sel_set[cursor] or nil end
        elseif key=="A" then
            local cnt=0; for _ in pairs(sel_set) do cnt=cnt+1 end
            if cnt==#items then sel_set={} else for i=1,#items do sel_set[i]=true end end
        elseif key=="ENTER" then
            if cursor<=#items then
                sel_set[cursor]=not sel_set[cursor] or nil
            elseif cursor==#items+ACT_INSTALL then
                local cnt=0; for _ in pairs(sel_set) do cnt=cnt+1 end
                if cnt==0 then msg={"warning","Select at least one clone first."}; goto cont end
                local ast,amsg=ensure_access(hwid,lbl)
                if ast=="server" then show_error("Access",amsg); return "auth_fail" end
                if ast~="valid"  then status_box("Access",amsg,"danger"); sleep(1); return "auth_fail" end
                local idxs={}; for i=1,#items do if sel_set[i] then idxs[#idxs+1]=i end end
                render_summ(install_selected(items,idxs,sess))
                sel_set={}; inst_set=get_installed_set()
                for i,e in ipairs(items) do if inst_set[e.name] then sel_set[i]=true end end
                msg={"success","Install run completed."}
            elseif cursor==#items+ACT_REFRESH then
                local ast,amsg=ensure_access(hwid,lbl)
                if ast=="server" then show_error("Access",amsg); return "auth_fail" end
                if ast~="valid"  then status_box("Access",amsg,"danger"); sleep(1); return "auth_fail" end
                prog("Refreshing","Fetching fresh catalog...","Contacting Gofile...","accent")
                local rok,rs,ri=pcall(gf_new_session)
                if rok then
                    sess=rs; items=ri; sel_set={}; inst_set=get_installed_set()
                    for i,e in ipairs(items) do if inst_set[e.name] then sel_set[i]=true end end
                    cursor=1; total=#items+ACT_COUNT; msg={"success","Catalog refreshed."}
                else push_debug("GOFILE","refresh "..tostring(rs)); show_error("Refresh","Refresh failed: "..short(tostring(rs),80)) end
            elseif cursor==#items+ACT_BACK then
                return "back"
            end
        end
        ::cont::
    end
end

local MENU_ITEMS={{num="1",icon="[+]",label="Download Clones",color=C.accent,enabled=true},{num="2",icon="[~]",label="Soon",color=C.soon,enabled=false}}

local function render_main_menu(cursor,notice)
    clear(); draw_header(); local w=tw(); local inn=w-2
    local cfg=load_clone_cfg(); local n_inst=#(cfg.installed or {})
    local last_ts=cfg.last_install and os.date("%d %b %H:%M",cfg.last_install) or "never"
    box("",{
        kv_row("Device",short(DEVICE_LABEL,38),C.text,w),
        kv_row("License","Active",C.success,w),
        kv_row("Clones installed",tostring(n_inst).."  (last: "..last_ts..")",n_inst>0 and C.installed or C.muted,w),
    },C.border_hi)
    if notice then box("",{notice_row(notice[1],notice[2])},TONES[notice[1]] or C.border_hi) end
    io.write(col("+-- Menu "..string.rep("-",math.max(0,inn-9)).."+ ",C.border_hi).."\n")
    for i,item in ipairs(MENU_ITEMS) do
        local active=cursor==i
        local arrow=active and col(" > ",C.accent,C.bold) or "   "
        local num=col(item.num..". ",C.muted)
        local ico=col(item.icon.." ",item.color,active and C.bold or "")
        local lbl=item.enabled and (active and col(item.label,item.color,C.bold) or col(item.label,C.text)) or col(item.label,C.dim)
        local badge=not item.enabled and col(" [soon]",C.soon,C.italic) or ""
        local used=3+vlen(num)+vlen(item.icon)+1+vlen(item.label)+vlen(badge)+2
        local gap=string.rep(" ",math.max(1,inn-2-used))
        local line=arrow..num..ico..lbl..gap..badge
        local bg=active and C.bg_hi or C.bg_row
        io.write(col("|",C.border_hi)..bg..pad_r(line,inn-2)..C.reset..col("|",C.border_hi).."\n")
    end
    io.write(col("+--"..string.rep("-",inn-2).."+",C.border_hi).."\n")
    local act_exit=cursor==#MENU_ITEMS+1
    local exit_line=(act_exit and col(" > ",C.danger,C.bold) or "   ")..col("[x]",C.danger,act_exit and C.bold or "")..(act_exit and col("  Exit",C.danger,C.bold) or col("  Exit",C.muted))
    local bg_exit=act_exit and C.bg_hi or C.bg_row
    io.write(col("|",C.border_hi)..bg_exit..pad_r(exit_line,inn-2)..C.reset..col("|",C.border_hi).."\n")
    io.write(col("+"..string.rep("-",inn).."+",C.border_hi).."\n")
    box("",{pad_c(col("Up/Down",C.accent).." Navigate  "..col("Enter",C.accent).." Select  "..col("Q",C.accent).." Quit",tw()-2)},C.border)
end

local function run_main_menu(hwid,lbl)
    local cursor=1; local notice=nil; local total=#MENU_ITEMS+1
    while true do
        render_main_menu(cursor,notice); notice=nil; local key=read_key()
        if     key=="UP"    then cursor=((cursor-2)%total)+1
        elseif key=="DOWN"  then cursor=(cursor%total)+1
        elseif key=="Q"     then return 0
        elseif key=="ENTER" then
            if cursor==#MENU_ITEMS+1 then return 0 end
            local item=MENU_ITEMS[cursor]
            if not item.enabled then notice={"soon","This feature is coming soon!"}
            elseif cursor==1 then
                local r=run_catalog(hwid,lbl)
                if r=="auth_fail" then notice={"warning","Session expired. Please re-authenticate."} end
            end
        end
    end
end

local function draw_license_screen(notice)
    clear(); draw_header("Access"); local w=tw(); local rows={}
    if notice then rows[#rows+1]=notice_row(notice[1],notice[2]); rows[#rows+1]="" end
    rows[#rows+1]=col("Enter your license key to continue.",C.text,C.bold); rows[#rows+1]=""
    rows[#rows+1]=kv_row("Saved profile",load_lic() and "Detected" or "Not found",load_lic() and C.success or C.muted,w)
    rows[#rows+1]=kv_row("Validation","Hosted API",C.accent,w); rows[#rows+1]=""
    rows[#rows+1]=col("Need your key? Run ",C.muted)..col("/key_information",C.accent,C.bold)..col(" in the Discord bot.",C.muted)
    box("Access",rows,C.border_hi)
end
local function draw_verify_screen(lbl,notice)
    clear(); draw_header("Verification"); local w=tw(); local rows={}
    rows[#rows+1]=kv_row("Device",short(lbl,40),C.text,w); rows[#rows+1]=""
    if notice then rows[#rows+1]=notice_row(notice[1],notice[2]); rows[#rows+1]="" end
    rows[#rows+1]=col("Enter the Termux verification code.",C.text,C.bold); rows[#rows+1]=""
    rows[#rows+1]=kv_row("Mode","One-time secure code",C.accent,w); rows[#rows+1]=""
    rows[#rows+1]=col("Run ",C.muted)..col("/get-termux-code",C.accent,C.bold)..col(" in the bot — paste from your DMs.",C.muted)
    box("Verification",rows,C.border_hi)
end
local function try_saved_login(hwid,lbl)
    local key=load_lic(); if not key then return "missing",nil end
    push_debug("AUTH","checking saved license"); status_box("Access","Checking saved license...","warning")
    local st,msg=do_autologin(key,hwid,lbl)
    if st=="valid" then return "valid",key end
    if st=="server" then return "server",msg end
    os.remove(LIC_PATH); return "failed","auto login failed"
end

local function main()
    mkdirp(LROOT); mkdirp(TEMP_ROOT)
    local hwid,lbl=device_id(); DEVICE_LABEL=lbl
    push_debug("BOOT","base "..TOOL_API.base)
    push_debug("BOOT","device "..short(lbl,48).." hwid "..hwid:sub(1,12))
    local notice=nil
    local sl_st,sl_msg=try_saved_login(hwid,lbl)
    if sl_st=="valid" then run_main_menu(hwid,lbl); os.exit(0) end
    if sl_st=="server" then show_error("Access",tostring(sl_msg)); os.exit(1) end
    if sl_st=="failed" then notice={"warning",tostring(sl_msg)} end
    while true do
        draw_license_screen(notice); notice=nil
        local key=prompt_val("License key")
        if key=="" then notice={"danger","No license key provided."}; goto lic_next end
        status_box("Access","Checking license...","warning")
        local ls,lm=chk_license(key)
        if ls=="server" then show_error("Access",lm); os.exit(1) end
        if ls~="valid" then notice={"danger","Key not recognised — try again or run /key_information."}; goto lic_next end
        local tc_note={"warning","Run /get-termux-code in the bot, then paste the code from your DMs."}
        while true do
            draw_verify_screen(lbl,tc_note)
            local tc=prompt_val("Termux code")
            if tc=="" then tc_note={"danger","No code entered."}; goto tc_next end
            status_box("Verification","Validating...","warning")
            local cs,cm=do_validate(key,tc,hwid,lbl)
            if cs=="server" then show_error("Verification",cm); os.exit(1) end
            if cs=="valid" then save_lic(key,hwid,lbl); run_main_menu(hwid,lbl); os.exit(0) end
            if cs=="invalid_license" then os.remove(LIC_PATH); notice={"danger","License no longer valid. Please re-enter."}; break end
            if cs=="expired" then tc_note={"warning","Code expired — run /get-termux-code again."}; goto tc_next end
            if cs=="hwid_limit_reached" then tc_note={"danger","HWID limit reached. Reset HWIDs first."}; goto tc_next end
            tc_note={"danger","Invalid code. Please try again."}
            ::tc_next::
        end
        ::lic_next::
    end
end

local ok,err=pcall(main)
if not ok then io.write("\n[fatal] "..tostring(err).."\n"); os.exit(1) end
