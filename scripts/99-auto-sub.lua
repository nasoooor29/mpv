local mp = require 'mp'
local utils = require 'mp.utils'

-- remove [tags] and extra junk
local function normalize(name)
    -- remove extension
    name = name:gsub("%.%w+$", "")

    -- remove things like [1080p], [E269D73D], etc.
    name = name:gsub("%b[]", "")

    -- trim spaces
    name = name:gsub("^%s+", ""):gsub("%s+$", "")

    return name
end

-- extract episode number
local function get_episode(name)
    return name:match("%s%-%s(%d+)")
end

local function detect_sub_lang(name)
    local lower = name:lower()

    if lower:match("arabic") or lower:match("%f[%a]ara%f[^%a]") or lower:match("%f[%a]ar%f[^%a]") then
        return "ara"
    end

    if lower:match("english") or lower:match("%f[%a]eng%f[^%a]") or lower:match("%f[%a]en%f[^%a]") then
        return "eng"
    end

    return nil
end

mp.register_event("file-loaded", function()
    local path = mp.get_property("path")
    if not path then return end

    local dir, filename = utils.split_path(path)
    local ep = get_episode(filename)

    if not ep then return end

    local files = utils.readdir(dir, "files")
    if not files then return end

    for _, file in ipairs(files) do
        if file:match("%.ass$") then
            local sub_ep = get_episode(file)

            if sub_ep == ep then
                local fullpath = dir .. file
                local lang = detect_sub_lang(file)
                if lang then
                    mp.commandv("sub-add", fullpath, "select", file, lang)
                else
                    mp.commandv("sub-add", fullpath)
                end
                mp.commandv("script-message", "fullyy-sub-loaded")
                mp.msg.info("Loaded subtitle: " .. file)
                return
            end
        end
    end

    mp.msg.warn("No matching subtitle found")
end)
