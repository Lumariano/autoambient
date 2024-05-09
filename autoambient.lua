addon.name      = 'autoambient';
addon.author    = 'Lumaro';
addon.version   = '1.0';
addon.desc      = 'Save and apply ambient lighting settings automatically on a per-zone basis.'
addon.link      = '';

require('common');
local chat      = require('chat');
local settings  = require('settings');

local default_settings = T{
    default_ambient_color = 0xFFFFFFFF,
    zones = T{ },
};

local autoambient = T{
    settings = settings.load(default_settings),
};

local function on_zone_change()
    local k = autoambient.settings.zones:find_if(function (v)
        local zone_id = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0);
        local zone_name = AshitaCore:GetResourceManager():GetString('zones.names', zone_id);
        return v[1] == zone_name;
    end);

    if (k ~= nil) then
        local ambient_color = autoambient.settings.zones[k][2];
        AshitaCore:GetProperties():SetD3DAmbientColor(ambient_color);
        AshitaCore:GetProperties():SetD3DAmbientEnabled(true);
    else
        AshitaCore:GetProperties():SetD3DAmbientEnabled(false);
        AshitaCore:GetProperties():SetD3DAmbientColor(autoambient.settings.default_ambient_color);
    end
end

local function print_help(is_error)
    if (is_error) then
        print(chat.header(addon.name):append(chat.error('Invalid command syntax for command: ')):append(chat.success('/' .. addon.name)));
    else
        print(chat.header(addon.name):append(chat.message('Available commands:')));
    end

    local cmds = T{
        { '/autoambient <r> <g> <b>', 'Adds / Reconfigures the current zone.' },
        { '/autoambient help', 'Displays the addons help information.' },
        { '/autoambient remove', 'Removes the current zone.' },
        { '/autoambient default <r> <g> <b>', 'Sets the ambient color to be used in other zones.' },
        { '/autoambient list', 'Lists all configured zones.' }
    };

    cmds:ieach(function (v)
        print(chat.header(addon.name):append(chat.error('Usage: ')):append(chat.message(v[1]):append(' - ')):append(chat.color1(6, v[2])));
    end);
end

settings.register('settings', 'settings_update', function (s)
    if (s ~= nil) then
        autoambient.settings = s;
    end

    settings.save();
end);

ashita.events.register('load', 'load_cb', on_zone_change);

ashita.events.register('unload', 'unload_cb', function ()
    AshitaCore:GetProperties():SetD3DAmbientEnabled(false);
    AshitaCore:GetProperties():SetD3DAmbientColor(autoambient.settings.default_ambient_color);
    settings.save();
end)

ashita.events.register('command', 'command_cb', function (e)
    local args = e.command:args();

    if (#args == 0 or args[1] ~= '/autoambient') then
        return;
    end

    e.blocked = true;

    if (#args == 4) then
        local r = args[2]:num_or(255);
        local g = args[3]:num_or(255);
        local b = args[4]:num_or(255);
        local ambient_color = math.d3dcolor(255, r, g, b);

        local zone_id = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0);
        local zone_name = AshitaCore:GetResourceManager():GetString('zones.names', zone_id);

        local k = autoambient.settings.zones:find_if(function (v)
            return v[1] == zone_name;
        end);

        if (k ~= nil) then
            autoambient.settings.zones[k][2] = ambient_color;
            settings.save();

            AshitaCore:GetProperties():SetD3DAmbientColor(ambient_color);
            AshitaCore:GetProperties():SetD3DAmbientEnabled(true);

            print(chat.header(addon.name)
                :append(chat.message('Updated '))
                :append(chat.success('%s'))
                :append(chat.message(' ambient lighting color.')):fmt(zone_name));
            return;
        end

        AshitaCore:GetProperties():SetD3DAmbientColor(ambient_color);
        AshitaCore:GetProperties():SetD3DAmbientEnabled(true);
        autoambient.settings.zones:append({ zone_name, ambient_color });
        settings.save();

        print(chat.header(addon.name):append(chat.message('Added zone: ')):append(chat.success(zone_name)));
        return;
    end

    if (#args == 2 and args[2] == 'help') then
        print_help(false);
        return;
    end

    if (#args == 2 and args[2] == 'remove') then
        local zone_id = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0);
        local zone_name = AshitaCore:GetResourceManager():GetString('zones.names', zone_id);

        local k = autoambient.settings.zones:find_if(function (v)
            return v[1] == zone_name;
        end);

        if (k == nil) then
            print(chat.header(addon.name):append(chat.error('This zone has not been configured.')));
            return;
        end

        AshitaCore:GetProperties():SetD3DAmbientEnabled(false);
        AshitaCore:GetProperties():SetD3DAmbientColor(autoambient.settings.default_ambient_color);

        autoambient.settings.zones:remove(k);
        settings.save();

        print(chat.header(addon.name):append(chat.message('Removed zone: ')):append(chat.success(zone_name)));
        return;
    end

    if(#args == 5 and args[2] == 'default') then
        local r = args[3]:num_or(255);
        local g = args[4]:num_or(255);
        local b = args[5]:num_or(255);
        local ambient_color = math.d3dcolor(255, r, g, b);

        autoambient.settings.default_ambient_color = ambient_color
        AshitaCore:GetProperties():SetD3DAmbientColor(ambient_color);

        print(chat.header(addon.name):append(chat.success('Updated default ambient lighting color.')));
        return;
    end

    if (#args == 2 and args[2] == 'list') then
        print(chat.header(addon.name):append('Configured zones:'));

        autoambient.settings.zones:ieach(function (v)
            print(chat.header(addon.name):append(chat.success(v[1])));
        end);
        return;
    end

    print_help(true);
end);

ashita.events.register('packet_in', 'packet_in_cb', function (e)
    if (e.id == 0x000A) then
        coroutine.sleep(1);
        on_zone_change();
    end
end);
