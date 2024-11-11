if GetResourceState('ox_inventory') == 'started' then
    exports.ox_inventory:registerHook('buyItem', function(payload)
        if payload.metadata and payload.metadata.serial then
            local xPlayer = Bridge.getPlayerFromId(payload.source)
            local coords = GetEntityCoords(GetPlayerPed(payload.source))
            MySQL.Async.execute('INSERT INTO `mdt_weapons` (weapon, serialnumber, identifier, coords) VALUES (?, ?, ?, ?)', {payload.itemName, payload.metadata.serial, Bridge.getIdentifier(xPlayer), json.encode({x = coords.x, y = coords.y})})
        end
        return true
    end, {
        print = false,
    })
end