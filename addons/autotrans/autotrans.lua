addon.name      = 'AutoTrans';
addon.author    = 'Thorny';
addon.version   = '1.0.0.0';
addon.desc      = 'Replaces [[]] with translation tags in typed commands.';
addon.link      = 'https://ashitaxi.com/';

require('common');
local chat = require('chat');

local autoTranslateMapping;

local function LoadMapping()
    local configFile = string.format('%sconfig/addons/%s/mapping.lua', AshitaCore:GetInstallPath(), addon.name);
    if ashita.fs.exists(configFile) then
        local success, loadError = loadfile(configFile);
        if success then
            local result, output = pcall(success);
            if result then
                autoTranslateMapping = output;
                print(chat.header('AutoTrans') .. chat.message('Loaded mapping from ') .. chat.color1(2, configFile) .. chat.message('.'));
            end
        end
    end

    if autoTranslateMapping == nil then
        configFile = string.format('%saddons/%s/mapping.lua', AshitaCore:GetInstallPath(), addon.name);
        if ashita.fs.exists(configFile) then
            local success, loadError = loadfile(configFile);
            if success then
                local result, output = pcall(success);
                if result then
                    autoTranslateMapping = output;
                    print(chat.header('AutoTrans') .. chat.message('Loaded mapping from ') .. chat.color1(2, configFile) .. chat.message('.'));
                end
            end
        end
    end

    if autoTranslateMapping == nil then
        print(chat.header('AutoTrans') .. chat.error('Failed to load mapping.'));
    end
end

ashita.events.register('load', 'load_cb', function (e)
    LoadMapping();
end);

ashita.events.register('command', 'command_cb', function (e)
    local args = e.command:args();
    if #args > 0 and (args[1] == '/at') then
        if (#args > 1) and (args[2] == 'generate') then            
            local parser = require('parser');
            local result, output = pcall(parser.Parse);
            if result then
                print(chat.header('AutoTrans') .. chat.message('Generated a new mapping at: ') .. chat.color1(2, output) .. chat.message('.'));
                LoadMapping();
            else
                print(chat.header('AutoTrans') .. chat.error('Mapping generation failed. Error: ' .. output));
            end
        end
    end
end);

ashita.events.register('text_out', 'text_out_cb', function (e)
    e.message_modified = string.gsub(e.message_modified, "%[%[.-%]%]", function(input)
        local sub = string.sub(input, 3, -3);
        local lookup = autoTranslateMapping[sub];
        if lookup then
            return lookup;
        else
            return input;
        end
    end);
end);