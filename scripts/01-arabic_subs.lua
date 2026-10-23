local mp = require("mp")

local function arabic_shit()
    mp.set_property("sub-font", "Amiri")
    mp.set_property_native("sub-font-size", 64)
    mp.set_property("sub-color", "#fbff27ff")
    mp.set_property_native("sub-border-size", 2)
    mp.set_property_native("sub-shadow-offset", 1)

    mp.osd_message("Arabic subtitles activated.", 2)
    mp.msg.info("Arabic subtitle style applied")
end

local function english_shit()
    mp.set_property("sub-font", "Helvetica Bold")
    mp.set_property_native("sub-font-size", 36)
    mp.set_property("sub-color", "#ffffffff")
    mp.set_property_native("sub-border-size", 1)
    mp.set_property_native("sub-shadow-offset", 0)

    mp.osd_message("English subtitles activated.", 2)
    mp.msg.info("English subtitle style applied")
end

local function set_sub_style()
    mp.msg.info("set_sub_style called")

    -- Strip subtitle-provided styling and force mpv styling
    mp.set_property("sub-ass-override", "strip")

    local sid = mp.get_property_number("sid")

    if not sid then
        mp.msg.info("No subtitle selected")
        return
    end

    local tracks = mp.get_property_native("track-list")

    if not tracks then
        mp.msg.warn("Could not get track-list")
        return
    end

    for _, t in ipairs(tracks) do
        if t.type == "sub" and t.id == sid then
            local lang = (t.lang or ""):lower()
            local title = (t.title or ""):lower()
            local filename = (t["external-filename"] or ""):lower()

            mp.msg.info(
                "Selected subtitle:"
                .. " id=" .. tostring(t.id)
                .. " lang=" .. tostring(lang)
                .. " title=" .. tostring(title)
                .. " file=" .. tostring(filename)
            )

            -- Arabic detection
            if
                lang == "ar"
                or lang == "ara"
                or lang == "ar-sa"
                or lang == "arabic"
                or title:match("arabic")
                or title:match("ara")
                or filename:match("%.ara%.")
                or filename:match("%.ar%.")
                or filename:match("arabic")
            then
                arabic_shit()
                return
            end

            -- English detection
            if
                lang == "en"
                or lang == "eng"
                or lang == "english"
                or title:match("english")
                or title:match("eng")
                or filename:match("%.eng%.")
                or filename:match("%.en%.")
                or filename:match("english")
            then
                english_shit()
                return
            end

            mp.osd_message(
                "Unknown subtitle language: "
                .. (lang ~= "" and lang or "none"),
                3
            )

            mp.msg.warn(
                "Could not detect subtitle language."
                .. " lang=" .. tostring(lang)
                .. " title=" .. tostring(title)
                .. " file=" .. tostring(filename)
            )

            return
        end
    end

    mp.msg.warn("Selected subtitle track not found in track-list")
end

-- Debug message so you KNOW the script actually loaded
mp.register_event("file-loaded", function()
    mp.osd_message("Subtitle style script loaded", 2)
    mp.msg.info("Subtitle style script loaded")

    -- Small delay because external subtitles may load slightly later
    mp.add_timeout(0.3, set_sub_style)
end)

-- When you switch subtitle tracks
mp.observe_property("sid", "number", function()
    mp.add_timeout(0.1, set_sub_style)
end)

-- When new tracks/subtitles are added
mp.register_event("tracks-changed", function()
    mp.add_timeout(0.1, set_sub_style)
end)

-- Your existing custom hook
mp.register_script_message("fullyy-sub-loaded", function()
    mp.add_timeout(0.1, set_sub_style)
end)
