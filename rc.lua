--Load library {{{
-- Standard awesome library--{{{
local gears = require("gears")
local awful = require("awful")
awful.rules = require("awful.rules")
require("awful.autofocus")
-- Widget and layout library
local wibox = require("wibox")
-- Theme handling library
local beautiful = require("beautiful")
-- Notification library
local naughty = require("naughty")
local menubar = require("menubar")
--}}}
-- Custome lib{{{
local fixwidthtextbox = require("fixwidthtextbox")
--}}}
--}}}

-- Custome variables{{{
local confdir = awful.util.getdir("config")
--}}}

-- {{{ Error handling
-- Custome{{{
function printError(str)
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Error",
                     text = str })
end
--}}}
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Oops, there were errors during startup!",
                     text = awesome.startup_errors })
end

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.connect_signal("debug::error", function (err)
        -- Make sure we don't go into an endless error loop
        if in_error then return end
        in_error = true

        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "Oops, an error happened!",
                         text = err })
        in_error = false
    end)
end
-- }}}

-- {{{ Variable definitions
-- Themes define colours, icons, and wallpapers
beautiful.init(awful.util.getdir("config") .. "/theme.lua")

-- This is used later as the default terminal and editor to run.
terminal = "gnome-terminal"
editor = os.getenv("EDITOR") or "gvim"
editor_cmd = terminal .. "-x bash -c " .. editor

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
-- If you do not like this or do not have such a key,
-- I suggest you to remap Mod4 to another key using xmodmap or other tools.
-- However, you can use another modifier like Mod1, but it may interact with others.
altkey = "Mod1"
modkey = "Mod4"

-- Table of layouts to cover with awful.layout.inc, order matters.
local layouts =
{
    awful.layout.suit.floating,
    awful.layout.suit.tile,
    awful.layout.suit.tile.left,
    awful.layout.suit.tile.bottom,
    awful.layout.suit.tile.top,
    awful.layout.suit.fair,
    awful.layout.suit.fair.horizontal,
    awful.layout.suit.spiral,
    awful.layout.suit.spiral.dwindle,
    awful.layout.suit.max,
    awful.layout.suit.max.fullscreen,
    awful.layout.suit.magnifier
}
-- }}}

-- {{{ Wallpaper
if beautiful.wallpaper then
    for s = 1, screen.count() do
        gears.wallpaper.maximized(beautiful.wallpaper, s, true)
    end
end
-- }}}

-- {{{ Tags
-- Define a tag table which hold all screen tags.
tags = {
   names  = {1, 2, 3, 4, 5, 6, 7, 8, 9},
   layout = { layouts[2], layouts[2], layouts[2], layouts[2], layouts[2],
              layouts[2], layouts[2], layouts[2], layouts[6]
 }}

for s = 1, screen.count() do
     tags[s] = awful.tag(tags.names, s, tags.layout)
end
-- }}}

-- {{{ Menu
-- Create a laucher widget and a main menu
myawesomemenu = {
   -- { "manual", terminal .. " -x zsh -ic \"man awesome\"" },
   -- { "edit config", editor_cmd .. " " .. awesome.conffile },
   { "restart(&r)", awesome.restart }
   -- { "quit", awesome.quit }
}

mymainmenu = awful.menu({ items = { { "awesome(&a)", myawesomemenu, beautiful.awesome_icon },
                                    { "shutdown(&s)", "systemctl poweroff" },
                                    { "reboot(&r)", "systemctl reboot" },
                                  }
                        })

-- mylauncher = awful.widget.launcher({ image = beautiful.awesome_icon,
                                     -- menu = mymainmenu })

-- Menubar configuration
menubar.utils.terminal = terminal -- Set the terminal for applications that require it
-- }}}

