local teleportQueue = {}
local teleportQueueEntryCount = 0
local updateRateBoost = false
local updateRate = {60, 10}
local hasChanged = true
local openedGUIPlayers = {}
local updateGUIEveryTick = false

-- local recallJobs = {}

-- script.on_event({defines.on_event.on_tick}, function(event)

-- end)

function getAverage(items)
    local count = 0
    local sum = 0
    for k, v in pairs(items) do
        count = count + 1
        sum = sum + v
    end

    return sum / count
end

function setGUISize(element, w, h)
    if (not element.style) then return end
    if (w) then element.style.width = w end
    if (h) then element.style.height = h end
end

function getAllIdleRobotsInNetwork(logistic_network)
    local robots = {}
    if (logistic_network == nil) then return robots end
    for k, cell in pairs(logistic_network.cells) do
        local inv = cell.owner.get_inventory(defines.inventory.roboport_robot)
        for i = 1, #inv do
            local itemstack = inv[i]
            if (itemstack.valid_for_read) then
                if robots[itemstack.name] then
                    robots[itemstack.name].count =
                        robots[itemstack.name].count + itemstack.count
                else
                    robots[itemstack.name] =
                        {
                            count = itemstack.count,
                            item = itemstack.prototype,
                            ent = itemstack.prototype.place_result
                        }
                end
            end
        end
    end

    return robots

end

function getDistanceBetweenVectors(a, b)
    local x = a.x - b.x
    local y = a.y - b.y

    return math.abs(math.sqrt((x * x) + (y * y)))
end

function addToTeleportQueue(source, destination, itemstack)

    local currentTick = game.tick
    local destinationInv = destination.get_inventory(defines.inventory.chest)
    local dist =
        getDistanceBetweenVectors(source.position, destination.position)

    local robotEnt = itemstack.prototype.place_result
    local unitsPerTick = source["force"]["worker_robots_speed_modifier"] *
                             robotEnt.speed
    local can_insert = destinationInv.can_insert(itemstack)

    -- game.print("" .. itemstack.count .. " " .. itemstack.name ..
    --                "to teleport queue")

    if (not can_insert) then return end
    -- game.print("Can't recall, no space!") 

    local queueEntry = {
        source = source,
        destination = destination,
        startTick = currentTick,
        endTick = math.abs(currentTick + (dist / unitsPerTick)),
        itemstack = itemstack
    }
    table.insert(teleportQueue, queueEntry)
    teleportQueueEntryCount = teleportQueueEntryCount + 1
    -- local timeTo

end

function buildRecallGui(baseGUI, entity)
    if (not entity) then return end
    if (entity.name ~= 'robot-recall-chest') then return end
    local logistic_network = entity.logistic_network
    if (baseGUI['robot-recall-chest'] ~= nil) then
        baseGUI['robot-recall-chest'].destroy()
    end
    local recallFrame = baseGUI.add({
        type = "frame",
        name = "robot-recall-chest",
        direction = "vertical"
    })
    recallFrame.caption = "Recall Robots"
    -- ply.opened = recallFrame
    -- this is for vanilla at 1x scale
    local INV_DIMENSIONS = {width = 874, height = 436, verticalOffset = -88}
    local WIDTH = 300
    local HEIGHT = INV_DIMENSIONS.height
    local recallScrollFlowFrame = recallFrame.add(
                                      {
            type = "frame",
            name = "frame",
            style = "image_frame",
            direction = "vertical"
        })
    local recallScrollFlow = recallScrollFlowFrame.add {
        type = "scroll-pane",
        name = "scrollpane"
    }

    setGUISize(recallFrame, WIDTH, HEIGHT)
    setGUISize(recallScrollFlow, WIDTH - 20, HEIGHT - 50)
    -- game.print(ply.gui)
    local ply = game.players[baseGUI.player_index]
    local res = ply.display_resolution
    local scl = ply.display_scale
    openedGUIPlayers[baseGUI.player_index] =
        {ply = game.players[baseGUI.player_index], ent = entity}
    recallFrame.location = {
        (res.width / 2) - (INV_DIMENSIONS.width * scl * 0.5) - WIDTH * scl,
        (res.height / 2) - (INV_DIMENSIONS.height / 2 * scl) +
            (INV_DIMENSIONS.verticalOffset * scl)
    }

    local robots = getAllIdleRobotsInNetwork(logistic_network)
    updateRecallGuiList(baseGUI, robots, logistic_network)
