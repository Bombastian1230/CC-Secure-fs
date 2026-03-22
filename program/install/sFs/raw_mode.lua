settings.set("sFs.raw_mode", true)
settings.save()

term.setTextColor(colors.orange)
local start_x, start_y = term.getCursorPos()
for i = 0, 4 do
    term.setCursorPos(1, start_y)
    term.clear()
    write("Rebooting into raw mode in " .. tostring(5 - i))
    os.sleep(1)
end

os.reboot()