-- {{{ Wibox
-- Clock--{{{
mytextclock = awful.widget.textclock("<span color='yellow'>%m-%d</span> <span color='red'>%H:%M:%S</span> %a ", 1)
--}}}
-- Network speed indicator--{{{
function update_netstat()
    local interval = netwidget_clock.timeout
    local netif, text
    local f = io.open('/proc/net/route')
    for line in f:lines() do
        netif = line:match('^(%w+)%s+00000000%s')
        if netif then
            break
        end
    end
    f:close()

    if netif then
        local down, up
        f = io.open('/proc/net/dev')
        for line in f:lines() do
            -- Match wmaster0 as well as rt0 (multiple leading spaces)
            local name, recv, send = string.match(line, "^%s*(%w+):%s+(%d+)%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+(%d+)")
            if name == netif then
                if netdata[name] == nil then
                    -- Default values on the first run
                    netdata[name] = {}
                    down, up = 0, 0
                else
                    down = (recv - netdata[name][1]) / interval
                    up   = (send - netdata[name][2]) / interval
                end
                netdata[name][1] = recv
                netdata[name][2] = send
                break
            end
        end
        f:close()
        down = string.format('%.1f', down / 1024)
        up = string.format('%.1f', up / 1024)
        text = '↓<span color="#5798d9">'.. down ..'</span> ↑<span color="#c2ba62">'.. up ..'</span>'
    else
        netdata = {} -- clear as the interface may have been reset
        text = ''
    end
    netwidget:set_markup(text)
end
netdata = {}
netwidget = fixwidthtextbox('(net)')
netwidget.width = 85
netwidget:set_align('right')
netwidget_clock = timer({ timeout = 2 })
netwidget_clock:connect_signal("timeout", update_netstat)
netwidget_clock:start()
update_netstat()
-- }}}
-- Memory usage indicator--{{{
function update_memwidget()
    local f = io.open('/proc/meminfo')
    local total = f:read('*l')
    local free = f:read('*l')
    local buffered = f:read('*l')
    local cached = f:read('*l')
    f:close()
    total = total:match('%d+')
    free = free:match('%d+')
    buffered = buffered:match('%d+')
    cached = cached:match('%d+')
    free = free + buffered + cached
    local percent = 100 - math.floor(free / total * 100 + 0.5)
    -- memwidget:set_markup('<span color="#00ff00">M</span> <span color="#90ee90">'.. percent ..'%</span>')
    memwidget:set_markup(' <span color="#90ee90">'.. percent ..'%</span>')
end
memwidget = fixwidthtextbox('Mem ??')
memwidget:set_align('right')
memwidget.width = 24
update_memwidget()
mem_clock = timer({ timeout = 2 })
mem_clock:connect_signal("timeout", update_memwidget)
mem_clock:start()
-- }}}
-- Brightness Controller--{{{
brightnessicon = wibox.widget.imagebox()
brightnessicon:set_image(confdir .. "/icons/brightness_16.png")
io.popen('sudo chmod 666 /sys/class/backlight/intel_backlight/brightness')
function brightnessctl (mode, widget)
    local f = io.popen("cat /sys/class/backlight/intel_backlight/brightness")
    local brightness = f:read("*all")
    -- printError(brightness)
    f:close()
    if not tonumber(brightness) then
        widget:set_markup("<span color='red'>ERR</span>")
        do return end
    end

    if mode == "update" then
        brightness = string.format("%d", brightness)
        widget:set_markup("◑" .. brightness)
    end

    if mode == "up" then
        brightness = brightness + 50
        local f = io.popen("sudo echo " .. brightness .. " >/sys/class/backlight/intel_backlight/brightness")
        local s = f:read("*all")
        -- printError(s)
        f:close()
        brightnessctl("update", widget)
    elseif mode == "down" then
        brightness = brightness - 50
        local f = io.popen("sudo echo " .. brightness .. " >/sys/class/backlight/intel_backlight/brightness")
        f:read("*all")
        f:close()
        brightnessctl("update", widget)
    end
end
brightness_clock = timer({ timeout = 10 })
brightness_clock:connect_signal("timeout", function () brightnessctl("update", brightnesswidget) end)
brightness_clock:start()

brightnesswidget = fixwidthtextbox('(brightness)')
brightnesswidget.width = 30
brightnesswidget:set_align('right')
brightnesswidget:buttons(awful.util.table.join(
    awful.button({ }, 4, function () brightnessctl("up", brightnesswidget) end),
    awful.button({ }, 5, function () brightnessctl("down", brightnesswidget) end)
    -- awful.button({ }, 3, function () awful.util.spawn("pavucontrol") end),
    -- awful.button({ }, 1, function () brightnessctl("mute", brightnesswidget) end)
))
brightnessctl("update", brightnesswidget)
--}}}
-- Volume Controller--{{{
function volumectl (mode, widget)
    if mode == "update" then
        local f = io.popen("pamixer --get-volume")
        local volume = f:read("*all")
        f:close()
        if not tonumber(volume) then
            widget:set_markup("<span color='red'>ERR</span>")
            do return end
        end
        volume = string.format("% 3d", volume)

        f = io.popen("pamixer --get-mute")
        local muted = f:read("*all")
        f:close()
        if muted == "false" then
            volume = '♫' .. volume
        else
            volume = '♫' .. volume .. "<span color='red'>M</span>"
        end
        widget:set_markup(volume)
    elseif mode == "up" then
        local f = io.popen("pamixer --allow-boost --increase 5")
        f:read("*all")
        f:close()
        volumectl("update", widget)
    elseif mode == "down" then
        local f = io.popen("pamixer --allow-boost --decrease 5")
        f:read("*all")
        f:close()
        volumectl("update", widget)
    else
        local f = io.popen("pamixer --toggle-mute")
        f:read("*all")
        f:close()
        volumectl("update", widget)
    end
end
volume_clock = timer({ timeout = 10 })
volume_clock:connect_signal("timeout", function () volumectl("update", volumewidget) end)
volume_clock:start()

volumewidget = fixwidthtextbox('(volume)')
volumewidget.width = 29
volumewidget:set_align('right')
volumewidget:buttons(awful.util.table.join(
    awful.button({ }, 4, function () volumectl("up", volumewidget) end),
    awful.button({ }, 5, function () volumectl("down", volumewidget) end),
    awful.button({ }, 3, function () awful.util.spawn("pavucontrol") end),
    awful.button({ }, 1, function () volumectl("mute", volumewidget) end)
))
volumectl("update", volumewidget)
--}}}
-- Battery indicator--{{{
last_bat_warning = 0
local battery_state = {
    unknown     = '<span color="yellow">?',
    fullycharged        = '<span color="#0000ff">↯',
    charging    = '<span color="green">+',
    discharging = '<span color="#1e90ff">–',
}
function update_batwidget()
    local cmd = 'upower -i /org/freedesktop/UPower/devices/battery_BAT0'

    -- local bat_dir = '/sys/devices/platform/smapi/BAT0/'
    local f = io.popen(cmd .. '|grep -E "state"|awk \'{print $2}\'|sed \'{s/-//}\' ')
    -- local s = f:read('*all')
    if not f then
        batwidget:set_markup('<span color="red">ERR</span>')
        return
    end

    local state = f:read('*l')
    -- printError(state)
    f:close()
    local state_text = battery_state[state] or battery_state.unknown

    f = io.popen(cmd .. '|grep -E "percentage:"|grep -oP "\\d+"')
    if not f then
        batwidget:set_markup('<span color="red">ERR</span>')
        return
    end
    -- printError(f:read('*l'))
    local percent = tonumber(f:read('*l'))
    f:close()
    if percent <= 35 then
        if state == 'discharging' then
            local t = os.time()
            if t - last_bat_warning > 60 * 5 then
                naughty.notify{
                    preset = naughty.config.presets.critical,
                    title = "电量警报",
                    text = '电池电量只剩下 ' .. percent .. '% 了！',
                    bg="#3b3b3b",
                    fg="#ff0000",
                    timeout = 5,
                }
                last_bat_warning = t
            end
        end
        percent = '<span color="red">' .. percent .. '</span>'
    end
    batwidget:set_markup(state_text .. percent .. '%</span>')
end
batwidget = fixwidthtextbox('↯??%')
batwidget.width = 35
batwidget:set_align("right")
update_batwidget()
bat_clock = timer({ timeout = 5 })
bat_clock:connect_signal("timeout", update_batwidget)
bat_clock:start()
-- }}}
-- -- mplayer Controller--{{{
-- --icons{{{
-- mplayericon = wibox.widget.imagebox()
-- -- mplayericon:set_image(confdir .. "/icons/play_16.png")
-- --}}}
-- mplayercontrol="/home/qian/.music.fifo"
-- mplayeroutput="/home/qian/.music.output"
-- mplayer_is_play = true
-- function mplayer_is_run()
    -- local f = io.popen("pgrep mplayer")
    -- local pid = f:read("*all")
    -- if tonumber(pid) then
        -- return true
    -- else
        -- return false
    -- end
-- end
-- function mplayerctl (mode, widget)
    -- if mode == "update" then
        -- if mplayer_is_run() and mplayer_is_play then
            -- -- printError(mplayer_is_run())
            -- io.popen("echo \"get_file_name\">" .. mplayercontrol)
            -- local f = io.popen("tail -n 10 " .. mplayeroutput .. "|grep -oP \'(?<=ANS_FILENAME=).*\'|tail -n 1|sed \"s/\'//g;s/\\..*//\"")
            -- local s = f:read('*alll')
            -- -- printError(s)
            -- mplayerwidget.width = 80
            -- mplayerwidget:set_markup(s)
            -- mplayericon:set_image(confdir .. "/icons/play_16.png")

            -- -- -- 控制文件大小
            -- -- local f = io.popen("stat -c %s " .. mplayeroutput)
            -- -- local new_size = f:read("*all")
            -- -- f.close()
            -- -- new_size = tonumber(new_size)
            -- -- if (new_size > 1024*1024) then
                -- -- io.popen("cat /dev/null >" .. mplayeroutput)
            -- -- end
        -- else
            -- if not mplayer_is_run() then
                -- -- printError(mplayer_is_run())
                -- mplayerwidget.width = 0
                -- mplayericon:set_image(nil)
            -- end
        -- end
    -- end

    -- if mode == "next" then
        -- io.popen("echo \"pt_step 1\">" .. mplayercontrol)
        -- mplayerctl("update", widget)
    -- elseif mode == "last" then
        -- io.popen("echo \"pt_step -1\">" .. mplayercontrol)
        -- mplayerctl("update", widget)
    -- elseif mode == "pause" then
        -- io.popen("echo \"pause\">" .. mplayercontrol)
        -- mplayer_is_play = not mplayer_is_play
        -- if mplayer_is_play then
            -- mplayericon:set_image(confdir .. "/icons/play_16.png")
        -- else
            -- mplayericon:set_image(confdir .. "/icons/pause_16.png")
        -- end
    -- end
-- end
-- mplayer_clock = timer({ timeout = 5 })
-- mplayer_clock:connect_signal("timeout", function () mplayerctl("update", mplayerwidget) end)
-- mplayer_clock:start()

-- mplayerwidget = fixwidthtextbox('')
-- mplayerwidget:set_align('right')
-- mplayerwidget:buttons(awful.util.table.join(
-- awful.button({ }, 1, function () mplayerctl("pause", mplayerwidget) end),
-- awful.button({ }, 4, function () mplayerctl("last", mplayerwidget) end),
-- awful.button({ }, 5, function () mplayerctl("next", mplayerwidget) end)
-- -- awful.button({ }, 3, function () awful.util.spawn("pavucontrol") end),
-- ))
-- mplayerctl("update", mplayerwidget)
-- --}}}
--{{{ Email
function update_email()
    mailWidget:set_markup(awful.util.pread("/bin/awesome-email.py"))
end
mailWidget = fixwidthtextbox('Email')
mailWidgetTimer = timer({ timeout = 300 })
mailWidgetTimer:connect_signal("timeout", update_email)
update_email()
mailWidgetTimer:start()
mailWidget:buttons(awful.util.table.join(
awful.button({ }, 1, function ()
    awful.util.spawn("thunderbird")
    awful.tag.viewidx(5)
    end)
)
)
--}}}
-- Create a wibox for each screen and add it--{{{
-- Default--{{{
mywibox = {}
mypromptbox = {}
mylayoutbox = {}
mytaglist = {}
mytaglist.buttons = awful.util.table.join(
awful.button({ }, 1, awful.tag.viewonly),
awful.button({ modkey }, 1, awful.client.movetotag),
awful.button({ }, 3, awful.tag.viewtoggle),
awful.button({ modkey }, 3, awful.client.toggletag),
awful.button({ }, 4, function(t) awful.tag.viewnext(awful.tag.getscreen(t)) end),
awful.button({ }, 5, function(t) awful.tag.viewprev(awful.tag.getscreen(t)) end)
)
mytasklist = {}
mytasklist.buttons = awful.util.table.join(
awful.button({ }, 1, function (c)
    if c == client.focus then
        c.minimized = true
    else
        -- Without this, the following
        -- :isvisible() makes no sense
        c.minimized = false
        if not c:isvisible() then
            awful.tag.viewonly(c:tags()[1])
        end
        -- This will also un-minimize
        -- the client, if needed
        client.focus = c
        c:raise()
    end
end),
awful.button({ }, 3, function ()
    if instance then
        instance:hide()
        instance = nil
    else
        instance = awful.menu.clients({ width=250 })
    end
end),
awful.button({ }, 4, function ()
    awful.client.focus.byidx(1)
    if client.focus then client.focus:raise() end
end),
awful.button({ }, 5, function ()
    awful.client.focus.byidx(-1)
    if client.focus then client.focus:raise() end
end))

for s = 1, screen.count() do
    -- Create a promptbox for each screen
    mypromptbox[s] = awful.widget.prompt()
    -- Create an imagebox widget which will contains an icon indicating which layout we're using.
    -- We need one layoutbox per screen.
    mylayoutbox[s] = awful.widget.layoutbox(s)
    mylayoutbox[s]:buttons(awful.util.table.join(
    awful.button({ }, 1, function () awful.layout.inc(layouts, 1) end),
    awful.button({ }, 3, function () awful.layout.inc(layouts, -1) end),
    awful.button({ }, 4, function () awful.layout.inc(layouts, 1) end),
    awful.button({ }, 5, function () awful.layout.inc(layouts, -1) end)))
    -- Create a taglist widget
    mytaglist[s] = awful.widget.taglist(s, awful.widget.taglist.filter.all, mytaglist.buttons)
    -- Create a tasklist widget
    mytasklist[s] = awful.widget.tasklist(s, awful.widget.tasklist.filter.currenttags, mytasklist.buttons)
    -- Create the wibox
    mywibox[s] = awful.wibox({ position = "top", screen = s })
    --}}}
    -- Widgets that are aligned to the left--{{{
    local left_layout = wibox.layout.fixed.horizontal()
    left_layout:add(mytaglist[s])
    left_layout:add(mypromptbox[s])
    --}}}
    -- Widgets that are aligned to the right--{{{
    local right_layout = wibox.layout.fixed.horizontal()
    if s == 1 then right_layout:add(wibox.widget.systray()) end
    right_layout:add(mailWidget)
    right_layout:add(netwidget)
    right_layout:add(memwidget)
    right_layout:add(volumewidget)
    -- right_layout:add(brightnessicon)
    right_layout:add(brightnesswidget)
    right_layout:add(batwidget)
    -- right_layout:add(mplayericon)
    -- right_layout:add(mplayerwidget)
    right_layout:add(mytextclock)
    right_layout:add(mylayoutbox[s])
    --}}}
    -- Now bring it all together (with the tasklist in the middle)--{{{
    local layout = wibox.layout.align.horizontal()
    layout:set_left(left_layout)
    layout:set_middle(mytasklist[s])
    layout:set_right(right_layout)

    mywibox[s]:set_widget(layout)
    --}}}
end
--}}}
--}}}