end

function updateRecallGuiList(baseGui, robots, logistic_network)
    local scrollPane = baseGui['robot-recall-chest']['frame']['scrollpane']
    local ply = game.players[baseGui.player_index]
    if (logistic_network == nil or not logistic_network.valid) then
        local label = scrollPane['no-network'] or scrollPane.add(
                          {
                type = "label",
                caption = "This is not apart of a logistics network! :(",
                name = "no-network"
            })
        label.style.horizontal_align = "center"
        label.style.width = scrollPane.style.maximal_width - 10
        return
    end
    if (scrollPane['no-network'] and scrollPane['no-network'].valid) then
        scrollPane['no-network'].destroy()
    end
    local count = 0
    for k, v in pairs(robots) do

        count = count + 1
        local flow = baseGui['robot-recall-chest']['frame']['scrollpane'][k] or
                         scrollPane.add({type = "flow", name = k})
        local spritebutton = flow['spritebutton'] or flow.add(
                                 {
                type = "sprite-button",
                tooltip = {"", "Recall ", v.item.localised_name},
                name = "spritebutton"
            })

        if (spritebutton.sprite == "") then
            spritebutton.sprite = "item/" .. v.item.name
        end

        local progressbar =
            baseGui['robot-recall-chest']['frame']['scrollpane'][k ..
                '-progressbar'] or scrollPane.add(
                {
                    type = "progressbar",
                    name = k .. '-progressbar',
                    visible = false,
                    value = 0
                })

        if (ply.opened and ply.opened.name == "robot-recall-chest") then
            if (ply.opened.get_inventory(defines.inventory.chest).can_insert(
                {name = k})) then
                spritebutton.enabled = true
            else
                spritebutton.enabled = false
            end
        end

        local label = flow['label'] or
                          flow.add({type = "label", name = "label"})
        label.caption = {"", v.item.localised_name, "\nCount: " .. v.count}
        label.style.single_line = false

    end

    if (count * 2 ~= table_size(scrollPane)) then
        for k, v in pairs(baseGui['robot-recall-chest']['frame']['scrollpane']
                              .children) do
            if (v.valid and v.type == "flow" and not robots[v.name]) then
                local progress =
                    baseGui['robot-recall-chest']['frame']['scrollpane'][v.name ..
                        '-progressbar']
                v.destroy()
                progress.destroy()
                -- baseGui['robot-recall-chest']['frame']['scrollpane'][k..'-progressbar'].destroy()
            end
        end
    end

    if (count == 0 and not scrollPane['no-robots-label']) then
        local label = scrollPane.add({
            type = "label",
            caption = "There are no robots in this network's roboports! :(",
            name = "no-robots-label"
        })
        -- baseGUI.style.height
        label.style.single_line = false
        label.style.horizontal_align = 'center'
        label.style.width = scrollPane.style.maximal_width - 10
        return
    elseif (count > 0 and scrollPane['no-robots-label'] and
        scrollPane['no-robots-label'].valid) then
        scrollPane['no-robots-label'].destroy()
    end
end

function updateRecallGuiListProgress(baseGui, robots, logistic_network)
    if (not baseGui or not baseGui['robot-recall-chest']) then return end

    local scrollPane = baseGui['robot-recall-chest']['frame']['scrollpane']
    local ply = game.players[baseGui.player_index]
    for _, element in pairs(scrollPane.children) do
        if (element.type == "progressbar") then
            local progressbar = element
            local itemname = string.sub(element.name, 0,
                                        - 1 - string.len("-progressbar"))
            local totalProgress = {}
            for k, v in pairs(teleportQueue) do
                -- if (teleportQueue.destination) then
                -- end
                
                if (v.destination.unit_number == ply.opened.unit_number 
                    and v.itemstack.prototype.name == itemname) then
                    local currentTick = game.tick - v.startTick
                    local finishTick = v.endTick - v.startTick
                    -- game.print("TELEPORT QUEUE LOl")
                    table.insert(totalProgress, currentTick / finishTick)
                end
            end
            if (table_size(totalProgress) ~= 0) then
                progressbar.visible = true
                local newprog = getAverage(totalProgress)
                progressbar.value = math.max(newprog, progressbar.value)
            else
                progressbar.visible = false
                progressbar.value = 0
                -- local robots = getAllIdleRobotsInNetwork(ply.opened.ent)
                -- updateRecallGuiList(v.ply.gui.screen, robots, v.ent.logistic_network)
            end

        end
    end

