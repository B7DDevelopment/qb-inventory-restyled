local QBCore = exports['qb-core']:GetCoreObject()

local TimeAllowed = 60 * 60 * 24 * 2
function ConvertQuality(item)
	local StartDate = item.created
    if not item.name or not QBCore.Shared.Items[item.name:lower()] then
        return 100
    end
    local DecayRate = QBCore.Shared.Items[item.name:lower()]["decay"] ~= nil and QBCore.Shared.Items[item.name:lower()]["decay"] or 0.0
    if DecayRate == nil then
        DecayRate = 0
    end
    local TimeExtra = math.ceil((TimeAllowed * DecayRate))
    local percentDone = 100 - math.ceil((((os.time() - StartDate) / TimeExtra) * 100))
    if DecayRate == 0 then
        percentDone = 100
    end
    if percentDone < 0 then
        percentDone = 0
    end
    return percentDone
end

QBCore.Functions.CreateCallback('inventory:server:ConvertQuality', function(source, cb, inventory, other, id)
    local src = source
    local data = {}
    local Player = QBCore.Functions.GetPlayer(src)
    if not inventory or type(inventory) ~= "table" then
        data.inventory = {}
        data.other = other
        cb(data)
        return
    end
    for k, item in pairs(inventory) do
        if item.created and item.name and QBCore.Shared.Items[item.name:lower()] then
            if QBCore.Shared.Items[item.name:lower()]["decay"] ~= nil or QBCore.Shared.Items[item.name:lower()]["decay"] ~= 0 then
                if item.info then
		            if type(item.info) == "string" then
                        item.info = {}
                    end
                    if item.info.quality == nil then
                        item.info.quality = 100
                    end
                else
                    local info = {quality = 100}
                    item.info = info
                end
                local quality = ConvertQuality(item)
                if item.info.quality then
                    if quality < item.info.quality then
                        item.info.quality = quality
                    end
                else
                    item.info = {quality = quality}
                end
            else
                if item.info then 
                    item.info.quality = 100
                else
                    local info = {quality = 100}
                    item.info = info
                end
            end
        end
    end
    if other and type(other) == "table" and other["inventory"] and type(other["inventory"]) == "table" then
        for k, item in pairs(other["inventory"]) do
            if item.created and item.name and QBCore.Shared.Items[item.name:lower()] then
                if QBCore.Shared.Items[item.name:lower()]["decay"] ~= nil or QBCore.Shared.Items[item.name:lower()]["decay"] ~= 0 then
                    if item.info then 
                        if item.info.quality == nil then
                            item.info.quality = 100
                        end
                    else
                        local info = {quality = 100}
                        item.info = info
                    end
                    local quality = ConvertQuality(item)
                    if item.info.quality then
                        if quality < item.info.quality then
                            item.info.quality = quality
                        end
                    else
                        item.info = {quality = quality}
                    end
                else
                    if item.info then 
                        item.info.quality = 100
                    else
                        local info = {quality = 100}
                        item.info = info
                    end
                end
            end
        end
    end
    if id then
        if Gloveboxes[id] then
            local GlobeBoxItems = GetOwnedVehicleGloveboxItems(id)
            for k, item in pairs(GlobeBoxItems) do
                if item.created and item.name and QBCore.Shared.Items[item.name:lower()] then
                    if QBCore.Shared.Items[item.name:lower()]["decay"] ~= nil or QBCore.Shared.Items[item.name:lower()]["decay"] ~= 0 then
                        if item.info then
                            if type(item.info) == "string" then
                                item.info = {}
                            end
                            if item.info.quality == nil then
                                item.info.quality = 100
                            end
                        else
                            local info = {quality = 100}
                            item.info = info
                        end
                        local quality = ConvertQuality(item)
                        if item.info.quality then
                            if quality < item.info.quality then
                                item.info.quality = quality
                            end
                        else
                            item.info = {quality = quality}
                        end
                    else
                        if item.info then 
                            item.info.quality = 100
                        else
                            local info = {quality = 100}
                            item.info = info
                        end
                    end
                end
            end
            SaveOwnedGloveboxItems(id, GlobeBoxItems)
        elseif Trunks[id] then
            local trunkItems = GetOwnedVehicleItems(id)
            for k, item in pairs(trunkItems) do
                if item.created and item.name and QBCore.Shared.Items[item.name:lower()] then
                    if QBCore.Shared.Items[item.name:lower()]["decay"] ~= nil or QBCore.Shared.Items[item.name:lower()]["decay"] ~= 0 then
                        if item.info then
                            if type(item.info) == "string" then
                                item.info = {}
                            end
                            if item.info.quality == nil then
                                item.info.quality = 100
                            end
                        else
                            local info = {quality = 100}
                            item.info = info
                        end
                        local quality = ConvertQuality(item)
                        if item.info.quality then
                            if quality < item.info.quality then
                                item.info.quality = quality
                            end
                        else
                            item.info = {quality = quality}
                        end
                    else
                        if item.info then 
                            item.info.quality = 100
                        else
                            local info = {quality = 100}
                            item.info = info
                        end
                    end
                end
            end
            SaveOwnedVehicleItems(id, trunkItems)
        elseif Stashes[id] then
            local stashItems = GetStashItems(id)
            for k, item in pairs(stashItems) do
                if item.created and item.name and QBCore.Shared.Items[item.name:lower()] then
                    if QBCore.Shared.Items[item.name:lower()]["decay"] ~= nil or QBCore.Shared.Items[item.name:lower()]["decay"] ~= 0 then
                        if item.info then
                            if type(item.info) == "string" then
                                item.info = {}
                            end
                            if item.info.quality == nil then
                                item.info.quality = 100
                            end
                        else
                            local info = {quality = 100}
                            item.info = info
                        end
                        local quality = ConvertQuality(item)
                        if item.info.quality then
                            if quality < item.info.quality then
                                item.info.quality = quality
                            end
                        else
                            item.info = {quality = quality}
                        end
                    else
                        if item.info then 
                            item.info.quality = 100
                        else
                            local info = {quality = 100}
                            item.info = info
                        end
                    end
                end
            end
            SaveStashItems(id, stashItems)
        end
    end
    SetInventory(src, inventory)
    data.inventory = inventory
    data.other = other
    cb(data)
end)