-- {{{ Mouse bindings
root.buttons(awful.util.table.join(
awful.button({ }, 3, function () mymainmenu:toggle() end),
awful.button({ }, 4, awful.tag.viewnext),
awful.button({ }, 5, awful.tag.viewprev)
))
-- }}}

-- {{{ Key bindings
-- globalkeys--{{{
globalkeys = awful.util.table.join(
-- Default--{{{
awful.key({ modkey,           }, "Left",   awful.tag.viewprev       ),
awful.key({ modkey,           }, "Right",  awful.tag.viewnext       ),
awful.key({ modkey,           }, "Escape", awful.tag.history.restore),
awful.key({ modkey,           }, "j", function ()
    awful.client.focus.byidx( 1)
    if client.focus then client.focus:raise() end
end),
awful.key({ modkey,           }, "k",
function ()
    awful.client.focus.byidx(-1)
    if client.focus then client.focus:raise() end
end),
awful.key({ modkey,           }, "w", function () mymainmenu:show() end),

-- Layout manipulation
awful.key({ modkey, "Shift"   }, "j", function () awful.client.swap.byidx(  1)    end),
awful.key({ modkey, "Shift"   }, "k", function () awful.client.swap.byidx( -1)    end),
awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_relative( 1) end),
awful.key({ modkey, "Control" }, "k", function () awful.screen.focus_relative(-1) end),
awful.key({ modkey,           }, "u", awful.client.urgent.jumpto),
awful.key({ modkey,           }, "Tab",
function ()
    awful.client.focus.history.previous()
    if client.focus then
        client.focus:raise()
    end
end),

-- Standard program
awful.key({ modkey,           }, "Return", function () awful.util.spawn(terminal) end),
awful.key({ modkey, "Control" }, "r", awesome.restart),
awful.key({ modkey, "Shift"   }, "q", awesome.quit),

awful.key({ modkey,           }, "l",     function () awful.tag.incmwfact( 0.05)    end),
awful.key({ modkey,           }, "h",     function () awful.tag.incmwfact(-0.05)    end),
awful.key({ modkey, "Shift"   }, "h",     function () awful.tag.incnmaster( 1)      end),
awful.key({ modkey, "Shift"   }, "l",     function () awful.tag.incnmaster(-1)      end),
awful.key({ modkey, "Control" }, "h",     function () awful.tag.incncol( 1)         end),
awful.key({ modkey, "Control" }, "l",     function () awful.tag.incncol(-1)         end),
awful.key({ modkey,           }, "space", function () awful.layout.inc(layouts,  1) end),
awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(layouts, -1) end),

awful.key({ modkey, "Control" }, "n", awful.client.restore),
-- awful.key({ altkey,           }, "r",
-- function()
-- if awful.client.minimized then
-- -- awful.client.restore
-- naughty.notify({ preset = naughty.config.presets.critical,
-- title = "if",
-- text = awesome.startup_errors })
-- else
-- naughty.notify({ preset = naughty.config.presets.critical,
-- title = "else" .. awful.client.minimized,
-- text = awesome.startup_errors })
-- end
-- end),

-- Prompt
awful.key({ modkey },            "r",     function () mypromptbox[mouse.screen]:run() end),

awful.key({ modkey }, "x",
function ()
    awful.prompt.run({ prompt = "Run Lua code: " },
    mypromptbox[mouse.screen].widget,
    awful.util.eval, nil,
    awful.util.getdir("cache") .. "/history_eval")
end),
-- Menubar
awful.key({ modkey }, "p", function() menubar.show() end),
--}}}
-- Custom key bindings{{{
awful.key({ modkey, }, "s", function () awful.util.spawn_with_shell("google-chrome-stable") end),
awful.key({ modkey, }, "e", function () awful.util.spawn("doublecmd") end),
-- awful.key({ modkey },            "r",     function () awful.util.spawn("launchy") end),
awful.key({ altkey },            "f",     function () awful.util.spawn("HappySearch") end),
awful.key({ altkey },            "r",     function () awful.util.spawn("HappyRun") end),
awful.key({ modkey },            "c",     function () awful.util.spawn("sudo poweroff") end)
--}}}
)
--}}}
-- clientkeys--{{{
-- Default--{{{
clientkeys = awful.util.table.join(
awful.key({ modkey,           }, "f",      function (c) c.fullscreen = not c.fullscreen  end),
awful.key({ altkey,           }, "F4",     function (c) c:kill()                         end),
awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ),
awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end),
awful.key({ modkey,           }, "o",      awful.client.movetoscreen                        ),
awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end),
awful.key({ altkey,           }, "z",
function (c)
    -- The client currently has the input focus, so it cannot be
    -- minimized, since minimized clients can't have the focus.
    c.minimized = true
end),
awful.key({ altkey,           }, "x",
function (c)
    c.maximized_horizontal = not c.maximized_horizontal
    c.maximized_vertical   = not c.maximized_vertical
end),
awful.key({ altkey,           }, "Tab",
    function ()
        -- awful.client.focus.history.previous()
        awful.client.focus.byidx(-1)
        if client.focus then
            client.focus:raise()
        end
    end),

awful.key({ altkey, "Shift"   }, "Tab",
    function ()
        -- awful.client.focus.history.previous()
        awful.client.focus.byidx(1)
        if client.focus then
            client.focus:raise()
        end
    end),
--}}}
-- Custome--{{{
-- 调整浮动窗口位置--{{{
awful.key({ modkey, "Shift" }, "Up",    function () awful.client.moveresize(  0, -20,   0,   0) end),
awful.key({ modkey, "Shift" }, "Down",  function () awful.client.moveresize(  0,  20,   0,   0) end),
awful.key({ modkey, "Shift" }, "Left",  function () awful.client.moveresize(-20,   0,   0,   0) end),
awful.key({ modkey, "Shift" }, "Right", function () awful.client.moveresize( 20,   0,   0,   0) end)

-- awful.key({ modkey, "Shift" }, "Next",  function () awful.client.moveresize(  0,   0, -40, -40) end),
-- awful.button({ }, 4,  function () awful.client.moveresize(  0,   0, -40, -40) end),
-- awful.button({ "Shift" }, 5, function () awful.client.moveresize(  0,   0,  40,  40) end)
-- awful.key({ modkey, "Shift" }, "Prior", function () awful.client.moveresize(  0,   0,  40,  40) end)
--}}}
--}}}
)
--}}}
-- Bind all key numbers to tags.--{{{
-- Be careful: we use keycodes to make it works on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, 9 do
    globalkeys = awful.util.table.join(globalkeys,
    awful.key({ modkey }, "#" .. i + 9,
    function ()
        local screen = mouse.screen
        local tag = awful.tag.gettags(screen)[i]
        if tag then
            awful.tag.viewonly(tag)
        end
    end),
    awful.key({ modkey, "Control" }, "#" .. i + 9,
    function ()
        local screen = mouse.screen
        local tag = awful.tag.gettags(screen)[i]
        if tag then
            awful.tag.viewtoggle(tag)
        end
    end),
    awful.key({ modkey, "Shift" }, "#" .. i + 9,
    function ()
        local tag = awful.tag.gettags(client.focus.screen)[i]
        if client.focus and tag then
            awful.client.movetotag(tag)
        end
    end),
    awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
    function ()
        local tag = awful.tag.gettags(client.focus.screen)[i]
        if client.focus and tag then
            awful.client.toggletag(tag)
        end
    end))
end--}}}

