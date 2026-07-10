local mp = require("mp")
local utils = require("mp.utils")

-- Returns true when the path is absolute on Windows or Unix.
local function is_absolute_path(path)
    return path:match("^%a:[/\\]") ~= nil
        or path:match("^[/\\][/\\]") ~= nil
        or path:sub(1, 1) == "/"
end

local function get_absolute_video_path()
    local path = mp.get_property("path")

    if not path or path == "" then
        return nil
    end

    if is_absolute_path(path) then
        return path
    end

    local working_directory = mp.get_property("working-directory")

    if not working_directory or working_directory == "" then
        return path
    end

    return utils.join_path(working_directory, path)
end

local function get_extension(filename)
    return filename:match("%.([^%.]+)$")
end

local function remove_extension(filename)
    return filename:gsub("%.[^%.]+$", "")
end

local function starts_with_ignore_case(value, prefix)
    return value:sub(1, #prefix):lower() == prefix:lower()
end

local function find_matching_subtitle(video_path)
    local directory, video_filename = utils.split_path(video_path)
    local video_base = remove_extension(video_filename)

    local files = utils.readdir(directory, "files")

    if not files then
        return nil, "Could not read video directory: " .. directory
    end

    table.sort(files)

    for _, filename in ipairs(files) do
        local extension = get_extension(filename)

        if extension then
            extension = extension:lower()

            local is_subtitle =
                extension == "srt"
                or extension == "ass"
                or extension == "ssa"

            if is_subtitle and starts_with_ignore_case(filename, video_base) then
                return utils.join_path(directory, filename)
            end
        end
    end

    return nil, "No matching external subtitle found beside the video"
end

local function timestamp_to_ms(timestamp)
    local hours, minutes, seconds, fraction =
        timestamp:match("^(%d+):(%d+):(%d+)[,.](%d+)$")

    if not hours then
        return nil
    end

    -- Normalize centiseconds/microseconds/etc. to milliseconds.
    fraction = (fraction .. "000"):sub(1, 3)

    return (
        tonumber(hours) * 3600
        + tonumber(minutes) * 60
        + tonumber(seconds)
    ) * 1000 + tonumber(fraction)
end

local function first_subtitle_time(path)
    local file, open_error = io.open(path, "r")

    if not file then
        return nil, "Could not open subtitle: " .. tostring(open_error)
    end

    for line in file:lines() do
        -- SRT:
        -- 00:00:07,354 --> 00:00:10,000
        local srt_time =
            line:match("^%s*(%d+:%d+:%d+[,%.]%d+)%s*%-%->")

        if srt_time then
            file:close()
            return srt_time
        end

        -- ASS/SSA:
        -- Dialogue: 0,0:00:07.35,0:00:10.00,...
        local ass_time =
            line:match("^Dialogue:[^,]*,(%d+:%d+:%d+%.%d+),")

        if ass_time then
            file:close()
            return ass_time
        end
    end

    file:close()
    return nil, "No subtitle timing found in: " .. path
end

local function get_temp_directory()
    return os.getenv("TMPDIR")
        or os.getenv("TEMP")
        or os.getenv("TMP")
        or "/tmp"
end

local function make_temp_subtitle_path()
    math.randomseed(os.time() + math.floor(mp.get_time() * 100000))

    local filename = string.format(
        "mpv-subsync-%d-%d.srt",
        os.time(),
        math.random(100000, 999999)
    )

    return utils.join_path(get_temp_directory(), filename)
end

local function delete_file(path)
    if path then
        os.remove(path)
    end
end

local function sync_subtitles()
    local video_path = get_absolute_video_path()

    if not video_path then
        mp.osd_message("No video is playing", 3)
        return
    end

    local external_subtitle, subtitle_error =
        find_matching_subtitle(video_path)

    if not external_subtitle then
        mp.msg.error(subtitle_error)
        mp.osd_message(subtitle_error, 5)
        return
    end

    local temporary_subtitle = make_temp_subtitle_path()

    mp.osd_message("v2 Calculating subtitle delay...", 3)

    mp.msg.info("v2 Video: " .. video_path)
    mp.msg.info("v2 External subtitle: " .. external_subtitle)

    mp.command_native_async({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
        args = {
            "ffmpeg",
            "-y",
            "-loglevel", "error",
            "-i", video_path,
            "-map", "0:s:0",
            "-frames:s", "1",
            temporary_subtitle,
        },
    }, function(success, result, error_message)
        if not success then
            delete_file(temporary_subtitle)

            local message =
                "Could not run ffmpeg: " .. tostring(error_message)

            mp.msg.error(message)
            mp.osd_message(message, 6)
            return
        end

        if not result or result.status ~= 0 then
            delete_file(temporary_subtitle)

            local stderr = result and result.stderr or ""
            local message = "ffmpeg failed"

            if stderr ~= "" then
                message = message .. ":\n" .. stderr
            end

            mp.msg.error(message)
            mp.osd_message(message, 6)
            return
        end

        local embedded_time, embedded_error =
            first_subtitle_time(temporary_subtitle)

        delete_file(temporary_subtitle)

        if not embedded_time then
            mp.msg.error(embedded_error)
            mp.osd_message(embedded_error, 6)
            return
        end

        local external_time, external_error =
            first_subtitle_time(external_subtitle)

        if not external_time then
            mp.msg.error(external_error)
            mp.osd_message(external_error, 6)
            return
        end

        local embedded_ms = timestamp_to_ms(embedded_time)
        local external_ms = timestamp_to_ms(external_time)

        if not embedded_ms or not external_ms then
            mp.osd_message("Failed to parse subtitle timestamps", 6)
            return
        end

        local difference_ms = external_ms - embedded_ms
        local offset = -difference_ms / 1000
        -- make it to the 100th for example 3453 -> 3400 -> 3.4
        offset = math.floor(offset * 10) / 10

        mp.set_property_number("sub-delay", offset)

        mp.msg.info("Embedded first subtitle: " .. embedded_time)
        mp.msg.info("External first subtitle: " .. external_time)
        mp.msg.info("Difference: " .. difference_ms .. " ms")
        mp.msg.info(string.format("Subtitle delay: %.3f", offset))

        mp.osd_message(
            string.format("Subtitle delay set to %.3f seconds", offset),
            4
        )
    end)
end

mp.add_forced_key_binding(
    "Ctrl+e",
    "auto-subtitle-sync",
    sync_subtitles
)
