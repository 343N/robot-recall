local teleportQueue = {}
local robots = {}
-- local recallJobs = {}

-- script.on_event({defines.on_event.on_tick}, function(event)

-- end)

local function getAverage(items)
    local count = 0
    local sum = 0
    for k, v in pairs(items) do
        count = count + 1
        sum = sum + v
    end

    return sum / count
end

local function getDistanceBetweenVectors(a, b)
    local x = a.x - b.x
    local y = a.y - b.y

    return math.abs(math.sqrt((x * x) + (y * y)))
end

local function addToTeleportQueue(source, destination, itemstack, currentTick)

    local destinationInv = destination.get_inventory(defines.inventory.chest)
    local dist =
        getDistanceBetweenVectors(source.position, destination.position)

    local robotEnt = itemstack.prototype.place_result
    local unitsPerTick = source["force"]["worker_robots_speed_modifier"] *
                             robotEnt.speed
    local can_insert = destinationInv.can_insert(itemstack)

    -- game.print("" .. itemstack.count .. " " .. itemstack.name ..
    --                "to teleport queue")

    if (not can_insert) then
        game.print("Can't recall, no space!")
        return
    end

    local queueEntry = {
        source = source,
        destination = destination,
        startTick = currentTick,
        endTick = math.abs(currentTick + (dist / unitsPerTick)),
        itemstack = itemstack
    }
    table.insert(teleportQueue, queueEntry)
    -- local timeTo

end

local function setGUISize(element, w, h)
    if (w) then element.style.width = w end
    if (h) then element.style.height = h end
end

local function updateRecallGuiElement(gui, name)
    -- if (gui['robot-recall-chest']) then
    --     gui['robot-recall-chest']['frame']['scrollpane'][name .. '-flow'].destroy()
    --     gui['robot-recall-chest']['frame']['scrollpane'][name .. '-progressbar'].destroy()
    -- end
end

local function updateRecallGui(event, gui, player)
    local totalProgress = {}
    if (gui == nil) then return end
    if (gui['robot-recall-chest'] ~= nil) then
        local scrollpane = gui['robot-recall-chest']['frame']['scrollpane']
        for _, e in ipairs(teleportQueue) do
            -- if (not itemstack.valid)
            if (e.destination.unit_number == player.opened.unit_number) then
                if (e.itemstack.valid_for_read) then
                    local itemname = e.itemstack.prototype.name
                    local progress = math.min(
                                         (event.tick - e.startTick) /
                                             (e.endTick - e.startTick), 1)
                    if (totalProgress[itemname]) then
                        table.insert(totalProgress[itemname], progress)
                    else
                        totalProgress[itemname] = {progress}
                    end
                end
            end
        end

        -- if (not scrollpane) then return end
        for _, e in pairs(scrollpane.children) do
            if (e.type == "progressbar") then
                local itemname = string.sub(e.name, 0, -13)
                if (totalProgress[itemname]) then
                    local progress = getAverage(totalProgress[itemname])
                    e.visible = true
                    e.value = progress
                else
                    e.value = 0
                    e.visible = false
                end
            end
        end
    end
end

local function drawRobotRecallGui(basegui, logisticNetwork)

    for k, cell in pairs(logisticNetwork.cells) do
        local inv = cell.owner.get_inventory(defines.inventory.roboport_robot)
        for i = 1, #inv do
            local itemstack = inv[i]
            if (itemstack.valid_for_read) then
                if (not robots[itemstack.prototype.name]) then
                    -- local global_proto = game.prototypes[itemstack.prototype.name]
                    robots[itemstack.prototype.name] =
                        {
                            count = itemstack.count,
                            locale = itemstack.prototype.localised_name,
                            item = itemstack.prototype
                        }
                else
                    -- robots[itemstack.prototype.localised_name] = 
                    robots[itemstack.prototype.name].count =
                        robots[itemstack.prototype.name].count + itemstack.count
                end
            end
        end
    end

    for k, v in pairs(robots) do
        local flow = basegui.add({type = "flow", name = k .. '-flow'})
        local progressBar = basegui.add({
            type = "progressbar",
            name = k .. '-progressbar'
        })
        progressBar.visible = false
        local robotSprite = flow.add({
            type = "sprite-button",
            name = 'recall-' .. k,
            sprite = "item/" .. k,
            tooltip = {"", "Recall ", v.locale}
        })
        local robotLabel = flow.add({
            type = "label",
            name = "label",
            caption = {"", v.locale, "\nCount: " .. v.count}
        })
        flow.style.vertical_align = "center"

        robotLabel.style.single_line = false
    end

    -- updateRecallGui(gui)
