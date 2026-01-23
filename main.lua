-- Developed by Ali Haider & AI Optimized
require "import"
import "android.content.Context"
import "android.location.Geocoder"
import "android.location.LocationManager"
import "android.media.AudioManager"
import "android.media.MediaPlayer"
import "java.util.Locale"
import "java.net.URL"
import "java.util.Scanner"
import "android.app.Notification"
import "android.app.NotificationChannel"
import "android.app.NotificationManager"
import "android.os.PowerManager"

-- Configuration
local CURRENT_VERSION = "1.0"
local GITHUB_URL = "https://raw.githubusercontent.com/zayanjani93-cmd/Encrypted.-/main/"
local PLUGIN_PATH = "/storage/emulated/0/解说/Plugins/Momin Assistant -/main.lua"

-- 1. Global Restart Function
_G.restartMominNow = function()
  service.setSharedData("prayer_active", "false")
  service.stopForeground(true)
  service.handler.postDelayed(Runnable({
    run = function()
      service.click({{"Momin Assistant -", 1}})
    end
  }), 1000)
end

-- 2. Update Logic
_G.checkMominUpdate = function()
  Http.get(GITHUB_URL .. "version.txt", function(code, onlineV)
    if code == 200 and onlineV then
      local v = tostring(onlineV):gsub("%s+", "")
      if v ~= CURRENT_VERSION then
        service.handler.post(function()
          local dlg = LuaDialog(service or activity)
          dlg.setTitle("Update Available")
          dlg.setMessage("Momin Assistant ka naya update dastiyab hai. Kya aap update karna chahte hain?")
          dlg.setButton("Update Now", function()
            dlg.dismiss()
            service.speak("Update download ho rahi hai...")
            Http.get(GITHUB_URL .. "main.lua", function(c, content)
              if c == 200 and content and #content > 1000 then
                local f = io.open(PLUGIN_PATH, "w")
                if f then
                  f:write(content)
                  f:close()
                  local resDlg = LuaDialog(service or activity)
                  resDlg.setTitle("Success")
                  resDlg.setMessage("Momin Assistant update ho gaya hai. Restart karein?")
                  resDlg.setButton("Restart Now", function()
                    resDlg.dismiss()
                    _G.restartMominNow()
                  end)
                  resDlg.setButton2("Later", function() resDlg.dismiss() end)
                  resDlg.show()
                end
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

-- 3. Global Azan Function
_G.playAzan = function()
  pcall(function()
    if service.getSharedData("azan_playing") == "true" then return end
    service.setSharedData("azan_playing", "true")
    local mp = MediaPlayer()
    mp.setDataSource("/storage/emulated/0/解说/Plugins/Momin Assistant -/azan.mp3")
    mp.setAudioStreamType(AudioManager.STREAM_MUSIC)
    mp.setVolume(1.0, 1.0)
    mp.prepareAsync()
    mp.setOnPreparedListener(MediaPlayer.OnPreparedListener{onPrepared = function(m) m.start() end})
    mp.setOnCompletionListener(MediaPlayer.OnCompletionListener{onCompletion = function(m)
      pcall(function() m.release() end)
      service.setSharedData("azan_playing", "false")
    end})
  end)
end

-- 4. Main Service Control
local status = service.getSharedData("prayer_active")
if status == "true" then
  service.setSharedData("prayer_active", "false")
  service.stopForeground(true)
  service.speak("Sadaqallahul Azim. Developed by Ali Haider.")
  return true
else
  service.setSharedData("prayer_active", "true")
  service.setSharedData("last_announced", "") 
  service.setSharedData("is_speaking", "false")
  service.setSharedData("azan_playing", "false")
  
  pcall(function()
    local nm = service.getSystemService(Context.NOTIFICATION_SERVICE)
    if android.os.Build.VERSION.SDK_INT >= 26 then
      nm.createNotificationChannel(NotificationChannel("momin_chan", "Namaz Reminder", NotificationManager.IMPORTANCE_LOW))
    end
    local notification = Notification.Builder(service, "momin_chan")
      .setContentTitle("Momin Assistant")
      .setContentText("Monitoring Active")
      .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
      .setOngoing(true).build()
    service.startForeground(1, notification)
  end)
  service.speak("Bismillah hir-Rahman nir-Rahim.")
end

_G.checkMominUpdate()

-- 5. Main Task
task(function()
  Thread.sleep(2000)
  local lat, lon = 25.3176, 82.9739
  local city = service.getSharedData("p_city") or "Dina"
  local country = service.getSharedData("p_country") or "Pakistan"
  
  pcall(function()
    local lm = service.getSystemService(Context.LOCATION_SERVICE)
    local loc = lm.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
    if loc then 
      lat, lon = loc.getLatitude(), loc.getLongitude() 
      local gc = Geocoder(service, Locale.getDefault())
      local list = gc.getFromLocation(lat, lon, 1)
      if list and list.size() > 0 then 
        city = list.get(0).getLocality() or city
        country = list.get(0).getCountryName() or country
        service.setSharedData("p_city", city)
        service.setSharedData("p_country", country)
      end
    end
  end)

  local school_val = (country:find("Pakistan") or country:find("India")) and 1 or 0
  local url = string.format("https://api.aladhan.com/v1/timings?latitude=%f&longitude=%f&method=1&school=%d", lat, lon, school_val)
  
  local ok, res = pcall(function()
    local conn = URL(url).openConnection()
    conn.setConnectTimeout(5000)
    return Scanner(conn.getInputStream()).useDelimiter("\\A").next()
  end)

  if ok and res ~= "" then
    service.setSharedData("prayer_res", res)
  else
    res = service.getSharedData("prayer_res")
  end

  if res then
    local function parse(k) return res:match('"'..k..'":"?([^",}]+)"?') end
    local f_t, s_t, d_t, a_t, m_t, i_t = parse("Fajr"), parse("Sunrise"), parse("Dhuhr"), parse("Asr"), parse("Maghrib"), parse("Isha")
    
    local function to_m(str)
      local h, m = str:match("(%d+):(%d+)")
      return (tonumber(h)*60) + tonumber(m)
    end
    
    local now_v = (tonumber(os.date("%H"))*60) + tonumber(os.date("%M"))
    local h_day = tonumber(res:match('"day":"(%d+)"') or 0)
    if now_v < to_m(m_t) then h_day = h_day - 1 end
    
    local h_month = res:match('"en":"([^"]+)"') or "Month"
    local h_year = res:match('"year":"([^"]+)"') or ""

    local p_list = {
      {n="Tahajjud", v=to_m(f_t)-90}, {n="Fajr", v=to_m(f_t)},
      {n="Ishraq", v=to_m(s_t)+20}, {n="Chasht", v=to_m(s_t)+150},
      {n="Zohar", v=to_m(d_t)}, {n="Asar", v=to_m(a_t)},
      {n="Maghrib", v=to_m(m_t)}, {n="Isha", v=to_m(i_t)}
    }
    
    local cur_n = "Isha"
    for _, p in ipairs(p_list) do if now_v >= p.v then cur_n = p.n end end
    local nxt_n, nxt_v = "Tahajjud", p_list[1].v
    for _, p in ipairs(p_list) do if p.v > now_v then nxt_n = p.n; nxt_v = p.v; break end end
    
    local diff = nxt_v - now_v
    if diff < 0 then diff = diff + 1440 end
    local hr, mn = math.floor(diff/60), diff%60

    local msg = "Welcome to " .. country .. ". Aaj " .. os.date("%A, %d %B") .. ". Islami tareekh " .. h_day .. " " .. h_month .. " " .. h_year .. " Hijri hai. " ..
          "Is waqt " .. city .. " mein " .. cur_n .. " ka waqt hai. " ..
          "Agali namaz " .. nxt_n .. " hai jis mein " .. (hr > 0 and hr .. " ghante " or "") .. mn .. " minute baaki hain."
    
    service.setSharedData("is_speaking", "true")
    service.speak(msg)
    service.setSharedData("is_speaking", "false")
  end
end)

-- 6. Monitoring Timer (Fixed & Enhanced)
service.timer(function()
  if service.getSharedData("prayer_active") ~= "true" then return false end
  if service.getSharedData("is_speaking") == "true" or service.getSharedData("azan_playing") == "true" then return true end
  
  local current_time = os.date("%H:%M")
  local res = service.getSharedData("prayer_res")
  if not res or res == "" then return true end

  -- Safety Check for playAzan
  if type(_G.playAzan) ~= "function" then
    _G.playAzan = function()
      pcall(function()
        if service.getSharedData("azan_playing") == "true" then return end
        service.setSharedData("azan_playing", "true")
        local mp = MediaPlayer()
        mp.setDataSource("/storage/emulated/0/解说/Plugins/Momin Assistant -/azan.mp3")
        mp.setAudioStreamType(AudioManager.STREAM_MUSIC)
        mp.setVolume(1.0, 1.0)
        mp.prepareAsync()
        mp.setOnPreparedListener(MediaPlayer.OnPreparedListener{onPrepared = function(m) m.start() end})
        mp.setOnCompletionListener(MediaPlayer.OnCompletionListener{onCompletion = function(m)
          pcall(function() m.release() end)
          service.setSharedData("azan_playing", "false")
        end})
      end)
    end
  end

  local function parse(k) return res:match('"'..k..'":"?([^",}]+)"?') end
  local timings = {Fajr=parse("Fajr"), Zohar=parse("Dhuhr"), Asar=parse("Asr"), Maghrib=parse("Maghrib"), Isha=parse("Isha")}

  for name, p_time in pairs(timings) do
    if current_time == p_time and current_time ~= service.getSharedData("last_announced") then
      -- 1. Start Azan Immediately
      pcall(function() _G.playAzan() end)
      service.setSharedData("last_announced", current_time)

      -- 2. Delay Announcement by 60 seconds (1 minute)
      service.handler.postDelayed(Runnable({
        run = function()
          local city = service.getSharedData("p_city") or "City"
          local name_final = (name == "Zohar" and os.date("%A") == "Friday") and "Jummah" or name
          local announcement = "Tavajjo farmaye. Is waqt " .. city .. " mein " .. name_final .. " ka waqt ho gaya hai."
          
          -- Special Fajr message
          if name == "Fajr" then
            announcement = announcement .. " As-salatu khayrum minan-nawm. Namaz neend se behtar hai."
          end
          
          service.speak(announcement)
        end
      }), 60000)
      
      break
    end
  end
  return true
end, 10000)

return true