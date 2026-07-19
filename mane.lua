require "import"
import "android.content.Context"
import "android.location.Geocoder"
import "android.location.LocationManager"
import "java.util.Locale"
import "java.net.URL"
import "java.util.Scanner"
import "android.app.Notification"
import "android.app.NotificationChannel"
import "android.app.NotificationManager"
import "android.os.PowerManager"
import "android.os.Build"
import "java.io.File"
import "android.content.Intent"
import "android.content.IntentFilter"
import "android.content.BroadcastReceiver"
import "android.net.ConnectivityManager"
import "android.speech.tts.TextToSpeech"
import "android.provider.Settings"

if not Thread then
    if luajava and luajava.createThread then
        Thread = function(f) luajava.createThread(f) end
    else
        Thread = function(f) f() end 
    end
end
_G.Thread = Thread 

if not _G.task then
    _G.task = function(f)
        Thread(f)
    end
end

local pluginSpeak = function(msg)
    local enginePkg = service.getSharedData("momin_tts_engine")
    if enginePkg and enginePkg ~= "" then
        if _G.mominTTS_Engine ~= enginePkg then
            if _G.mominTTS then pcall(function() _G.mominTTS.shutdown() end) end
            _G.mominTTS = nil
            _G.mominTTS_Engine = enginePkg
        end
        if not _G.mominTTS then
            _G.mominTTS = TextToSpeech(service, TextToSpeech.OnInitListener{
                onInit = function(status)
                    if status == TextToSpeech.SUCCESS then
                        _G.mominTTS.speak(msg, TextToSpeech.QUEUE_FLUSH, nil, "momin_tts")
                    else
                        service.speak(msg)
                    end
                end
            }, enginePkg)
        else
            _G.mominTTS.speak(msg, TextToSpeech.QUEUE_FLUSH, nil, "momin_tts")
        end
    else
        service.speak(msg)
    end
end

local runMominTask, checkMominUpdate, restartMominNow
local showMainDialog, showSettingsDialog, showAboutDialog

local PLUGIN_DIR = "/storage/emulated/0/解说/Plugins/Momin Assistant -/"
local PLUGIN_PATH = PLUGIN_DIR .. "main.lua"
local VERSION_FILE = PLUGIN_DIR .. "version.txt"
local GITHUB_URL = "https://raw.githubusercontent.com/zayanjani93-cmd/Encrypted.-/main/"

local lastScreenUnlockAnnounce = ""
local lastMaghribUpdate = "" 

local function getLocalVersion()
    local f = io.open(VERSION_FILE, "r")
    if f then
        local v = f:read("*a"):gsub("%s+", "")
        f:close()
        return v
    end
    return "1.0"
end
local CURRENT_VERSION = getLocalVersion()

_G.restartMominNow = function()
    service.setSharedData("prayer_active", "false")
    service.stopForeground(true)
    if _G.mominWakeLock and _G.mominWakeLock.isHeld() then
        _G.mominWakeLock.release()
        _G.mominWakeLock = nil
    end
    if _G.mominScreenUnlockReceiver then
        pcall(function() service.unregisterReceiver(_G.mominScreenUnlockReceiver) end)
        _G.mominScreenUnlockReceiver = nil
    end
    service.handler.post(luajava.createProxy("java.lang.Runnable", {
        run = function()
            service.click({{"Momin Assistant -", 1}})
        end
    }))
end
restartMominNow = _G.restartMominNow 