end

function createRobotRecallGUI(ent, ply, gui)
    -- if (not (ent and ent.name == "robot-recall-chest")) then return end
    if (gui['robot-recall-chest'] ~= nil) then
        gui['robot-recall-chest'].destroy()
    end
    local recallFrame = gui.add({
        type = "frame",
        name = "robot-recall-chest",
        direction = "vertical"
    })
    recallFrame.caption = "Recall Robots"
    -- ply.opened = recallFrame
    -- this is for vanilla at 1x scale
    local INV_DIMENSIONS = {width = 874, height = 436, verticalOffset = -88}
    local WIDTH = 300
    local HEIGHT = INV_DIMENSIONS.height
    local recallScrollFlowFrame = recallFrame.add(
                                      {
            type = "frame",
            name = "frame",
            style = "image_frame",
            direction = "vertical"
        })
    local recallScrollFlow = recallScrollFlowFrame.add {
        type = "scroll-pane",
        name = "scrollpane"
    }

    setGUISize(recallFrame, WIDTH, HEIGHT)
    setGUISize(recallScrollFlow, WIDTH - 20, HEIGHT - 50)
    -- game.print(ply.gui)
    local res = ply.display_resolution
    local scl = ply.display_scale

    recallFrame.location = {
        (res.width / 2) - (INV_DIMENSIONS.width * scl * 0.5) - WIDTH * scl,
        (res.height / 2) - (INV_DIMENSIONS.height / 2 * scl) +
            (INV_DIMENSIONS.verticalOffset * scl)
    }

    -- if (ent and ent.logistic_network) then
    --     -- game.print(ent.logistic_network.robots)
    --     -- recallFrame.direction = "vertical"
    --     -- drawRobotRecallGui(recallScrollFlow, ent.logistic_network)
    -- end
end

function callRobotsToEntity(location_ent, logisticNetwork, robotItem)

    for k, cell in pairs(logisticNetwork.cells) do
        local roboport = cell.owner
        local inv = roboport.get_inventory(defines.inventory.roboport_robot)
        for i = 1, #inv do
            local itemstack = inv[i]
            if (itemstack.valid_for_read) then
                if (itemstack.prototype == robotItem) then
                    addToTeleportQueue(roboport, location_ent, itemstack)
                end
            end
        end
    end

end

-- function updateLogisticNetwork

function updateTeleportJobs(event)
    for k, e in ipairs(teleportQueue) do
        -- if (not itemstack.valid)
        if (not e.destination   or  not e.destination.valid)    then return end
        if (not e.source        or  not e.source.valid)         then return end
        if (event.tick >= e.endTick) then

            -- if () then return end
            local destinationInv = e.destination.get_inventory(
                                       defines.inventory.roboport_robot) or
                                       e.destination.get_inventory(
                                           defines.inventory.chest)
            local sourceInv = e.source.get_inventory(
                                  defines.inventory.roboport_robot) or
                                  e.source
                                      .get_inventory(defines.inventory.chest)
            if (e.itemstack.valid_for_read and
                e.destination.get_inventory(1).can_insert(e.itemstack)) then
                local amnt = e.destination.insert(e.itemstack)
                if (amnt == e.itemstack.count) then
                    e.itemstack.clear()
                else
                    e.itemstack.count = e.itemstack.count - amnt
                end
            end

            -- for _, v in pairs(openedGUIPlayers) do
            --     -- getAllIdleRobotsInNetwork(p.ply.opened)
            --     -- local robots = getAllIdleRobotsInNetwork(v.ent.logistic_network)
            --     -- updateRecallGuiList(v.ply.gui.screen, robots, v.ent.logistic_network)
            -- end
            table.remove(teleportQueue, k)
            teleportQueueEntryCount = teleportQueueEntryCount - 1
        end
    end
