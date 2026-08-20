local mp = require("mp")

local powershell = [[C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe]]
local ps_script = mp.command_native({
    "expand-path",
    "~~/subtitle-sync.ps1"
})

local function sync_subtitles()
    local video_path = mp.get_property("path")

    if not video_path or video_path == "" then
        mp.osd_message("No video is playing", 3)
        return
    end

    mp.osd_message("Calculating subtitle delay...", 3)

    mp.command_native_async({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
        args = {
            powershell,
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            ps_script,
            "-Video",
            video_path,
        },
    }, function(success, result, error_message)
        if not success then
            mp.msg.error("Could not start PowerShell: " .. tostring(error_message))
            mp.osd_message("Could not start PowerShell", 5)
            return
        end

        if not result then
            mp.msg.error("PowerShell returned no result")
            mp.osd_message("PowerShell returned no result", 5)
            return
        end

        local stdout = result.stdout or ""
        local stderr = result.stderr or ""

        mp.msg.info("PowerShell exit status: " .. tostring(result.status))
        mp.msg.info("PowerShell stdout: " .. stdout)

        if stderr ~= "" then
            mp.msg.warn("PowerShell stderr: " .. stderr)
        end

        if result.status ~= 0 then
            mp.osd_message(
                "Subtitle sync failed:\n" ..
                (stderr ~= "" and stderr or stdout),
                6
            )
            return
        end

        -- Extracts values such as:
        -- -5.114
        -- 2.500
        -- 0
        local offset_text = stdout:match("[-+]?%d+%.?%d*")
        local offset = tonumber(offset_text)

        if not offset then
            mp.msg.error("Invalid output from subtitle-sync.ps1: " .. stdout)
            mp.osd_message("Invalid subtitle offset: " .. stdout, 6)
            return
        end

        mp.set_property_number("sub-delay", offset)

        mp.osd_message(
            string.format("Subtitle delay set to %.3f seconds", offset),
            4
        )

        mp.msg.info(
            string.format("Subtitle delay set to %.3f seconds", offset)
        )
    end)
end

mp.add_forced_key_binding(
    "Ctrl+s",
    "auto-subtitle-sync",
    sync_subtitles
)
