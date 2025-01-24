addon.name    = "autoambient";
addon.author  = "Lumaro";
addon.version = "1.1";
addon.desc    = "Save and apply ambient lighting settings automatically on a per-zone basis.";
addon.link    = "https://github.com/Lumariano/autoambient";

require("common");
local chat     = require("chat");
local settings = require("settings");

local default_settings = T{
    default_red = 255,
    default_green = 255,
    default_blue = 255,
    default_d3dcolor = math.d3dcolor(255, 255, 255, 255),
    zones = { },
};

local autoambient = {
    settings = settings.load(default_settings),
};

local function ambient_on(color)
    AshitaCore:GetProperties():SetD3DAmbientColor(color);
    AshitaCore:GetProperties():SetD3DAmbientEnabled(true);
end

local function ambient_off()
    AshitaCore:GetProperties():SetD3DAmbientEnabled(false);
    AshitaCore:GetProperties():SetD3DAmbientColor(autoambient.settings.default_d3dcolor);
end

local function apply_ambient()
    local zone_id = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0);
    local zone = autoambient.settings.zones[zone_id];

    if (zone == nil) then
        ambient_off();
        return;
    end

    ambient_on(zone.d3dcolor);
end

local function print_help(is_error)
    if (is_error) then
        print(chat.header(addon.name):append(chat.error("Invalid command syntax for command: ")):append(chat.success("/" .. addon.name)));
    else
        print(chat.header(addon.name):append(chat.message("Available commands:")));
    end

    local cmds = T{
        { "/autoambient help",                "Displays the addons help information." },
        { "/autoambient zone <r> <g> <b>",    "Sets the current zone"s ambient color." },
        { "/autoambient zone",                "Lists the current zone"s ambient color, if configured." },
        { "/autoambient remove",              "Removes the current zone from configuration." },
        { "/autoambient list",                "Lists all configured zones." },
        { "/autoambient default",             "Lists the default ambient color." },
        { "/autoambient default <r> <g> <b>", "Sets the default ambient color." },
    };

    cmds:ieach(function (v)
        print(chat.header(addon.name):append(chat.error("Usage: ")):append(chat.message(v[1]):append(" - ")):append(chat.color1(6, v[2])));
    end);
end

settings.register("settings", "settings_update", function (s)
    if (s ~= nil) then
        autoambient.settings = s;
    end

    settings.save();
end);

ashita.events.register("load", "load_cb", function ()
    if (settings.logged_in == true) then
        apply_ambient();
    end
end);

ashita.events.register("unload", "unload_cb", function ()
    ambient_off();
end);

ashita.events.register("packet_in", "packet_in_cb", function (e)
    if (e.id ~= 0x000A) then
        return;
    end

    coroutine.sleep(1);
    apply_ambient();
end);

ashita.events.register("command", "command_cb", function (e)
    local args = e.command:args();

    if (#args == 0 or not args[1]:any("/autoambient", "/aa")) then
        return;
    end

    e.blocked = true;

    if (#args == 2 and args[2] == "help") then
        print_help(false);
        return;
    end

    if (#args == 5 and args[2] == "zone") then
        r = args[3]:tonumber();
        g = args[4]:tonumber();
        b = args[5]:tonumber();

        if (r == nil or g == nil or b == nil) then
            print(chat.header(addon.name):append(chat.message("Could not set zone's ambient color: "):append(chat.error("at least one argument was not a number!"))))
            return;
        end

        r = r:clamp(0, 255);
        g = g:clamp(0, 255);
        b = b:clamp(0, 255);

        local zone_id = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0);
        local zone_name = AshitaCore:GetResourceManager():GetString("zones.names", zone_id);

        autoambient.settings.zones[zone_id] = {
            name = zone_name,
            red = r,
            green = g,
            blue = b,
            d3dcolor = math.d3dcolor(255, r, g, b),
        };

        ambient_on(autoambient.settings.zones[zone_id].d3dcolor);
        settings.save();
        print(chat.header(addon.name):append(chat.message("Set " .. zone_name .. " ambient color to: "):append(chat.success("rgb(" .. r .. ", " .. g .. ", " .. b .. ")"))));
        return;
    end

    if (#args == 2 and args[2] == "zone") then
        local zone_id = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0);
        local zone = autoambient.settings.zones[zone_id];

        if (zone == nil) then
            print(chat.header(addon.name):append(chat.message("Could not list zone: "):append(chat.error("this zone has not been configured"))));
            return;
        end

        print(chat.header(addon.name):append(chat.message(zone.name .. " ambient color is set to: rgb(" .. zone.red .. ", " .. zone.green .. ", " .. zone.blue .. ")")));
        return;
    end

    if (#args == 2 and args[2] == "remove") then
        local zone_id = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0);
        local zone = autoambient.settings.zones[zone_id];

        if (zone == nil) then
            print(chat.header(addon.name):append(chat.message("Could not remove zone: "):append(chat.error("this zone has not been configured"))));
            return;
        end

        autoambient.settings.zones[zone_id] = nil;
        ambient_off();
        settings.save();
        print(chat.header(addon.name):append(chat.message("Removed zone: "):append(chat.success(zone.name))))
        return;
    end

    if (#args == 2 and args[2] == "list") then
        print(chat.header(addon.name):append(chat.message("Configured zones:")));
        
        for _, zone in pairs(autoambient.settings.zones) do
            print(chat.header(addon.name):append(chat.message(zone.name .. " : " .. "rgb(" .. zone.red .. ", " .. zone.green .. ", " .. zone.blue .. ")")));
        end

        return;
    end

    if (#args == 2 and args[2] == "default") then
        print(chat.header(addon.name):append(chat.message("The default ambient color is set to: rgb(" .. autoambient.settings.default_red .. ", " .. autoambient.settings.default_green .. ", " .. autoambient.settings.default_blue .. ")")));
        return;
    end

    if (#args == 5 and args[2] == "default") then
        r = args[3]:tonumber();
        g = args[4]:tonumber();
        b = args[5]:tonumber();

        if (r == nil or g == nil or b == nil) then
            print(chat.header(addon.name):append(chat.message("Could not set default ambient color: "):append(chat.error("at least one argument was not a number!"))))
            return;
        end

        r = r:clamp(0, 255);
        g = g:clamp(0, 255);
        b = b:clamp(0, 255);

        autoambient.settings.default_red = r;
        autoambient.settings.default_green = g;
        autoambient.settings.default_blue = b;
        autoambient.settings.default_d3dcolor = math.d3dcolor(255, r, g, b);
        AshitaCore:GetProperties():SetD3DAmbientColor(autoambient.settings.default_d3dcolor);
        settings.save();
        print(chat.header(addon.name):append(chat.message("Set default ambient color to: "):append(chat.success("rgb(" .. r .. ", " .. g .. ", " .. b .. ")"))));
        return;
    end

    print_help(true);
end);
