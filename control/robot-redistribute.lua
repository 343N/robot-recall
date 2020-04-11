local deploying = {}

script.on_nth_tick(60, function(event)

    for _, surface in pairs(game.surfaces) do
        local deploymentstations = surface.find_entities_filtered(
                                       {name = "robot-redistribute-chest"})

        for k, v in pairs(deploymentstations) do
            if (not v.get_inventory(1).is_empty()) then
                deploying[v.unit_number] = v
            else
                if (deploying[v.unit_number]) then table.remove(deploying, v.unit_number) end
            end
        end

    end

end)

script.on_nth_tick(15, function(event)
    local removeList = {}
    for k, v in pairs(deploying) do
        if (not v.valid) then 
            table.insert(removeList, k, v) 
            break 
        end
        local inv = v.get_inventory(1)
        if (not inv.is_empty()) then
            local items = inv.get_contents()
            for name, count in pairs(items) do
                local placeresult = game.item_prototypes[name].place_result
                if (placeresult.type == "logistic-robot" or 
                placeresult.type == "construction-robot") then
                    if (logisticNetworkHasItemSpace(v.logistic_network, name)) then
                        v.surface.create_entity(
                            {
                                name = placeresult.name,
                                position = v.position,
                                force = v.logistic_network.force
                            })
                        inv.remove({name = name, count = 1})
                    end
                end

            end
        else
            table.insert(removeList, k, v)
        end
    end

    for k, v in pairs(removeList) do 
        table.remove(deploying, k)
    end

end)

-- function canInsertIntoRoboport(itemname, logistic_network)
--     -- local roboport = 
--     if (logistic_network and logistic_network.valid) then
--         for k, v in pairs(logistic_network.cells) do
--             local inv = cell.owner.get_inventory(
--                             defines.inventory.roboport_robot)
--             if (inv and inv.can_insert({name = itemname, count = 1})) then
--                 return true
--             end
--         end
--     end
--     return false
-- end

function logisticNetworkHasItemSpace(logistic_network, itemname)
    if (logistic_network and logistic_network.valid) then
        for k, v in pairs(logistic_network.cells) do
            local inv = v.owner.get_inventory(defines.inventory.roboport_robot)
            if (inv and inv.can_insert({name = itemname, count = 1})) then
                return true
            end
        end
    end
    return false
end