showSettingsDialog = function()
    service.handler.post(function()
        local InternalTextToSpeech = luajava.bindClass("android.speech.tts.TextToSpeech")
        local tts = InternalTextToSpeech(service, InternalTextToSpeech.OnInitListener{
            onInit = function(status) end
        })
        local engines = tts.getEngines()
        local names = {}
        local pkgs = {}
        if engines then
            for i=0, engines.size()-1 do
                local e = engines.get(i)
                table.insert(names, e.label)
                table.insert(pkgs, e.name)
            end
        end
        pcall(function() tts.shutdown() end)

        local dlg = LuaDialog(service or activity)
        dlg.setTitle("Settings (Select TTS)")
        
        local items = {}
        for _, name in ipairs(names) do
            table.insert(items, tostring(name))
        end
        
        local ArrayList = luajava.bindClass("java.util.ArrayList")
        local jItems = ArrayList()
        for i=1, #items do
            jItems.add(tostring(items[i]))
        end
        
        dlg.setItems(jItems)
        
        local ok = pcall(function()
            dlg.setOnItemClickListener(function(parent, view, pos, id)
                local index = pos + 1
                if names[index] then
                    service.setSharedData("momin_tts_engine", pkgs[index])
                    pluginSpeak("Selected TTS: " .. tostring(names[index]))
                    dlg.dismiss()
                end
            end)
        end)
        
        if not ok then
            pcall(function()
                dlg.getListView().setOnItemClickListener(function(parent, view, pos, id)
                    local index = pos + 1
                    if names[index] then
                        service.setSharedData("momin_tts_engine", pkgs[index])
                        pluginSpeak("Selected TTS: " .. tostring(names[index]))
                        dlg.dismiss()
                    end
                end)
            end)
        end
        
        dlg.setButton("Back", function()
            dlg.dismiss()
            showMainDialog()
        end)
        
        dlg.show()
    end)
end

showAboutDialog = function()
    service.handler.post(function()
        local dlg = LuaDialog(service or activity)
        dlg.setTitle("About Momin Assistant")
        dlg.setMessage("Contact us to join our WhatsApp group Tech for V.I. Gaming Club and Tech for V.I. Technology group.")
        
        dlg.setButton("Back", function()
            dlg.dismiss()
            showMainDialog()
        end)
        
        dlg.setButton2("Join", function()
            local InternalIntent = luajava.bindClass("android.content.Intent")
            local Uri = luajava.bindClass("android.net.Uri")
            local url = "https://wa.me/923019031567?text=Hello!%20I%20want%20to%20join%20Tech%20for%20V.I.%20Gaming%20Club%20and%20Tech%20for%20V.I.%20Technology%20group.%0A%0ASend%20via%20Momin%20assistant."
            
            local intent = InternalIntent(InternalIntent.ACTION_VIEW, Uri.parse(url))
            intent.addFlags(InternalIntent.FLAG_ACTIVITY_NEW_TASK)
            pcall(function() service.startActivity(intent) end)
            dlg.dismiss()
        end)
        
        dlg.show()
    end)
end

showMainDialog = function()
    service.handler.post(function()
        local dlg = LuaDialog(service or activity)
        dlg.setTitle("Welcome to Momin Assistant")
        dlg.setMessage("Developed by Ali Haider")
        
        dlg.setButton("Close", function()
            dlg.dismiss()
        end)
        
        dlg.setButton2("Settings", function()
            dlg.dismiss()
            showSettingsDialog()
        end)
        
        dlg.setButton3("About", function()
            dlg.dismiss()
            showAboutDialog()
        end)
        
        dlg.show()
    end)
end

-- NEW ERROR CHECKING & CACHE FIX UPDATE LOGIC
_G.checkMominUpdate = function()
    Http.get(GITHUB_URL .. "version.txt?t=" .. os.time(), function(code, onlineV)
        if code == 200 and onlineV then
            local v = tostring(onlineV):gsub("%s+", "")
            if v ~= CURRENT_VERSION then
                service.handler.post(function()
                    local dlg = LuaDialog(service or activity)
                    dlg.setTitle("Update Available")
                    dlg.setMessage("Momin Assistant ka naya version ("..v..") dastiyab hai. Kya aap update karna chahte hain?")
                    dlg.setButton("Update Now", function()
                        dlg.dismiss()
                        service.speak("Update download ho rahi hai...")
                        
                        Http.get(GITHUB_URL .. "main.lua?t=" .. os.time(), function(c, content)
                            if c == 200 then
                                if content and #content > 1000 then
                                    local f = io.open(PLUGIN_PATH, "w")
                                    if f then 
                                        f:write(content) 
                                        f:close() 
                                        
                                        local vf = io.open(VERSION_FILE, "w")
                                        if vf then vf:write(v) vf:close() end
                                        
                                        local resDlg = LuaDialog(service or activity)
                                        resDlg.setTitle("Success")
                                        resDlg.setMessage("Momin Assistant update ho gaya hai. Restart karein?")
                                        resDlg.setButton("Restart Now", function()
                                            resDlg.dismiss()
                                            restartMominNow()
                                        end)
                                        resDlg.setButton2("Later", function() resDlg.dismiss() end)
                                        resDlg.show()
                                    else
                                        service.speak("Download ho gayi, par file save nahi ho saki. Apne folder ka naam check karein.")
                                    end
                                else
                                    service.speak("Error! GitHub se khali ya aadhi file download hui hai.")
                                end
                            else
                                service.speak("Download error! GitHub ne masla kiya hai. Code: " .. tostring(c))
                            end
                        end)
                    end)
                    dlg.setButton2("Later", function() dlg.dismiss() end)
                    dlg.show()
                end)
            end
        end
    end)