clientbuttons = awful.util.table.join(
awful.button({ }, 1, function (c) client.focus = c; c:raise() end),
awful.button({ modkey }, 1, awful.mouse.client.move),
awful.button({ modkey }, 3, awful.mouse.client.resize))

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
awful.rules.rules = {
    -- All clients will match this rule.
    { rule = { },
    properties = { border_width = beautiful.border_width,
    border_color = beautiful.border_normal,
    focus = awful.client.focus.filter,
    keys = clientkeys,
    buttons = clientbuttons } },
    -- { rule = { class = "MPlayer" }, properties = { floating = true } },
    { rule = { class = "pinentry" }, properties = { floating = true } },
    { rule = { class = "gimp" }, properties = { floating = true } },
    -- { rule = { class = "Chromium" },  properties = { floating = false, tag = tags[1][1] }},
    { rule = { class = "VirtualBox" },  properties = { floating = false, tag = tags[1][9] }},
    -- { rule = { class = "Gvim" },  properties = {floating = false, tag = tags[1][2]}}
    { rule = { name = "Question.text"},  properties = {floating = false, tag = tags[1][8]}},
    { rule = { class = "Pidgin"},
      properties = {floating = true, tag = tags[1][8]},
      callback = function(c) c:geometry({x=0, y=15, width=300, height=748}) end
    },
    { rule = { class = "Pidgin", role = "conversation"},
      properties = {floating = true, tag = tags[1][8]},
      callback = function(c) c:geometry({x=300, y=15, width=1066, height=748}) end
    },
    { rule = { class = "XMind"},  properties = {floating = false, tag = tags[1][7]}},
    { rule = { class = "Thunderbird"},  properties = {floating = false, tag = tags[1][6]}},
    { rule = { class = "Doublecmd" },  properties = { floating = false }},
    { rule = { class = "Gnome-terminal" },  properties = { floating = true }},
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c, startup)
    -- Enable sloppy focus
    c:connect_signal("mouse::enter", function(c)
        if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier
            and awful.client.focus.filter(c) then
            client.focus = c
        end
    end)

    if not startup then
        -- Set the windows at the slave,
        -- i.e. put it at the end of others instead of setting it master.
        -- awful.client.setslave(c)

        -- Put windows in a smart way, only if they does not set an initial position.
        if not c.size_hints.user_position and not c.size_hints.program_position then
            awful.placement.no_overlap(c)
            awful.placement.no_offscreen(c)
        end
    end

    local titlebars_enabled = false
    if titlebars_enabled and (c.type == "normal" or c.type == "dialog") then
        -- buttons for the titlebar
        local buttons = awful.util.table.join(
        awful.button({ }, 1, function()
            client.focus = c
            c:raise()
            awful.mouse.client.move(c)
        end),
        awful.button({ }, 3, function()
            client.focus = c
            c:raise()
            awful.mouse.client.resize(c)
        end)
        )

        -- Widgets that are aligned to the left
        local left_layout = wibox.layout.fixed.horizontal()
        left_layout:add(awful.titlebar.widget.iconwidget(c))
        left_layout:buttons(buttons)

        -- Widgets that are aligned to the right
        local right_layout = wibox.layout.fixed.horizontal()
        right_layout:add(awful.titlebar.widget.floatingbutton(c))
        right_layout:add(awful.titlebar.widget.maximizedbutton(c))
        right_layout:add(awful.titlebar.widget.stickybutton(c))
        right_layout:add(awful.titlebar.widget.ontopbutton(c))
        right_layout:add(awful.titlebar.widget.closebutton(c))

        -- The title goes in the middle
        local middle_layout = wibox.layout.flex.horizontal()
        local title = awful.titlebar.widget.titlewidget(c)
        title:set_align("center")
        middle_layout:add(title)
        middle_layout:buttons(buttons)

        -- Now bring it all together
        local layout = wibox.layout.align.horizontal()
        layout:set_left(left_layout)
        layout:set_right(right_layout)
        layout:set_middle(middle_layout)

        awful.titlebar(c):set_widget(layout)
    end
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
-- }}}

-- Autostart{{{
--}}}