end

local function createRobotRecallGUI(ent, ply, gui)
    if (not (ent and ent.name == "robot-recall-chest")) then return end
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

    if (ent.logistic_network) then
        -- game.print(ent.logistic_network.robots)
        -- recallFrame.direction = "vertical"
        drawRobotRecallGui(recallScrollFlow, ent.logistic_network)
    end
end

local function callRobotsToEntity(location_ent, logisticNetwork, robotItem, tick)

    for k, cell in pairs(logisticNetwork.cells) do
        local roboport = cell.owner
        local inv = roboport.get_inventory(defines.inventory.roboport_robot)
        for i = 1, #inv do
            local itemstack = inv[i]
            if (itemstack.valid_for_read) then
                if (itemstack.prototype == robotItem) then
                    -- game.print("Found " .. robotItem.name)
                    addToTeleportQueue(roboport, location_ent, itemstack, tick)

                end
            end
        end
    end

end

local function updateTeleportJobs(event)
    for k, e in ipairs(teleportQueue) do
        -- if (not itemstack.valid)
        if (event.tick >= e.endTick) then
            local destinationInv = e.destination.get_inventory(
                                       defines.inventory.roboport_robot) or
                                       e.destination.get_inventory(
                                           defines.inventory.chest)
            local sourceInv = e.source.get_inventory(
                                  defines.inventory.roboport_robot) or
                                  e.source
                                      .get_inventory(defines.inventory.chest)
            if (e.destination.get_inventory(1).can_insert(e.itemstack)) then
                local amnt = e.destination.insert(e.itemstack)
                if (amnt == e.itemstack.count) then
                    e.itemstack.clear()
                else
                    e.itemstack.count = e.itemstack.count - amnt
                end
            end
            for _, p in pairs(game.players) do
                -- removeRecallGuiElement(p.gui.screen, e.itemstack.prototype.name)
                createRobotRecallGUI(p.opened, p, p.gui.screen)
            end
            table.remove(teleportQueue, k)
        end
    end
end

script.on_event({defines.events.on_gui_opened}, function(event)
    local ent = event.entity
    local ply = game.players[event.player_index]
    local gui = ply.gui.screen
    createRobotRecallGUI(ent, ply, gui)
    -- recallFrame.add({})

    -- local closeButton = recallFrame.add({type="button",name="robot-recall-chest.close", caption="Close!"})

end)

script.on_event({defines.events.on_gui_closed}, function(event)
    local ent = event.entity
    local ply = game.players[event.player_index]
    local gui = ply.gui.screen
    if (gui['robot-recall-chest'] ~= nil) then
        gui['robot-recall-chest'].destroy()
    end
    -- game.print('on_gui_close')
end)

script.on_event({defines.events.on_gui_click}, function(event)
    -- game.print(event)
    local ply = game.players[event.player_index]
    -- local items = game.item_prototypes

    if (event.element.type == "sprite-button" and event.element.name:sub(1, 7) ==
        'recall-') then
        local itemname = event.element.name:sub(8)
        local item = game.item_prototypes[itemname]
        -- game.print('recalling "' .. itemname .. '"')
        callRobotsToEntity(ply.opened, ply.opened.logistic_network, item,
                           event.tick)

    end

    if (event.element.name == "robot-recall-chest.close") then
        event.element.parent.destroy()
    end
end)

script.on_nth_tick(20, function(event)
    updateTeleportJobs(event)
    if (event.tick % 5 == 0) then
        for k, v in pairs(game.players) do
            -- local  = v.gui.screen
            local gui = v.gui.screen
            updateRecallGui(event, gui, v)
        end
    end
end)

script.on_nth_tick(2, function(event)
    for k, v in pairs(game.players) do
        -- local  = v.gui.screen
        local gui = v.gui.screen
        updateRecallGui(event, gui, v)
    end
end)