end
checkMominUpdate = _G.checkMominUpdate 

local function setupScreenUnlockListener()
    if _G.mominScreenUnlockReceiver then
        pcall(function() service.unregisterReceiver(_G.mominScreenUnlockReceiver) end)
        _G.mominScreenUnlockReceiver = nil
    end
    
    _G.hasAnnouncedUnlock = false

    _G.mominScreenUnlockReceiver = BroadcastReceiver({
        onReceive = function(context, intent)
            if service.getSharedData("prayer_active") ~= "true" then return end
            
            local action = intent.getAction()
            
            if action == Intent.ACTION_SCREEN_OFF then
                _G.hasAnnouncedUnlock = false
                
            elseif action == Intent.ACTION_USER_PRESENT then
                if _G.hasAnnouncedUnlock then return end
                _G.hasAnnouncedUnlock = true
                
                local now_time = os.date("%H:%M")
                if lastScreenUnlockAnnounce == now_time then return end
                lastScreenUnlockAnnounce = now_time

                _G.task(function() 
                    local InternalTextToSpeech = luajava.bindClass("android.speech.tts.TextToSpeech")
                    local function bgPluginSpeak(msg)
                        local enginePkg = service.getSharedData("momin_tts_engine")
                        if enginePkg and enginePkg ~= "" then
                            if _G.mominTTS_Engine ~= enginePkg then
                                if _G.mominTTS then pcall(function() _G.mominTTS.shutdown() end) end
                                _G.mominTTS = nil
                                _G.mominTTS_Engine = enginePkg
                            end
                            if not _G.mominTTS then
                                _G.mominTTS = InternalTextToSpeech(service, InternalTextToSpeech.OnInitListener{
                                    onInit = function(status)
                                        if status == InternalTextToSpeech.SUCCESS then
                                            _G.mominTTS.speak(msg, InternalTextToSpeech.QUEUE_FLUSH, nil, "momin_tts")
                                        else
                                            service.speak(msg)
                                        end
                                    end
                                }, enginePkg)
                            else
                                _G.mominTTS.speak(msg, InternalTextToSpeech.QUEUE_FLUSH, nil, "momin_tts")
                            end
                        else
                            service.speak(msg)
                        end
                    end
                    
                    Thread.sleep(1000)
                    
                    local function convertTo24Hour(timeStr)
                        if not timeStr then return "00:00" end
                        timeStr = tostring(timeStr):gsub("%s+", "")
                        if not timeStr:find("AM") and not timeStr:find("PM") then return timeStr end
                        local hour, minute, period = timeStr:match("(%d+):(%d+)(%a+)")
                        if not hour then hour, minute, period = timeStr:match("(%d+):(%d+)%s+(%a+)") end
                        if not hour then return "00:00" end
                        hour, minute = tonumber(hour), tonumber(minute)
                        period = period:upper()
                        if period == "PM" and hour ~= 12 then hour = hour + 12
                        elseif period == "AM" and hour == 12 then hour = 0 end
                        return string.format("%02d:%02d", hour, minute)
                    end
                    
                    local function toMinutes(str)
                        local h, m = str:match("(%d+):(%d+)")
                        return h and (tonumber(h) * 60 + tonumber(m)) or 0
                    end
                    
                    local function convertTo12Hour(time24)
                        if not time24 or time24 == "" then return "12:00 AM" end
                        local hour, minute = time24:match("(%d+):(%d+)")
                        if not hour then return "12:00 AM" end
                        hour, minute = tonumber(hour), tonumber(minute)
                        local period = hour >= 12 and "PM" or "AM"
                        hour = hour > 12 and hour - 12 or hour
                        hour = hour == 0 and 12 or hour
                        return string.format("%d:%02d %s", hour, minute, period)
                    end
                    
                    local function getAdjustedIslamicDate(res, currentMinutes, maghribMinutes)
                        local islamicMonths = {"Muharram al-Haram", "Safar al-Muzaffar", "Rabi' al-Awwal", "Rabi' al-Thani", "Jumada al-Awwal", "Jumada al-Thani", "Rajab al-Murajjab", "Sha'ban al-Mu'azzam", "Ramadan al-Mubarak", "Shawwal al-Mukarram", "Dhu al-Qi'dah", "Dhu al-Hijjah"}
                        
                        local parsed_day = tonumber(res:match('"hijri".-"day":"(%d+)"') or res:match('"day":"(%d+)"') or "1")
                        local h_month_num = tonumber(res:match('"hijri".-"month".-"number":(%d+)') or "1")
                        local h_month = islamicMonths[h_month_num] or "Muharram"
                        local h_year = res:match('"hijri".-"year":"([^"]+)"') or res:match('"year":"([^"]+)"') or "1445"
                        
                        local stored_day_str = service.getSharedData("api_hijri_day")
                        local api_day = parsed_day
                        if stored_day_str and stored_day_str ~= "" then
                            api_day = tonumber(stored_day_str)
                        else
                            service.setSharedData("api_hijri_day", tostring(parsed_day))
                        end
                        
                        local h_day = api_day
                        local last_sync = service.getSharedData("last_sync_date")
                        local today_str = os.date("%Y-%m-%d")
                        
                        if last_sync and last_sync ~= "" and last_sync ~= today_str then
                            if currentMinutes >= maghribMinutes then
                                h_day = api_day + 1
                            else
                                h_day = api_day
                            end
                        else
                            if currentMinutes >= maghribMinutes then
                                h_day = api_day
                            else
                                h_day = api_day - 1
                            end
                        end
                        
                        if h_day <= 0 then
                            h_day = 30
                            h_month_num = h_month_num - 1
                            if h_month_num <= 0 then
                                h_month_num = 12
                                h_year = tostring(tonumber(h_year) - 1)
                            end
                            h_month = islamicMonths[h_month_num] or "Muharram"
                        end
                        
                        if h_day > 30 then
                            h_day = 1
                            h_month_num = h_month_num + 1
                            if h_month_num > 12 then
                                h_month_num = 1
                                h_year = tostring(tonumber(h_year) + 1)
                            end
                            h_month = islamicMonths[h_month_num] or "Muharram"
                        end
                        
                        return tostring(h_day), h_month, h_year
                    end
                    
                    local f_t = service.getSharedData("fajr_time") or "00:00"
                    local s_t = service.getSharedData("sunrise_time") or "00:00"
                    local d_t = service.getSharedData("zohar_time") or "00:00" 
                    local a_t = service.getSharedData("asar_time") or "00:00"
                    local m_t = service.getSharedData("maghrib_time") or "00:00"
                    local i_t = service.getSharedData("isha_time") or "00:00"
                    
                    local f_min = toMinutes(f_t)
                    local s_min = toMinutes(s_t)
                    local d_min = toMinutes(d_t)
                    local a_min = toMinutes(a_t)
                    local m_min = toMinutes(m_t)
                    local i_min = toMinutes(i_t)
                    
                    local p_list_fixed = {
                        {n="Tahajjud", v= f_min - 90},
                        {n="Fajr", v= f_min},
                        {n="Ishraq", v= s_min + 20},
                        {n="Chasht", v= s_min + 150},
                        {n="Zohar", v= d_min},
                        {n="Asar", v= a_min},
                        {n="Maghrib", v= m_min},
                        {n="Isha", v= i_min}
                    }
                    
                    local res = service.getSharedData("prayer_res") 
                    if res and res ~= "" then
                        local now_v = toMinutes(os.date("%H:%M"))
                        local maghrib_v = m_min
                        local h_day, h_month, h_year = getAdjustedIslamicDate(res, now_v, maghrib_v)
                        
                        local cur_n = "Isha"
                        for _, p in ipairs(p_list_fixed) do
                            if now_v >= p.v then
                                cur_n = p.n
                            end
                        end
                        
                        local nxt_n = p_list_fixed[1].n
                        local nxt_v = p_list_fixed[1].v
                        for _, p in ipairs(p_list_fixed) do
                            if p.v > now_v then
                                nxt_n = p.n
                                nxt_v = p.v
                                break
                            end
                        end
                        
                        local diff = nxt_v - now_v
                        if diff < 0 then diff = diff + 1440 end
                        
                        local timeLeftStr = (diff < 60) and (diff .. " minute baaki hain") or (math.floor(diff/60) .. " ghante " .. (diff % 60) .. " minute baaki hain")
                        local display_v = nxt_v % 1440
                        local nxt_exact = convertTo12Hour(string.format("%02d:%02d", math.floor(display_v/60), display_v%60))
                        
                        local city = service.getSharedData("p_city") or "Dina"
                        local country = service.getSharedData("p_country") or "Pakistan"
                        
                        local msg = "Welcome to " .. country .. ". Aaj " .. os.date("%A, %d %B") .. 
                        ". Islami tareekh " .. h_day .. " " .. h_month .. " " .. h_year .. 
                        " Hijri hai. Is waqt " .. city .. " mein " .. cur_n .. 
                        " ka waqt hai. Agali namaz " .. nxt_n .. " hai jis mein " .. timeLeftStr .. ". Exact waqt " .. nxt_exact .. " hai."
                        
                        service.setSharedData("is_speaking", "true")
                        bgPluginSpeak(msg)
                        service.setSharedData("is_speaking", "false")
                    end
                end)
            end
        end
    })
    
    local filter = IntentFilter()
    filter.addAction(Intent.ACTION_USER_PRESENT)
    filter.addAction(Intent.ACTION_SCREEN_OFF)
    pcall(function() service.registerReceiver(_G.mominScreenUnlockReceiver, filter) end)
