local dats = require('dats');
local language;

local resMgr = AshitaCore:GetResourceManager();
local handlers = {
    ['@C'] = function(input)
        if string.len(input) < 3 then
            return;
        end

        local value = tonumber(string.sub(input, 3), 16);
        local res = resMgr:GetSpellById(value);
        return res.Name[language+1];
    end,
    ['@Y'] = function(input)
        if string.len(input) < 3 then
            return;
        end

        local value = tonumber(string.sub(input, 3), 16);
        local res = resMgr:GetAbilityById(value);
        return res.Name[language+1];
    end,
    ['@A'] = function(input)
        if string.len(input) < 3 then
            return;
        end

        local value = tonumber(string.sub(input, 3), 16);
        return resMgr:GetString('zones.names', value, language);
    end,
    ['@J'] = function(input)
        if string.len(input) < 3 then
            return;
        end

        local value = tonumber(string.sub(input, 3), 16);
        return resMgr:GetString('jobs.names', value, language);
    end,
};

--[[
* Returns the raw bytes used to build an auto-translate tag for the given item id.
*
* @param {number} item_id - The item id.
* @return {table} The table of bytes to make the auto-translation tag for the given item id.

Credit to atom0s for this function!
--]]
local function generate_item_translate_data(item_id)
    local ret = T{ 0xFD, 0x00, 0x01, 0x00, 0x00, 0xFD };
    if (bit.band(item_id, 0xFF00) == 0) then
        ret[2] = 0x09;
        ret[4] = 0xFF;
        ret[5] = bit.band(item_id, 0x00FF);
    else
        ret[4] = bit.rshift(bit.band(item_id, 0xFF00), 0x08);

        if (bit.band(item_id, 0x00FF) > 0) then
            ret[2] = 0x07;
            ret[5] = bit.band(item_id, 0x00FF);
        end
    end
    return ret;
end

local function ParseEnglishDat(datId)
    language = 2;
    local filePath = dats.get_file_path(datId);
    local dat = io.open(filePath, 'rb');
    local data = dat:read('*all');
    dat:close();
    local results = T{};
    local offset = 1;
    for categoryIndex = 1,42 do
        local categoryResults = T{};
        local categoryId = struct.unpack('L', data, offset);
        local displayName = struct.unpack('c28', data, offset+4):trimend('\x00');
        local categoryName = struct.unpack('c28', data, offset+36);
        local entryCount = struct.unpack('L', data, offset+68);

        offset = offset + 76
        for index = 1,entryCount do
            local id = struct.unpack('L', data, offset);
            local length = struct.unpack('B', data, offset+4);
            if length > 0 then
                local name = struct.unpack(string.format('c%u', length), data, offset+5):trimend('\x00');
                if name then
                    if length > 2 then
                        local handler = handlers[string.sub(name, 1, 2)];
                        if type(handler) == 'function' then
                            name = handler(name);
                        end
                    end

                    if name and string.len(name) > 0 then
                        local autoTranslateCode = T{ 0xFD, 0x02, language, categoryIndex, index, 0xFD };
                        categoryResults[index] = T{
                            Category = categoryName,
                            TranslateCode = autoTranslateCode,
                            EnglishText = name:trimend('\x00'),
                            JapaneseText = '???',
                        };
                    end
                end
            end

            offset = offset+length+5;
        end
        results[categoryIndex] = categoryResults;
    end

    local itemResults = T{};
    for i = 1,65535 do
        local item = resMgr:GetItemById(i);
        if item ~= nil then
            itemResults[i] = T{
                Category = 'Items',
                TranslateCode = generate_item_translate_data(i),
                EnglishText = item.Name[3],
                JapaneseText = item.Name[2],
            };
        end
    end
    results['Items'] = itemResults;

    return results;
end

--WORK IN PROGRESS.. Does not function yet.
local function AddJapaneseDat(results, datId)
    language = 1;
    local filePath = dats.get_file_path(datId);
    local dat = io.open(filePath, 'rb');
    local data = dat:read('*all');
    dat:close();
    local offset = 1;
    for categoryIndex = 1,42 do
        local categoryResults = results[categoryIndex];        
        local categoryId = struct.unpack('L', data, offset);
        local displayName = struct.unpack('c28', data, offset+4):trimend('\x00');
        local categoryName = struct.unpack('c28', data, offset+36);
        local entryCount = struct.unpack('L', data, offset+68);

        offset = offset + 76
        for index = 1,entryCount do
            local id = struct.unpack('L', data, offset);
            local length = struct.unpack('B', data, offset+4);
            if length > 0 then
                local name = struct.unpack(string.format('c%u', length), data, offset+5):trimend('\x00');
                if name then
                    if length > 2 then
                        local handler = handlers[string.sub(name, 1, 2)];
                        if type(handler) == 'function' then
                            name = handler(name);
                        end
                    end

                    if name and string.len(name) > 0 then
                        local autoTranslateCode = T{ 0xFD, 0x02, language, categoryIndex, index, 0xFD };
                        local res = categoryResults[index];
                        if res then
                            res.JapaneseText = name:trimend('\x00');
                        else
                            categoryResults[index] = T{
                                Category = categoryName,
                                TranslateCode = autoTranslateCode:map(string.char):join(),
                                EnglishText = '???',
                                JapaneseText = name:trimend('\x00'),
                            };
                        end
                    end
                end
            end

            offset = offset+length+5;
        end
        results[categoryIndex] = categoryResults;
    end
end


local function ParseDats()
    local result = ParseEnglishDat(55665);
    --AddJapaneseDat(result, 55545);

    local dupeMap = T{};
    local sortedMap = T{};
    for _,categoryMap in pairs(result) do
        local ct = 0;
        for _,entry in pairs(categoryMap) do
            if dupeMap[entry.EnglishText] == nil then
                dupeMap[entry.EnglishText] = true;

                local value = '';
                for _,entry in ipairs(entry.TranslateCode) do
                    value = value .. '\\x' .. string.format("%02X", entry);
                end
                sortedMap:append({ Key=entry.EnglishText, Value=value });
            end
        end
    end

    table.sort(sortedMap, function(a,b) return a.Key < b.Key end);

    local configFolder = string.format('%sconfig/addons/%s/', AshitaCore:GetInstallPath(), addon.name);
    if not ashita.fs.exists(configFolder) then
        ashita.fs.create_directory(configFolder);
    end

    local configPath = string.format('%smapping.lua', configFolder);
    local output = io.open(configPath, 'w');
    output:write('return T{\n');
    for _,entry in ipairs(sortedMap) do
        output:write(string.format('    [%q] = "%s",\n', entry.Key, entry.Value));
    end
    output:write('}');
    output:close();
    
    return configPath;
end

return {
    Parse = ParseDats,
};