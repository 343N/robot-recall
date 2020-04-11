-- require('util')
require('control.robot-recall')
require('control.robot-redistribute')

script.on_init(function(event)
    global.teleportQueue = {}
    global.teleportQueueEntryCount = 0
    global.hasChanged = false
    global.openedGUIPlayers = {}
    global.deploying = {}
end)

script.on_configuration_changed(function(event)
        if (event.mod_changes and event.mod_changes['robot-recall']) then
        local old_ver = event.mod_changes['robot-recall'].old_version
        if (old_ver) then
            if (old_ver == "0.2.0" or string.find(old_ver, "0.1.")) then
                global.teleportQueue = {}
                global.teleportQueueEntryCount = 0
            end

            if (old_ver == "0.2.0" or old_ver == "0.2.1") then
                global.deploying = {}
                for _, surface in pairs(game.surfaces) do
                    local deploymentstations =
                        surface.find_entities_filtered(
                            {name = "robot-redistribute-chest"})
                    for k, v in pairs(deploymentstations) do
                        global.deploying[v.unit_number] =
                            {ent = v, deploying = false}
                    end
                end
            end
        end

    end

    global.deploying = global.deploying or {}
    global.teleportQueue = global.teleportQueue or {}
    global.teleportQueueEntryCount = global.teleportQueueEntryCount or 0
    global.hasChanged = global.hasChanged or false
    global.openedGUIPlayers = global.openedGUIPlayers or {}
end)