end

local System = luajava.bindClass("java.lang.System")
local current_time = System.currentTimeMillis()
local last_click_str = service.getSharedData("last_plugin_click_time")
local last_click = 0
if last_click_str and last_click_str ~= "" then
    last_click = math.floor(tonumber(last_click_str) or 0)
end
service.setSharedData("last_plugin_click_time", string.format("%.0f", current_time))

if last_click > 0 and (current_time - last_click) <= 5000 then
    service.setSharedData("last_plugin_click_time", "0")
    showMainDialog()
    return true
end

local status = service.getSharedData("prayer_active")
if status == "true" then
    service.setSharedData("prayer_active", "false")
    service.stopForeground(true)
    if _G.mominWakeLock and _G.mominWakeLock.isHeld() then 
        _G.mominWakeLock.release() 
        _G.mominWakeLock = nil 
    end
    if _G.mominScreenUnlockReceiver then
        pcall(function() service.unregisterReceiver(_G.mominScreenUnlockReceiver) end)
        _G.mominScreenUnlockReceiver = nil 
    end
    pluginSpeak("Sadaqallahul Azim. Momin Assistant band ho gaya hai.")
    return true
else
    service.setSharedData("prayer_active", "true")
    service.setSharedData("last_announced", "")
    service.setSharedData("is_speaking", "false")
    
    service.setSharedData("last_sync_date", "")
    service.setSharedData("prayer_res", "")
    service.setSharedData("api_hijri_day", "")
    
    setupScreenUnlockListener()
    checkMominUpdate()
    
    pluginSpeak("Bismillahir Rahmanir Raheem. Momin Assistant on ho gaya hai. Developed by Ali Haider.")
    return true
end
