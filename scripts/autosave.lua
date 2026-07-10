local interval = 10

mp.add_periodic_timer(interval, function()
    mp.commandv("write-watch-later-config")
end)