end

function initRecallChest(event) end

script.on_event({defines.events.on_built_entity}, function(event)
    -- game.print("Hello!")
    if (event.created_entity and event.created_entity.name ==
        "robot-recall-chest") then initRecallChest(event) end
end)

script.on_event({defines.events.on_robot_built_entity}, function(event)
    if (event.created_entity and event.created_entity.name ==
        "robot-recall-chest") then initRecallChest(event) end
end)

script.on_event({defines.events.on_gui_opened}, function(event)
    local ent = event.entity
    local ply = game.players[event.player_index]
    local gui = ply.gui.screen
    buildRecallGui(gui, ent)
    -- recallFrame.add({})

    -- local closeButton = recallFrame.add({type="button",name="robot-recall-chest.close", caption="Close!"})

end)

script.on_event({defines.events.on_gui_closed}, function(event)
    local ent = event.entity
    local ply = game.players[event.player_index]
    local gui = ply.gui.screen
    if (gui['robot-recall-chest'] ~= nil) then
        if (openedGUIPlayers[event.player_index]) then
            table.remove(openedGUIPlayers, event.player_index)
        end
        gui['robot-recall-chest'].destroy()
    end
    -- game.print('on_gui_close')
end)

script.on_event({defines.events.on_gui_click}, function(event)
    -- game.print(event)
    local ply = game.players[event.player_index]
    -- local items = game.item_prototypes

    if (event.element.type == "sprite-button" and ply.opened and ply.opened.name ==
        "robot-recall-chest") then
        local itemname = event.element.parent.name
        local item = game.item_prototypes[itemname]
        -- game.print('recalling "' .. itemname .. '"')
        callRobotsToEntity(ply.opened, ply.opened.logistic_network, item,
                           event.tick)

    end

    if (event.element.name == "robot-recall-chest.close") then
        event.element.parent.destroy()
    end
end)

-- script.on_nth_tick(10, function(event)
-- if (event.tick % 5 == 0) then
--     for k, v in pairs(game.players) do
--         -- local  = v.gui.screen
--         local gui = v.gui.screen
--         updateRecallGui(event, gui, v)
--     end
-- end
-- end)
-- script.on_event({defines.events.on_tick}, function(event)
--     if (teleportQueueEntryCount > 0) then
--         for k, v in pairs(openedGUIPlayers) do
--             -- local  = v.gui.screen
--             local gui = v.ply.gui.screen
--             -- __DebugAdapter.print("Updating every tick!")
--             if (v.ent.logistic_network and v.ent.logistic_network.valid) then
--                 local robots = getAllIdleRobotsInNetwork(v.ent.logistic_network)
--                 updateRecallGuiList(v.ply.gui.screen, robots,
--                                     v.ent.logistic_network)
--             end
--         end
--     end
-- end)

script.on_nth_tick(2, function(event)
    if (teleportQueueEntryCount == 0 and hasChanged) then 
        hasChanged = false
        for k, v in pairs(openedGUIPlayers) do
            updateRecallGuiListProgress(v.ply.gui.screen)
        end
    elseif (teleportQueueEntryCount > 0) then
        hasChanged = true
        for k, v in pairs(openedGUIPlayers) do
            updateRecallGuiListProgress(v.ply.gui.screen)
        end
    end

end)

script.on_nth_tick(10, function(event)
    if (teleportQueueEntryCount > 0) then updateTeleportJobs(event) end
end)

script.on_nth_tick(180, function(event)
    for k, v in pairs(openedGUIPlayers) do
        -- __DebugAdapter.print("Updating every 10 ticks!")

        -- local  = v.gui.screen
        local gui = v.ply.gui.screen
        if (v.ent.logistic_network and v.ent.logistic_network.valid) then
            local robots = getAllIdleRobotsInNetwork(v.ent.logistic_network)
            updateRecallGuiList(v.ply.gui.screen, robots, v.ent.logistic_network)
        end
    end
    -- end
end)
