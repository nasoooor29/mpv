local function pp()
    -- mp.osd_message("Alt+Q pressed!") -- shows on screen
    local path = mp.get_property("path")
    if not path then
        mp.osd_message("No file loaded!")
        return
    end
    -- Calculate MD5 hash of the file path
    local md5 = require("md5")
    local hash = md5.sumhexa(path)
    mp.osd_message("MD5 hash: " .. hash) -- shows on screenshot_button
end

-- alt+q binding
mp.add_key_binding("Alt+q", "print-file-md5-hash", pp)
