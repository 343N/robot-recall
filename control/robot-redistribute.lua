script.on_nth_tick(15, function(event)
    for k, v in pairs(global.deploying) do
        if (v.deploying) then
            local inv = v.ent.get_inventory(1)
            if (not inv.is_empty()) then
                local items = inv.get_contents()
                for name, count in pairs(items) do
                    local placeresult = game.item_prototypes[name].place_result
                    if (placeresult.type == "logistic-robot" or placeresult.type ==
                        "construction-robot") then
                        if (logisticNetworkHasItemSpace(v.logistic_network, name)) then
                            v.surface.create_entity(
                                {
                                    name = placeresult.name,
                                    position = v.ent.position,
                                    force = v.ent.logistic_network.force
                                })
                            inv.remove({name = name, count = 1})
                        end
                    end

                end
            end
        end
    end
end)

script.on_event(defines.events.on_built_entity, function(event) end)

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

script.on_nth_tick(60, function(event)
    for k, v in pairs(global.deploying) do
        if (v.ent and not v.ent.valid) then table.remove(global.deploying, k) 
        elseif (v.ent and not v.ent.is_empty()) then v.deploying = true 
        else v.deploying = false end
    end

end)
