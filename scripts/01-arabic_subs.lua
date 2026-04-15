local function arabic_shit()
    -- Set subtitle style for Arabic subtitles
    mp.set_property("sub-font", "Amiri")                -- Set subtitle font to Amiri
    mp.set_property("sub-font-size", "64")              -- Set subtitle font size to 48
    mp.set_property("sub-color", "#fbff27ff")         -- Set subtitle color to purple
    mp.set_property("sub-border-size", "2")             -- Set subtitle border size to 2
    mp.set_property("sub-shadow-offset", "1")           -- Set subtitle shadow offset to 1
    mp.osd_message("Good job!!", 2) -- Show message for 2 seconds
end

local function english_shit()
    -- Set subtitle style for English subtitles
    mp.set_property("sub-font", "Helvetica Bold")       -- Set subtitle font to Helvetica Bold
    mp.set_property("sub-font-size", "36")              -- Set subtitle font size to 36
    mp.set_property("sub-color", "#ffffffff")           -- Set subtitle color to white
    mp.set_property("sub-border-size", "1")             -- Set subtitle border size to 1
    mp.set_property("sub-shadow-offset", "0")           -- Set subtitle shadow offset to 0
    mp.osd_message("English subtitles activated.", 2)   -- Show message for 2 seconds
end

-- Define a function to check subtitle track and apply style
local function set_sub_style()
    mp.set_property("sub-ass-override", "force")        -- so it work on ass subtitles and mkv etc
    local sid = mp.get_property_number("sid")           -- Get current subtitle track ID
    if not sid then return end                          -- If no subtitle track, exit function

    local tracks = mp.get_property_native("track-list") -- Get list of all tracks
    for _, t in ipairs(tracks) do                       -- Iterate over each track
        if t.id ~= sid or t.type ~= "sub" then          -- Skip if not the current subtitle track
            goto continue
        end

        -- if t.lang ~= "ar" and t.lang ~= "ara" then       -- Skip if subtitle language is not Arabic
        --     goto continue
        -- end
        if t.lang == "ar" or t.lang == "ara" then
            arabic_shit()
            goto continue
        end
        if t.lang == "en" or t.lang == "eng" then
            english_shit()
            goto continue
        end
        mp.osd_message("Unsupported " .. (t.lang or "unknown") .. " t.id: " .. t.id .. ", t.type: " .. t.type, 2)
        ::continue::

    end
end



mp.observe_property("sid", "number", set_sub_style)      -- when subtitle track changes try to set the theme
mp.register_event("file-loaded", set_sub_style)          -- when a new file is loaded try to set the theme
mp.register_script_message("fullyy-sub-loaded",set_sub_style)