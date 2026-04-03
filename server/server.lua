
local QBCore = exports['qb-core']:GetCoreObject()
local Drops = {}
Trunks = {}
Gloveboxes = {}
Stashes = {}
local ShopItems = {}

function GetDrops()
    return Drops
end

function LoadInventory(source, citizenid)
    local inventory = MySQL.prepare.await('SELECT inventory FROM players WHERE citizenid = ?', { citizenid })
	local loadedInventory = {}
    local missingItems = {}

    if not inventory then return loadedInventory end

	inventory = json.decode(inventory)
	if table.type(inventory) == "empty" then return loadedInventory end

	for _, item in pairs(inventory) do
		if item then
			local itemInfo = QBCore.Shared.Items[item.name:lower()]
			if itemInfo then
				loadedInventory[item.slot] = {
					name = itemInfo['name'],
					amount = item.amount,
					info = item.info or '',
					label = itemInfo['label'],
					description = itemInfo['description'] or '',
					weight = itemInfo['weight'],
					type = itemInfo['type'],
					unique = itemInfo['unique'],
					useable = itemInfo['useable'],
					image = itemInfo['image'],
					shouldClose = itemInfo['shouldClose'],
					slot = item.slot,
					combinable = itemInfo['combinable'],
                    created = item.created,
				}
			else
				missingItems[#missingItems + 1] = item.name:lower()
			end
		end
	end

    if #missingItems > 0 then
        print(("The following items were removed for player %s as they no longer exist"):format(GetPlayerName(source)))
		QBCore.Debug(missingItems)
    end

    return loadedInventory
end

exports("LoadInventory", LoadInventory)

function SaveInventory(source, offline)
	local PlayerData
	if not offline then
		local Player = QBCore.Functions.GetPlayer(source)

		if not Player then return end

		PlayerData = Player.PlayerData
	else
		PlayerData = source
	end

    local items = PlayerData.items
    local ItemsJson = {}
    if items and table.type(items) ~= "empty" then
        for slot, item in pairs(items) do
            if items[slot] then
                ItemsJson[#ItemsJson+1] = {
                    name = item.name,
                    amount = item.amount,
                    info = item.info,
                    type = item.type,
                    slot = slot,
                    created = item.created
                }
            end
        end
        MySQL.prepare('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode(ItemsJson), PlayerData.citizenid })
    else
        MySQL.prepare('UPDATE players SET inventory = ? WHERE citizenid = ?', { '[]', PlayerData.citizenid })
    end
end

exports("SaveInventory", SaveInventory)

local function GetTotalWeight(items)
	local weight = 0
    if not items then return 0 end
    for _, item in pairs(items) do
        weight += item.weight * item.amount
    end
    return tonumber(weight)
end

exports("GetTotalWeight", GetTotalWeight)

local function GetSlotsByItem(items, itemName)
    local slotsFound = {}
    if not items then return slotsFound end
    for slot, item in pairs(items) do
        if item.name:lower() == itemName:lower() then
            slotsFound[#slotsFound+1] = slot
        end
    end
    return slotsFound
end

exports("GetSlotsByItem", GetSlotsByItem)

local function GetFirstSlotByItem(items, itemName)
    if not items then return nil end
    for slot, item in pairs(items) do
        if item.name:lower() == itemName:lower() then
            return tonumber(slot)
        end
    end
    return nil
end

exports("GetFirstSlotByItem", GetFirstSlotByItem)

function AddItem(source, item, amount, slot, info, box)
	local Player = QBCore.Functions.GetPlayer(source)

	if not Player then return false end

	local totalWeight = GetTotalWeight(Player.PlayerData.items)
	local itemInfo = QBCore.Shared.Items[item:lower()]
	if not itemInfo and not Player.Offline then
		QBCore.Functions.Notify(source, "Item does not exist", 'error')
		return false
	end

	amount = tonumber(amount) or 1
	if not slot or slot == 0 then
		slot = GetFirstSlotByItem(Player.PlayerData.items, item)
	end
	slot = tonumber(slot)
	info = info or {}
    local time = os.time()
    if not created then 
        itemInfo['created'] = time
    else 
        itemInfo['created'] = created
    end
    if itemInfo["type"] == 'item' and info == nil then
        info = { quality = 100 }
    end

	if itemInfo["name"] == 'lockpick' then 
		if not info.uses then 
			info.uses = 5
		end
		if not info.tier then
			info.tier = "low"
		end
		elseif itemInfo["name"] == 'drill' then 
    if not info.uses then 
        info.uses = 5
    end
	elseif itemInfo["name"] == 'breaker' then 
		if not info.uses then 
			info.uses = 10
		end
	elseif itemInfo["name"] == 'hack_device' then 
		if not info.exp then 
			local timeex = "259200"
			info.exp = tonumber(os.time() + timeex)
			info.explable = QBCore.Functions.TimeFormate(info.exp)
		end
	elseif itemInfo["name"] == 'syphoningkit' then 
		if not info.gasamount then 
			info.gasamount = 0
		end
	end

	if itemInfo['type'] == 'weapon' then
		info.serie = info.serie or tostring(QBCore.Shared.RandomInt(2) .. QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(4))
		info.quality = info.quality or 100
	end
	if (totalWeight + (itemInfo['weight'] * amount)) <= Config.MaxInventoryWeight then
		if slot and slot > 0 then
			if Player.PlayerData.items[slot] == nil then
				Player.PlayerData.items[slot] = { name = itemInfo['name'], amount = amount, info = info or '', label = itemInfo['label'], description = itemInfo['description'] or '', weight = itemInfo['weight'], type = itemInfo['type'], unique = itemInfo['unique'], useable = itemInfo['useable'], image = itemInfo['image'], shouldClose = itemInfo['shouldClose'], slot = slot, combinable = itemInfo['combinable'], created = itemInfo['created'] }
				Player.Functions.SetPlayerData("items", Player.PlayerData.items)
				if item == "phone" then
					TriggerClientEvent('lb-phone:itemAdded', source)
				end
				if Player.Offline then return true end
				TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'AddItem', 'green', '**' .. GetPlayerName(source) .. ' (citizenid: ' .. Player.PlayerData.citizenid .. ' | id: ' .. source .. ')** got item: [slot:' .. slot .. '], itemname: ' .. Player.PlayerData.items[slot].name .. ', added amount: ' .. amount .. ', new total amount: ' .. Player.PlayerData.items[slot].amount)
				return true
			elseif (Player.PlayerData.items[slot].name:lower() == item:lower()) and (itemInfo['type'] == 'item' and not itemInfo['unique']) then
				Player.PlayerData.items[slot].amount = Player.PlayerData.items[slot].amount + amount
				Player.Functions.SetPlayerData("items", Player.PlayerData.items)
				if item == "phone" then
					TriggerClientEvent('lb-phone:itemAdded', source)
				end
				if Player.Offline then return true end
				TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'AddItem', 'green', '**' .. GetPlayerName(source) .. ' (citizenid: ' .. Player.PlayerData.citizenid .. ' | id: ' .. source .. ')** got item: [slot:' .. slot .. '], itemname: ' .. Player.PlayerData.items[slot].name .. ', added amount: ' .. amount .. ', new total amount: ' .. Player.PlayerData.items[slot].amount)
				return true
			else
				local existingSlot = GetFirstSlotByItem(Player.PlayerData.items, item)
				if existingSlot and (itemInfo['type'] == 'item' and not itemInfo['unique']) then
					Player.PlayerData.items[existingSlot].amount = Player.PlayerData.items[existingSlot].amount + amount
					Player.Functions.SetPlayerData("items", Player.PlayerData.items)
					if item == "phone" then
						TriggerClientEvent('lb-phone:itemAdded', source)
					end
					if Player.Offline then return true end
					TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'AddItem', 'green', '**' .. GetPlayerName(source) .. ' (citizenid: ' .. Player.PlayerData.citizenid .. ' | id: ' .. source .. ')** got item: [slot:' .. existingSlot .. '], itemname: ' .. Player.PlayerData.items[existingSlot].name .. ', added amount: ' .. amount .. ', new total amount: ' .. Player.PlayerData.items[existingSlot].amount)
					return true
				end
				for i = 1, Config.MaxInventorySlots, 1 do
					if Player.PlayerData.items[i] == nil then
						Player.PlayerData.items[i] = { name = itemInfo['name'], amount = amount, info = info or '', label = itemInfo['label'], description = itemInfo['description'] or '', weight = itemInfo['weight'], type = itemInfo['type'], unique = itemInfo['unique'], useable = itemInfo['useable'], image = itemInfo['image'], shouldClose = itemInfo['shouldClose'], slot = i, combinable = itemInfo['combinable'], created = itemInfo['created'] }
						Player.Functions.SetPlayerData("items", Player.PlayerData.items)
						if item == "phone" then
							TriggerClientEvent('lb-phone:itemAdded', source)
						end
						if Player.Offline then return true end
						TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'AddItem', 'green', '**' .. GetPlayerName(source) .. ' (citizenid: ' .. Player.PlayerData.citizenid .. ' | id: ' .. source .. ')** got item: [slot:' .. i .. '], itemname: ' .. Player.PlayerData.items[i].name .. ', added amount: ' .. amount .. ', new total amount: ' .. Player.PlayerData.items[i].amount)
						return true
					end
				end
			end
		else
			if (slot and Player.PlayerData.items[slot]) and (Player.PlayerData.items[slot].name:lower() == item:lower()) and (itemInfo['type'] == 'item' and not itemInfo['unique']) then
				Player.PlayerData.items[slot].amount = Player.PlayerData.items[slot].amount + amount
				Player.Functions.SetPlayerData("items", Player.PlayerData.items)
				if item == "phone" then
					TriggerClientEvent('lb-phone:itemAdded', source)
				end
				if Player.Offline then return true end
				TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'AddItem', 'green', '**' .. GetPlayerName(source) .. ' (citizenid: ' .. Player.PlayerData.citizenid .. ' | id: ' .. source .. ')** got item: [slot:' .. slot .. '], itemname: ' .. Player.PlayerData.items[slot].name .. ', added amount: ' .. amount .. ', new total amount: ' .. Player.PlayerData.items[slot].amount)
				return true
			elseif not itemInfo['unique'] and slot and Player.PlayerData.items[slot] == nil then
				Player.PlayerData.items[slot] = { name = itemInfo['name'], amount = amount, info = info or '', label = itemInfo['label'], description = itemInfo['description'] or '', weight = itemInfo['weight'], type = itemInfo['type'], unique = itemInfo['unique'], useable = itemInfo['useable'], image = itemInfo['image'], shouldClose = itemInfo['shouldClose'], slot = slot, combinable = itemInfo['combinable'], created = itemInfo['created'] }
				Player.Functions.SetPlayerData("items", Player.PlayerData.items)
				if item == "phone" then
					TriggerClientEvent('lb-phone:itemAdded', source)
				end
				if Player.Offline then return true end
				TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'AddItem', 'green', '**' .. GetPlayerName(source) .. ' (citizenid: ' .. Player.PlayerData.citizenid .. ' | id: ' .. source .. ')** got item: [slot:' .. slot .. '], itemname: ' .. Player.PlayerData.items[slot].name .. ', added amount: ' .. amount .. ', new total amount: ' .. Player.PlayerData.items[slot].amount)
				return true
			elseif itemInfo['unique'] or (not slot or slot == nil) or itemInfo['type'] == 'weapon' then
				for i = 1, Config.MaxInventorySlots, 1 do
					if Player.PlayerData.items[i] == nil then
						Player.PlayerData.items[i] = { name = itemInfo['name'], amount = amount, info = info or '', label = itemInfo['label'], description = itemInfo['description'] or '', weight = itemInfo['weight'], type = itemInfo['type'], unique = itemInfo['unique'], useable = itemInfo['useable'], image = itemInfo['image'], shouldClose = itemInfo['shouldClose'], slot = i, combinable = itemInfo['combinable'], created = itemInfo['created'] }
						Player.Functions.SetPlayerData("items", Player.PlayerData.items)
						if item == "phone" then
							TriggerClientEvent('lb-phone:itemAdded', source)
						end
						if Player.Offline then return true end
						TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'AddItem', 'green', '**' .. GetPlayerName(source) .. ' (citizenid: ' .. Player.PlayerData.citizenid .. ' | id: ' .. source .. ')** got item: [slot:' .. i .. '], itemname: ' .. Player.PlayerData.items[i].name .. ', added amount: ' .. amount .. ', new total amount: ' .. Player.PlayerData.items[i].amount)
						return true
					end
				end
			end
		end
	elseif not Player.Offline then
		QBCore.Functions.Notify(source, "Inventory too full", 'error')
	end
	return false
end

exports("AddItem", AddItem)

local function RemoveItem(source, item, amount, slot)
	local Player = QBCore.Functions.GetPlayer(source)

	if not Player then return false end

	amount = tonumber(amount) or 1
	slot = tonumber(slot)
	if item == "phone" then
		TriggerClientEvent('lb-phone:itemRemoved', source)
	end

	if slot then
		if Player.PlayerData.items[slot].amount > amount then
			Player.PlayerData.items[slot].amount = Player.PlayerData.items[slot].amount - amount
			Player.Functions.SetPlayerData("items", Player.PlayerData.items)

			if not Player.Offline then
				TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'RemoveItem', 'red', '**' .. GetPlayerName(source) .. ' (citizenid: ' .. Player.PlayerData.citizenid .. ' | id: ' .. source .. ')** lost item: [slot:' .. slot .. '], itemname: ' .. Player.PlayerData.items[slot].name .. ', removed amount: ' .. amount .. ', new total amount: ' .. Player.PlayerData.items[slot].amount)
			end

			TriggerClientEvent("inventory:client:UpdatePlayerInventory", Player.PlayerData.source, false)
			return true
		elseif Player.PlayerData.items[slot].amount == amount then
			Player.PlayerData.items[slot] = nil
			Player.Functions.SetPlayerData("items", Player.PlayerData.items)

			if Player.Offline then return true end

			TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'RemoveItem', 'red', '**' .. GetPlayerName(source) .. ' (citizenid: ' .. Player.PlayerData.citizenid .. ' | id: ' .. source .. ')** lost item: [slot:' .. slot .. '], itemname: ' .. item .. ', removed amount: ' .. amount .. ', item removed')
    		TriggerClientEvent("inventory:client:UpdatePlayerInventory", Player.PlayerData.source, false)

			return true
		end
	else
		local slots = GetSlotsByItem(Player.PlayerData.items, item)
		local amountToRemove = amount

		if not slots then return false end

		for _, _slot in pairs(slots) do
			if Player.PlayerData.items[_slot].amount > amountToRemove then
				Player.PlayerData.items[_slot].amount = Player.PlayerData.items[_slot].amount - amountToRemove
				Player.Functions.SetPlayerData("items", Player.PlayerData.items)

				if not Player.Offline then
					TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'RemoveItem', 'red', '**' .. GetPlayerName(source) .. ' (citizenid: ' .. Player.PlayerData.citizenid .. ' | id: ' .. source .. ')** lost item: [slot:' .. _slot .. '], itemname: ' .. Player.PlayerData.items[_slot].name .. ', removed amount: ' .. amount .. ', new total amount: ' .. Player.PlayerData.items[_slot].amount)
				end

				return true
			elseif Player.PlayerData.items[_slot].amount == amountToRemove then
				Player.PlayerData.items[_slot] = nil
				Player.Functions.SetPlayerData("items", Player.PlayerData.items)

				if Player.Offline then return true end

				TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'RemoveItem', 'red', '**' .. GetPlayerName(source) .. ' (citizenid: ' .. Player.PlayerData.citizenid .. ' | id: ' .. source .. ')** lost item: [slot:' .. _slot .. '], itemname: ' .. item .. ', removed amount: ' .. amount .. ', item removed')

				return true
			end
		end
	end
	return false
end

exports("RemoveItem", RemoveItem)

RegisterNetEvent('inventory:RemoveItem', function(itemName, amount, slot)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    RemoveItem(src, itemName, amount, slot)
end)

RegisterNetEvent('inventory:AddItem', function(itemName, amount, slot, info)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    AddItem(src, itemName, amount, slot, info)
end)

local function GetItemBySlot(source, slot)
	local Player = QBCore.Functions.GetPlayer(source)
	slot = tonumber(slot)
	return Player.PlayerData.items[slot]
end

exports("GetItemBySlot", GetItemBySlot)

local function GetItemByName(source, item)
	local Player = QBCore.Functions.GetPlayer(source)
	item = tostring(item):lower()
	local slot = GetFirstSlotByItem(Player.PlayerData.items, item)
	return Player.PlayerData.items[slot]
end

exports("GetItemByName", GetItemByName)

local function GetItemsByName(source, item)
	local Player = QBCore.Functions.GetPlayer(source)
	item = tostring(item):lower()
	local items = {}
	local slots = GetSlotsByItem(Player.PlayerData.items, item)
	for _, slot in pairs(slots) do
		if slot then
			items[#items+1] = Player.PlayerData.items[slot]
		end
	end
	return items
end

exports("GetItemsByName", GetItemsByName)

local function ClearInventory(source, filterItems)
	local Player = QBCore.Functions.GetPlayer(source)
	local savedItemData = {}

	if filterItems then
		local filterItemsType = type(filterItems)
		if filterItemsType == "string" then
			local item = GetItemByName(source, filterItems)

			if item then
				savedItemData[item.slot] = item
			end
		elseif filterItemsType == "table" and table.type(filterItems) == "array" then
			for i = 1, #filterItems do
				local item = GetItemByName(source, filterItems[i])

				if item then
					savedItemData[item.slot] = item
				end
			end
		end
	end

	Player.Functions.SetPlayerData("items", savedItemData)

	if Player.Offline then return end

	TriggerEvent('qb-log:server:CreateLog', 'playerinventory', 'ClearInventory', 'red', '**' .. GetPlayerName(source) .. ' (citizenid: ' .. Player.PlayerData.citizenid .. ' | id: ' .. source .. ')** inventory cleared')
end

exports("ClearInventory", ClearInventory)

function SetInventory(source, items)
	local Player = QBCore.Functions.GetPlayer(source)

	Player.Functions.SetPlayerData("items", items)

	if Player.Offline then return end

end

exports("SetInventory", SetInventory)

local function SetItemData(source, itemName, key, val)
	if not itemName or not key then return false end

	local Player = QBCore.Functions.GetPlayer(source)

	if not Player then return end

	local item = GetItemByName(source, itemName)

	if not item then return false end

	item[key] = val
	Player.PlayerData.items[item.slot] = item
	Player.Functions.SetPlayerData("items", Player.PlayerData.items)

	return true
end

exports("SetItemData", SetItemData)

local function HasItem(source, items, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end
    local isTable = type(items) == 'table'
    local isArray = isTable and table.type(items) == 'array' or false
    local totalItems = #items
    local count = 0
    local kvIndex = 2
    if isTable and not isArray then
        totalItems = 0
        for _ in pairs(items) do totalItems += 1 end
        kvIndex = 1
    end
    if isTable then
        for k, v in pairs(items) do
            local itemKV = {k, v}
            local item = GetItemByName(source, itemKV[kvIndex])
            if item and ((amount and item.amount >= amount) or (not isArray and item.amount >= v) or (not amount and isArray)) then
                count += 1
            end
        end
        if count == totalItems then
            return true
        end
    else
        local item = GetItemByName(source, items)
        if item and (not amount or (item and amount and item.amount >= amount)) then
            return true
        end
    end
    return false
end

exports("HasItem", HasItem)

local function CreateUsableItem(itemName, data)
	QBCore.Functions.CreateUseableItem(itemName, data)
end

exports("CreateUsableItem", CreateUsableItem)

local function GetUsableItem(itemName)
	return QBCore.Functions.CanUseItem(itemName)
end

exports("GetUsableItem", GetUsableItem)

local function UseItem(itemName, ...)
	local itemData = GetUsableItem(itemName)
	local callback = type(itemData) == 'table' and (rawget(itemData, '__cfx_functionReference') and itemData or itemData.cb or itemData.callback) or type(itemData) == 'function' and itemData
	if not callback then return end
	callback(...)
end

exports("UseItem", UseItem)

local function recipeContains(recipe, fromItem)
	for _, v in pairs(recipe.accept) do
		if v == fromItem.name then
			return true
		end
	end

	return false
end

local function hasCraftItems(source, CostItems, amount)
	for k, v in pairs(CostItems) do
		local item = GetItemByName(source, k)

		if not item then return false end

		if item.amount < (v * amount) then return false end
	end
	return true
end

local function IsVehicleOwned(plate)
    local result = MySQL.scalar.await('SELECT 1 from player_vehicles WHERE plate = ?', {plate})
    return result
end

local function SetupShopItems(shopItems)
	local items = {}
	if shopItems and next(shopItems) then
		for _, item in pairs(shopItems) do
			local itemInfo = QBCore.Shared.Items[item.name:lower()]
			if itemInfo then
				items[item.slot] = {
					name = itemInfo["name"],
					amount = tonumber(item.amount),
					info = item.info or "",
					label = itemInfo["label"],
					description = itemInfo["description"] or "",
					weight = itemInfo["weight"],
					type = itemInfo["type"],
					unique = itemInfo["unique"],
					useable = itemInfo["useable"],
					price = item.price,
					image = itemInfo["image"],
					slot = item.slot,
				}
			end
		end
	end
	return items
end

function GetStashItems(stashId)
	local items = {}
	local result = nil
	local indexstart, indexend = string.find(stashId, 'Backpack_')
	local evidencstart, evidencend = string.find(stashId, 'Evidence_Box')
	if indexstart and indexend then
		result = MySQL.scalar.await('SELECT items FROM otherstashitems WHERE stash = ?', {stashId})
	elseif evidencstart and evidencend then 
		result = MySQL.scalar.await('SELECT items FROM evidencebox WHERE stash = ?', {stashId})
	else
		result = MySQL.scalar.await('SELECT items FROM stashitems WHERE stash = ?', {stashId})
	end

	if not result then return items end
	local stashItems = json.decode(result)
	if not stashItems then return items end

	for _, item in pairs(stashItems) do
		local itemInfo = QBCore.Shared.Items[item.name:lower()]
		if itemInfo then
			items[item.slot] = {
				name = itemInfo["name"],
				amount = tonumber(item.amount),
				info = item.info or "",
				label = itemInfo["label"],
				description = itemInfo["description"] or "",
				weight = itemInfo["weight"],
				type = itemInfo["type"],
				unique = itemInfo["unique"],
				useable = itemInfo["useable"],
				image = itemInfo["image"],
				slot = item.slot,
				created = item.created
			}
		end
	end
	return items
end

local BLockedFromSave = {
	["Stash-None"] = true,
	["Stash-Trash"] = true,
}

function SaveStashItems(stashId, items)
	if BLockedFromSave[Stashes[stashId].label] or not items then return end
	if BLockedFromSave[Stashes[stashId].label:sub(1,11)] or not items then return end

	local indexstart, indexend = string.find(stashId, 'Backpack_')
	if indexstart and indexend then
		for _, item in pairs(items) do
			item.description = nil
		end
	
		MySQL.insert('INSERT INTO otherstashitems (stash, items) VALUES (:stash, :items) ON DUPLICATE KEY UPDATE items = :items', {
			['stash'] = stashId,
			['items'] = json.encode(items)
		})
		Stashes[stashId].isOpen = false
		return
	end

	local evidencstart, evidencend = string.find(stashId, 'Evidence_Box')
	if evidencstart and evidencend then
		for _, item in pairs(items) do
			item.description = nil
		end
	
		MySQL.insert('INSERT INTO evidencebox (stash, items) VALUES (:stash, :items) ON DUPLICATE KEY UPDATE items = :items', {
			['stash'] = stashId,
			['items'] = json.encode(items)
		})
		Stashes[stashId].isOpen = false
		return
	end

	for _, item in pairs(items) do
		item.description = nil
	end

	MySQL.insert('INSERT INTO stashitems (stash, items) VALUES (:stash, :items) ON DUPLICATE KEY UPDATE items = :items', {
		['stash'] = stashId,
		['items'] = json.encode(items)
	})

	Stashes[stashId].isOpen = false
end

local function AddToStash(stashId, slot, otherslot, itemName, amount, info, created)
	amount = tonumber(amount) or 1
	local ItemData = QBCore.Shared.Items[itemName]
	
	if not Stashes[stashId] then
		Stashes[stashId] = {}
		Stashes[stashId].items = {}
	end
	if not Stashes[stashId].items then
		Stashes[stashId].items = {}
	end
	
	if not ItemData.unique then
		if Stashes[stashId].items[slot] and Stashes[stashId].items[slot].name == itemName then
			Stashes[stashId].items[slot].amount = Stashes[stashId].items[slot].amount + amount
		else
			local itemInfo = QBCore.Shared.Items[itemName:lower()]
			Stashes[stashId].items[slot] = {
				name = itemInfo["name"],
				amount = amount,
				info = info or "",
				label = itemInfo["label"],
				description = itemInfo["description"] or "",
				weight = itemInfo["weight"],
				type = itemInfo["type"],
				unique = itemInfo["unique"],
				useable = itemInfo["useable"],
				image = itemInfo["image"],
                created = created,
				slot = slot,
			}
		end
	else
		if Stashes[stashId].items[slot] and Stashes[stashId].items[slot].name == itemName then
			local itemInfo = QBCore.Shared.Items[itemName:lower()]
			Stashes[stashId].items[otherslot] = {
				name = itemInfo["name"],
				amount = amount,
				info = info or "",
				label = itemInfo["label"],
				description = itemInfo["description"] or "",
				weight = itemInfo["weight"],
				type = itemInfo["type"],
				unique = itemInfo["unique"],
				useable = itemInfo["useable"],
				image = itemInfo["image"],
				slot = otherslot,
			}
		else
			local itemInfo = QBCore.Shared.Items[itemName:lower()]
			Stashes[stashId].items[slot] = {
				name = itemInfo["name"],
				amount = amount,
				info = info or "",
				label = itemInfo["label"],
				description = itemInfo["description"] or "",
				weight = itemInfo["weight"],
				type = itemInfo["type"],
				unique = itemInfo["unique"],
				useable = itemInfo["useable"],
				image = itemInfo["image"],
				slot = slot,
			}
		end
	end
end

local function RemoveFromStash(stashId, slot, itemName, amount)
	amount = tonumber(amount) or 1
	if Stashes[stashId].items[slot] and Stashes[stashId].items[slot].name == itemName then
		if Stashes[stashId].items[slot].amount > amount then
			Stashes[stashId].items[slot].amount = Stashes[stashId].items[slot].amount - amount
		else
			Stashes[stashId].items[slot] = nil
            if next(Stashes[stashId].items) == nil then
				Stashes[stashId].items = {}
			end
		end
	else
		Stashes[stashId].items[slot] = nil
		if Stashes[stashId].items == nil then
			Stashes[stashId].items[slot] = nil
		end
	end
end

function GetOwnedVehicleItems(plate)
	local items = {}
	local result = MySQL.scalar.await('SELECT items FROM trunkitems WHERE plate = ?', {plate})
	if not result then return items end

	local trunkItems = json.decode(result)
	if not trunkItems then return items end

	for _, item in pairs(trunkItems) do
		local itemInfo = QBCore.Shared.Items[item.name:lower()]
		if itemInfo then
			items[item.slot] = {
				name = itemInfo["name"],
				amount = tonumber(item.amount),
				info = item.info or "",
				label = itemInfo["label"],
				description = itemInfo["description"] or "",
				weight = itemInfo["weight"],
				type = itemInfo["type"],
				unique = itemInfo["unique"],
				useable = itemInfo["useable"],
				image = itemInfo["image"],
				slot = item.slot,
			}
		end
	end
	return items
end

function SaveOwnedVehicleItems(plate, items)
	if Trunks[plate].label == "Trunk-None" or not items then return end

	for _, item in pairs(items) do
		item.description = nil
	end

	MySQL.insert('INSERT INTO trunkitems (plate, items) VALUES (:plate, :items) ON DUPLICATE KEY UPDATE items = :items', {
		['plate'] = plate,
		['items'] = json.encode(items)
	})

	Trunks[plate].isOpen = false
end

local function AddToTrunk(plate, slot, otherslot, itemName, amount, info, created)
	amount = tonumber(amount) or 1
	local ItemData = QBCore.Shared.Items[itemName]

	if not ItemData.unique then
		if Trunks[plate].items[slot] and Trunks[plate].items[slot].name == itemName then
			Trunks[plate].items[slot].amount = Trunks[plate].items[slot].amount + amount
		else
			local itemInfo = QBCore.Shared.Items[itemName:lower()]
			Trunks[plate].items[slot] = {
				name = itemInfo["name"],
				amount = amount,
				info = info or "",
				label = itemInfo["label"],
				description = itemInfo["description"] or "",
				weight = itemInfo["weight"],
				type = itemInfo["type"],
				unique = itemInfo["unique"],
				useable = itemInfo["useable"],
				image = itemInfo["image"],
                created = created,
				slot = slot,
			}
		end
	else
		if Trunks[plate].items[slot] and Trunks[plate].items[slot].name == itemName then
			local itemInfo = QBCore.Shared.Items[itemName:lower()]
			Trunks[plate].items[otherslot] = {
				name = itemInfo["name"],
				amount = amount,
				info = info or "",
				label = itemInfo["label"],
				description = itemInfo["description"] or "",
				weight = itemInfo["weight"],
				type = itemInfo["type"],
				unique = itemInfo["unique"],
				useable = itemInfo["useable"],
				image = itemInfo["image"],
				slot = otherslot,
			}
		else
			local itemInfo = QBCore.Shared.Items[itemName:lower()]
			Trunks[plate].items[slot] = {
				name = itemInfo["name"],
				amount = amount,
				info = info or "",
				label = itemInfo["label"],
				description = itemInfo["description"] or "",
				weight = itemInfo["weight"],
				type = itemInfo["type"],
				unique = itemInfo["unique"],
				useable = itemInfo["useable"],
				image = itemInfo["image"],
				slot = slot,
			}
		end
	end
end

function RemoveFromTrunk(plate, slot, itemName, amount)
	amount = tonumber(amount) or 1
	if Trunks[plate].items[slot] and Trunks[plate].items[slot].name == itemName then
		if Trunks[plate].items[slot].amount > amount then
			Trunks[plate].items[slot].amount = Trunks[plate].items[slot].amount - amount
		else
			Trunks[plate].items[slot] = nil
            if next(Trunks[plate].items) == nil then
				Trunks[plate].items = {}
			end
		end
	else
		Trunks[plate].items[slot] = nil
		if Trunks[plate].items == nil then
			Trunks[plate].items[slot] = nil
		end
	end
end

function GetOwnedVehicleGloveboxItems(plate)
	local items = {}
	local result = MySQL.scalar.await('SELECT items FROM gloveboxitems WHERE plate = ?', {plate})
	if not result then return items end

	local gloveboxItems = json.decode(result)
	if not gloveboxItems then return items end

	for _, item in pairs(gloveboxItems) do
		local itemInfo = QBCore.Shared.Items[item.name:lower()]
		if itemInfo then
			items[item.slot] = {
				name = itemInfo["name"],
				amount = tonumber(item.amount),
				info = item.info or "",
				label = itemInfo["label"],
				description = itemInfo["description"] or "",
				weight = itemInfo["weight"],
				type = itemInfo["type"],
				unique = itemInfo["unique"],
				useable = itemInfo["useable"],
				image = itemInfo["image"],
				slot = item.slot,
			}
		end
	end
	return items
end

function SaveOwnedGloveboxItems(plate, items)
	if Gloveboxes[plate].label == "Glovebox-None" or not items then return end

	for _, item in pairs(items) do
		item.description = nil
	end

	MySQL.insert('INSERT INTO gloveboxitems (plate, items) VALUES (:plate, :items) ON DUPLICATE KEY UPDATE items = :items', {
		['plate'] = plate,
		['items'] = json.encode(items)
	})

	Gloveboxes[plate].isOpen = false
end

function AddToGlovebox(plate, slot, otherslot, itemName, amount, info, created)
	amount = tonumber(amount) or 1
	local ItemData = QBCore.Shared.Items[itemName]

	if not ItemData.unique then
		if Gloveboxes[plate].items[slot] and Gloveboxes[plate].items[slot].name == itemName then
			Gloveboxes[plate].items[slot].amount = Gloveboxes[plate].items[slot].amount + amount
		else
			local itemInfo = QBCore.Shared.Items[itemName:lower()]
			Gloveboxes[plate].items[slot] = {
				name = itemInfo["name"],
				amount = amount,
				info = info or "",
				label = itemInfo["label"],
				description = itemInfo["description"] or "",
				weight = itemInfo["weight"],
				type = itemInfo["type"],
				unique = itemInfo["unique"],
				useable = itemInfo["useable"],
				image = itemInfo["image"],
                created = created,
				slot = slot,
			}
		end
	else
		if Gloveboxes[plate].items[slot] and Gloveboxes[plate].items[slot].name == itemName then
			local itemInfo = QBCore.Shared.Items[itemName:lower()]
			Gloveboxes[plate].items[otherslot] = {
				name = itemInfo["name"],
				amount = amount,
				info = info or "",
				label = itemInfo["label"],
				description = itemInfo["description"] or "",
				weight = itemInfo["weight"],
				type = itemInfo["type"],
				unique = itemInfo["unique"],
				useable = itemInfo["useable"],
				image = itemInfo["image"],
				slot = otherslot,
			}
		else
			local itemInfo = QBCore.Shared.Items[itemName:lower()]
			Gloveboxes[plate].items[slot] = {
				name = itemInfo["name"],
				amount = amount,
				info = info or "",
				label = itemInfo["label"],
				description = itemInfo["description"] or "",
				weight = itemInfo["weight"],
				type = itemInfo["type"],
				unique = itemInfo["unique"],
				useable = itemInfo["useable"],
				image = itemInfo["image"],
				slot = slot,
			}
		end
	end
end

local function RemoveFromGlovebox(plate, slot, itemName, amount)
	amount = tonumber(amount) or 1
	if Gloveboxes[plate].items[slot] and Gloveboxes[plate].items[slot].name == itemName then
		if Gloveboxes[plate].items[slot].amount > amount then
			Gloveboxes[plate].items[slot].amount = Gloveboxes[plate].items[slot].amount - amount
		else
			Gloveboxes[plate].items[slot] = nil
            if next(Gloveboxes[plate].items) == nil then
				Gloveboxes[plate].items = {}
			end
		end
	else
		Gloveboxes[plate].items[slot] = nil
		if Gloveboxes[plate].items == nil then
			Gloveboxes[plate].items[slot] = nil
		end
	end
end

local function AddToDrop(dropId, slot, itemName, amount, info)
	amount = tonumber(amount) or 1
	if not Drops[dropId] then
		print("^1[ERROR] AddToDrop: Drop does not exist:", dropId)
		return false
	end
	if not Drops[dropId].items then
		Drops[dropId].items = {}
	end
	Drops[dropId].createdTime = os.time()
	if Drops[dropId].items[slot] and Drops[dropId].items[slot].name == itemName then
		Drops[dropId].items[slot].amount = Drops[dropId].items[slot].amount + amount
	else
		local itemInfo = QBCore.Shared.Items[itemName:lower()]
		if not itemInfo then
			print("^1[ERROR] AddToDrop: Item info not found:", itemName)
			return false
		end
		Drops[dropId].items[slot] = {
			name = itemInfo["name"],
			amount = amount,
			info = info or "",
			label = itemInfo["label"],
			description = itemInfo["description"] or "",
			weight = itemInfo["weight"],
			type = itemInfo["type"],
			unique = itemInfo["unique"],
			useable = itemInfo["useable"],
			image = itemInfo["image"],
			slot = slot,
			id = dropId,
		}
	end
	OnDropUpdate(dropId, Drops[dropId])
	return true
end

local function RemoveFromDrop(dropId, slot, itemName, amount)
	amount = tonumber(amount) or 1
	if not Drops[dropId] then
		print("^1[ERROR] RemoveFromDrop: Drop does not exist:", dropId)
		return false
	end
	if not Drops[dropId].items then
		print("^1[ERROR] RemoveFromDrop: Drop has no items:", dropId)
		return false
	end
	Drops[dropId].createdTime = os.time()
	if Drops[dropId].items[slot] and Drops[dropId].items[slot].name == itemName then
		if Drops[dropId].items[slot].amount > amount then
			Drops[dropId].items[slot].amount = Drops[dropId].items[slot].amount - amount
		else
			Drops[dropId].items[slot] = nil
		end
		OnDropUpdate(dropId, Drops[dropId])
		return true
	else
		print("^1[ERROR] RemoveFromDrop: Item not found in slot:", slot, "itemName:", itemName)
		return false
	end
end

local function CreateDropId()
	if Drops then
		local id = math.random(10000, 99999)
		local dropid = id
		while Drops[dropid] do
			id = math.random(10000, 99999)
			dropid = id
		end
		return dropid
	else
		local id = math.random(10000, 99999)
		local dropid = id
		return dropid
	end
end

local function CreateNewDrop(source, fromSlot, toSlot, itemAmount, itemData, alreadyRemoved)
	itemAmount = tonumber(itemAmount) or 1
	local Player = QBCore.Functions.GetPlayer(source)
	
	if not itemData then
		itemData = GetItemBySlot(source, fromSlot)
	end

	print("^2[DEBUG SERVER] CreateNewDrop called - source:", source, "fromSlot:", fromSlot, "toSlot:", toSlot, "amount:", itemAmount, "alreadyRemoved:", alreadyRemoved or false)

	if not itemData then 
		print("^1[DEBUG SERVER] No item data found!")
		return false
	end

	print("^2[DEBUG SERVER] Item data:", itemData.name, "amount:", itemData.amount)

	local coords = GetEntityCoords(GetPlayerPed(source))
	print("^2[DEBUG SERVER] Player coords:", coords)
	
	local itemRemoved = alreadyRemoved or false
	if not alreadyRemoved then
		if RemoveItem(source, itemData.name, itemAmount, itemData.slot) then
			itemRemoved = true
			TriggerClientEvent("inventory:client:CheckWeapon", source, itemData.name)
		else
			print("^1[DEBUG SERVER] Failed to remove item!")
			QBCore.Functions.Notify(source, Lang:t("notify.missitem"), "error")
			return false
		end
	end
	
	if itemRemoved then
		local itemInfo = QBCore.Shared.Items[itemData.name:lower()]
		if not itemInfo then
			print("^1[DEBUG SERVER] Item info not found:", itemData.name)
			return false
		end
		
		local dropId = CreateDropId()
		
		print("^2[DEBUG SERVER] Drop ID created:", dropId)
		
		Drops[dropId] = {}
		Drops[dropId].coords = coords
		Drops[dropId].createdTime = os.time()

		Drops[dropId].items = {}

		Drops[dropId].items[toSlot] = {
			name = itemInfo["name"],
			amount = itemAmount,
			info = itemData.info or "",
			label = itemInfo["label"],
			description = itemInfo["description"] or "",
			weight = itemInfo["weight"],
			type = itemInfo["type"],
			unique = itemInfo["unique"],
			useable = itemInfo["useable"],
			image = itemInfo["image"],
			slot = toSlot,
			id = dropId,
		}
		TriggerEvent("qb-log:server:CreateLog", "drop", "New Item Drop", "red", "**".. GetPlayerName(source) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..source.."*) dropped new item; name: **"..itemData.name.."**, amount: **" .. itemAmount .. "**")
		
		print("^2[DEBUG SERVER] Triggering drop animation for player:", source)
		TriggerClientEvent("inventory:client:DropItemAnim", source)
		
		print("^2[DEBUG SERVER] Broadcasting AddDropItem to all clients - dropId:", dropId, "coords:", coords)
		TriggerClientEvent("inventory:client:AddDropItem", -1, dropId, source, coords)
		
		if itemData.name:lower() == "radio" then
			TriggerClientEvent('Radio.Set', source, false)
		end
		
		OnDropUpdate(dropId, Drops[dropId])
		
		return true
	else
		print("^1[DEBUG SERVER] Item was not removed!")
		return false
	end
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
	QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, "AddItem", function(item, amount, slot, info)
		return AddItem(Player.PlayerData.source, item, amount, slot, info)
	end)

	QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, "RemoveItem", function(item, amount, slot)
		return RemoveItem(Player.PlayerData.source, item, amount, slot)
	end)

	QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, "GetItemBySlot", function(slot)
		return GetItemBySlot(Player.PlayerData.source, slot)
	end)

	QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, "GetItemByName", function(item)
		return GetItemByName(Player.PlayerData.source, item)
	end)

	QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, "GetItemsByName", function(item)
		return GetItemsByName(Player.PlayerData.source, item)
	end)

	QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, "ClearInventory", function(filterItems)
		ClearInventory(Player.PlayerData.source, filterItems)
	end)

	QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, "SetInventory", function(items)
		SetInventory(Player.PlayerData.source, items)
	end)
end)

AddEventHandler('onResourceStart', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then return end
	local Players = QBCore.Functions.GetQBPlayers()
	for k in pairs(Players) do
		QBCore.Functions.AddPlayerMethod(k, "AddItem", function(item, amount, slot, info)
			return AddItem(k, item, amount, slot, info)
		end)

		QBCore.Functions.AddPlayerMethod(k, "RemoveItem", function(item, amount, slot)
			return RemoveItem(k, item, amount, slot)
		end)

		QBCore.Functions.AddPlayerMethod(k, "GetItemBySlot", function(slot)
			return GetItemBySlot(k, slot)
		end)

		QBCore.Functions.AddPlayerMethod(k, "GetItemByName", function(item)
			return GetItemByName(k, item)
		end)

		QBCore.Functions.AddPlayerMethod(k, "GetItemsByName", function(item)
			return GetItemsByName(k, item)
		end)

		QBCore.Functions.AddPlayerMethod(k, "ClearInventory", function(filterItems)
			ClearInventory(k, filterItems)
		end)

		QBCore.Functions.AddPlayerMethod(k, "SetInventory", function(items)
			SetInventory(k, items)
		end)
	end
end)

RegisterNetEvent('QBCore:Server:UpdateObject', function()
    if source ~= '' then return end
    QBCore = exports['qb-core']:GetCoreObject()
end)

RegisterNetEvent('inventory:server:addTrunkItems', function(plate, items)
	Trunks[plate] = {}
	Trunks[plate].items = items
end)

RegisterNetEvent('inventory:server:combineItem', function(item, fromItem, toItem)
	local src = source

	if fromItem == nil  then return end
	if toItem == nil then return end

	fromItem = GetItemByName(src, fromItem)
	toItem = GetItemByName(src, toItem)

	if fromItem == nil  then return end
	if toItem == nil then return end

	local recipe = QBCore.Shared.Items[toItem.name].combinable

	if recipe and recipe.reward ~= item then return end
	if not recipeContains(recipe, fromItem) then return end

	TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], 'add')
	AddItem(src, item, 1)
	RemoveItem(src, fromItem.name, 1)
	RemoveItem(src, toItem.name, 1)
end)

RegisterNetEvent('inventory:server:CraftItems', function(itemName, itemCosts, amount, toSlot, points)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)

	amount = tonumber(amount)

	if not itemName or not itemCosts then return end

	for k, v in pairs(itemCosts) do
		RemoveItem(src, k, (v*amount))
	end
	AddItem(src, itemName, amount, toSlot)
	Player.Functions.SetMetaData("craftingrep", Player.PlayerData.metadata["craftingrep"] + (points * amount))
	TriggerClientEvent("inventory:client:UpdatePlayerInventory", src, false)
end)

RegisterNetEvent('inventory:server:CraftAttachment', function(itemName, itemCosts, amount, toSlot, points)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)

	amount = tonumber(amount)

	if not itemName or not itemCosts then return end

	for k, v in pairs(itemCosts) do
		RemoveItem(src, k, (v*amount))
	end
	AddItem(src, itemName, amount, toSlot)
	Player.Functions.SetMetaData("attachmentcraftingrep", Player.PlayerData.metadata["attachmentcraftingrep"] + (points * amount))
	TriggerClientEvent("inventory:client:UpdatePlayerInventory", src, false)
end)

RegisterNetEvent('inventory:server:SetIsOpenState', function(IsOpen, type, id)
	if IsOpen then return end
	if type == "stash" then
		Stashes[id].isOpen = false
	elseif type == "trunk" then
		Trunks[id].isOpen = false
	elseif type == "glovebox" then
		Gloveboxes[id].isOpen = false
	elseif type == "drop" then
		Drops[id].isOpen = false
	end
end)

RegisterNetEvent('inventory:server:OpenInventory', function(name, id, other)
	local src = source
	local ply = Player(src)
	local Player = QBCore.Functions.GetPlayer(src)
	if not ply.state.inv_busy then
		if name and id then
			local secondInv = {}
			if name == "stash" then
				local isBinStash = string.sub(id, 1, 10) == "PlayerBin_"
				
				if isBinStash then
					print("^3[DEBUG] Opening PlayerBin stash:", id, "for player:", src)
					if Stashes[id] then
						print("^3[DEBUG] Clearing existing PlayerBin state")
						Stashes[id].isOpen = false
					end
				end
				
				if Stashes[id] then
					if Stashes[id].isOpen and not isBinStash then
						local Target = QBCore.Functions.GetPlayer(Stashes[id].isOpen)
						if Target then
							TriggerClientEvent('inventory:client:CheckOpenState', Stashes[id].isOpen, name, id, Stashes[id].label)
						else
							Stashes[id].isOpen = false
						end
					end
				end
				
				local maxweight = 1000000
				local slots = 50
				if other then
					maxweight = other.maxweight or 1000000
					slots = other.slots or 50
				end
				secondInv.name = "stash-"..id
				secondInv.label = isBinStash and "DROP ZONE" or "Stash-"..id
				secondInv.maxweight = maxweight
				secondInv.inventory = {}
				secondInv.slots = slots
				if Stashes[id] and Stashes[id].isOpen and not isBinStash then
					secondInv.name = "none-inv"
					secondInv.label = "Stash-None"
					secondInv.maxweight = 1000000
					secondInv.inventory = {}
					secondInv.slots = 0
				else
					if isBinStash then
						Stashes[id] = {}
						Stashes[id].items = {}
						Stashes[id].isOpen = src
						Stashes[id].label = secondInv.label
						secondInv.inventory = {}
						print("^2[DEBUG] PlayerBin initialized as empty drop zone")
					else
						local stashItems = GetStashItems(id)
						if next(stashItems) then
							secondInv.inventory = stashItems
							Stashes[id] = {}
							Stashes[id].items = stashItems
							Stashes[id].isOpen = src
							Stashes[id].label = secondInv.label
						else
							Stashes[id] = {}
							Stashes[id].items = {}
							Stashes[id].isOpen = src
							Stashes[id].label = secondInv.label
						end
					end
				end
			elseif name == "trunk" then
				if Trunks[id] then
					if Trunks[id].isOpen then
						local Target = QBCore.Functions.GetPlayer(Trunks[id].isOpen)
						if Target then
							TriggerClientEvent('inventory:client:CheckOpenState', Trunks[id].isOpen, name, id, Trunks[id].label)
						else
							Trunks[id].isOpen = false
						end
					end
				end
				secondInv.name = "trunk-"..id
				secondInv.label = "Trunk-"..id
				secondInv.maxweight = other.maxweight or 60000
				secondInv.inventory = {}
				secondInv.slots = other.slots or 50
				if (Trunks[id] and Trunks[id].isOpen) or (QBCore.Shared.SplitStr(id, "POL")[2] and Player.PlayerData.job.name ~= "police") then
					secondInv.name = "none-inv"
					secondInv.label = "Trunk-None"
					secondInv.maxweight = other.maxweight or 60000
					secondInv.inventory = {}
					secondInv.slots = 0
				else
					if id then
						local ownedItems = GetOwnedVehicleItems(id)
						if IsVehicleOwned(id) and next(ownedItems) then
							secondInv.inventory = ownedItems
							Trunks[id] = {}
							Trunks[id].items = ownedItems
							Trunks[id].isOpen = src
							Trunks[id].label = secondInv.label
						elseif Trunks[id] and not Trunks[id].isOpen then
							secondInv.inventory = Trunks[id].items
							Trunks[id].isOpen = src
							Trunks[id].label = secondInv.label
						else
							Trunks[id] = {}
							Trunks[id].items = {}
							Trunks[id].isOpen = src
							Trunks[id].label = secondInv.label
						end
					end
				end
			elseif name == "glovebox" then
				if Gloveboxes[id] then
					if Gloveboxes[id].isOpen then
						local Target = QBCore.Functions.GetPlayer(Gloveboxes[id].isOpen)
						if Target then
							TriggerClientEvent('inventory:client:CheckOpenState', Gloveboxes[id].isOpen, name, id, Gloveboxes[id].label)
						else
							Gloveboxes[id].isOpen = false
						end
					end
				end
				secondInv.name = "glovebox-"..id
				secondInv.label = "Glovebox-"..id
				secondInv.maxweight = 10000
				secondInv.inventory = {}
				secondInv.slots = 5
				if Gloveboxes[id] and Gloveboxes[id].isOpen then
					secondInv.name = "none-inv"
					secondInv.label = "Glovebox-None"
					secondInv.maxweight = 10000
					secondInv.inventory = {}
					secondInv.slots = 0
				else
					local ownedItems = GetOwnedVehicleGloveboxItems(id)
					if Gloveboxes[id] and not Gloveboxes[id].isOpen then
						secondInv.inventory = Gloveboxes[id].items
						Gloveboxes[id].isOpen = src
						Gloveboxes[id].label = secondInv.label
					elseif IsVehicleOwned(id) and next(ownedItems) then
						secondInv.inventory = ownedItems
						Gloveboxes[id] = {}
						Gloveboxes[id].items = ownedItems
						Gloveboxes[id].isOpen = src
						Gloveboxes[id].label = secondInv.label
					else
						Gloveboxes[id] = {}
						Gloveboxes[id].items = {}
						Gloveboxes[id].isOpen = src
						Gloveboxes[id].label = secondInv.label
					end
				end
			elseif name == "shop" then
				secondInv.name = "itemshop-"..id
				secondInv.label = other.label
				secondInv.maxweight = 900000
				secondInv.inventory = SetupShopItems(other.items)
				ShopItems[id] = {}
				ShopItems[id].items = other.items
				secondInv.slots = #other.items
			elseif name == "traphouse" then
				secondInv.name = "traphouse-"..id
				secondInv.label = other.label
				secondInv.maxweight = 900000
				secondInv.inventory = other.items
				secondInv.slots = other.slots
			elseif name == "crafting" then
				secondInv.name = "crafting"
				secondInv.label = other.label
				secondInv.maxweight = 900000
				secondInv.inventory = other.items
				secondInv.slots = #other.items
			elseif name == "attachment_crafting" then
				secondInv.name = "attachment_crafting"
				secondInv.label = other.label
				secondInv.maxweight = 900000
				secondInv.inventory = other.items
				secondInv.slots = #other.items
			elseif name == "otherplayer" then
				local OtherPlayer = QBCore.Functions.GetPlayer(tonumber(id))
				if OtherPlayer then
					secondInv.name = "otherplayer-"..id
					secondInv.label = "Player-"..id
					secondInv.maxweight = Config.MaxInventoryWeight
					secondInv.inventory = OtherPlayer.PlayerData.items
					if Player.PlayerData.job.name == "police" and Player.PlayerData.job.onduty then
						local PoliceLocation = vec3(454.42449,-991.1528,27.511968)
						local MyPed = GetPlayerPed(Player.PlayerData.source)
						local MyCoords = GetEntityCoords(MyPed)
						if #(MyCoords - PoliceLocation) < 20 then 
							secondInv.slots = Config.MaxInventorySlots
						else
							secondInv.slots = Config.MaxInventorySlots - 1
						end
					else
						secondInv.slots = Config.MaxInventorySlots - 1
					end
					Wait(250)
				end
			else
				if Drops[id] then
					if Drops[id].isOpen then
						local Target = QBCore.Functions.GetPlayer(Drops[id].isOpen)
						if Target then
							TriggerClientEvent('inventory:client:CheckOpenState', Drops[id].isOpen, name, id, Drops[id].label)
						else
							Drops[id].isOpen = false
						end
					end
				end
				if Drops[id] and not Drops[id].isOpen then
					secondInv.coords = Drops[id].coords
					secondInv.name = id
					secondInv.label = "Dropped-"..tostring(id)
					secondInv.maxweight = 100000
					secondInv.inventory = Drops[id].items
					secondInv.slots = 30
					Drops[id].isOpen = src
					Drops[id].label = secondInv.label
					Drops[id].createdTime = os.time()
				else
					secondInv.name = "none-inv"
					secondInv.label = "Dropped-None"
					secondInv.maxweight = 100000
					secondInv.inventory = {}
					secondInv.slots = 0
				end
			end
			TriggerClientEvent("qb-inventory:client:closeinv", id)
			TriggerClientEvent("inventory:client:OpenInventory", src, {}, Player.PlayerData.items, secondInv, id)
		else
			TriggerClientEvent("inventory:client:OpenInventory", src, {}, Player.PlayerData.items)
		end
	else
		QBCore.Functions.Notify(src, Lang:t("notify.noaccess"), 'error')
	end
end)

RegisterNetEvent('inventory:server:SaveInventory', function(type, id)
	if not id then return end 
	
	local isBinStash = type == "stash" and string.sub(id, 1, 10) == "PlayerBin_"
	
	if type == "trunk" then
		if IsVehicleOwned(id) then
			SaveOwnedVehicleItems(id, Trunks[id].items)
		else
			Trunks[id].isOpen = false
		end
	elseif type == "glovebox" then
		if (IsVehicleOwned(id)) then
			SaveOwnedGloveboxItems(id, Gloveboxes[id].items)
		else
			if not Gloveboxes[id] then return end 
			Gloveboxes[id].isOpen = false
		end
	elseif type == "stash" then
		if isBinStash then
			print("^3[DEBUG] Closing PlayerBin, clearing state:", id)
			if Stashes[id] then
				Stashes[id].isOpen = false
				Stashes[id].items = {}
			end
		else
			SaveStashItems(id, Stashes[id].items)
		end
	elseif type == "drop" then
		if Drops[id] then
			Drops[id].isOpen = false
			if Drops[id].items == nil or next(Drops[id].items) == nil then
				TriggerClientEvent('qb-inventory:updateDropVisualData', -1, id, Drops[id].coords, {})
				Drops[id] = nil
				TriggerClientEvent("inventory:client:RemoveDropItem", -1, id)
			end
		end
	end
end)

RegisterNetEvent('inventory:server:UseItemSlot', function(slot)
	local src = source
	local itemData = GetItemBySlot(src, slot)
	if not itemData then return end
	local itemInfo = QBCore.Shared.Items[itemData.name]
	if itemData.type == "weapon" then
		TriggerClientEvent("inventory:client:UseWeapon", src, itemData, itemData.info.quality and itemData.info.quality > 0)
		TriggerClientEvent('inventory:client:ItemBox', src, itemInfo, "use")
	elseif itemData.useable then
		UseItem(itemData.name, src, itemData)
		TriggerClientEvent('inventory:client:ItemBox', src, itemInfo, "use")
	end
end)

RegisterNetEvent('inventory:server:UseItem', function(inventory, item)
	local src = source
	if inventory ~= "player" and inventory ~= "hotbar" then return end
	local itemData = GetItemBySlot(src, item.slot)
	if not itemData then return end
	local itemInfo = QBCore.Shared.Items[itemData.name]
	if itemData.type == "weapon" then
		TriggerClientEvent("inventory:client:UseWeapon", src, itemData, itemData.info.quality and itemData.info.quality > 0)
		TriggerClientEvent('inventory:client:ItemBox', src, itemInfo, "use")
	else
		UseItem(itemData.name, src, itemData)
		TriggerClientEvent('inventory:client:ItemBox', src, itemInfo, "use")
	end
end)

RegisterNetEvent('inventory:server:SetInventoryData', function(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount)
	if fromAmount then 
		fromAmount = math.ceil(fromAmount)
	end
	if toAmount then 
		toAmount = math.ceil(toAmount)
	end

	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	fromSlot = tonumber(fromSlot)
	toSlot = tonumber(toSlot)

	if (fromInventory == "player" or fromInventory == "hotbar") and (QBCore.Shared.SplitStr(toInventory, "-")[1] == "itemshop" or toInventory == "crafting") then
		return
	end

	if fromInventory == "player" or fromInventory == "hotbar" then
		local fromItemData = GetItemBySlot(src, fromSlot)
		fromAmount = tonumber(fromAmount) or fromItemData.amount
		if fromItemData and fromItemData.amount >= fromAmount then
			if toInventory == "player" or toInventory == "hotbar" then
				local toItemData = GetItemBySlot(src, toSlot)
				RemoveItem(src, fromItemData.name, fromAmount, fromSlot)
				TriggerClientEvent("inventory:client:CheckWeapon", src, fromItemData.name)
				if toItemData then
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						RemoveItem(src, toItemData.name, toAmount, toSlot)
						AddItem(src, toItemData.name, toAmount, fromSlot, toItemData.info)
					end
				end
				AddItem(src, fromItemData.name, fromAmount, toSlot, fromItemData.info, fromItemData.created)
			elseif QBCore.Shared.SplitStr(toInventory, "-")[1] == "otherplayer" then
				local playerId = tonumber(QBCore.Shared.SplitStr(toInventory, "-")[2])
				local OtherPlayer = QBCore.Functions.GetPlayer(playerId)
				if not OtherPlayer then 
					TriggerEvent('qb-log:server:CreateLog', 'fuckers', 'Fuckers Founded', 'red', GetPlayerName(src) .. ' Have Been Marked As Cheater [ to OtherPlayer]', true)
					DropPlayer(src, 'nah nah nah next time you will be banned')
					return
				end
				local toItemData = OtherPlayer.PlayerData.items[toSlot]
				RemoveItem(src, fromItemData.name, fromAmount, fromSlot)
				TriggerClientEvent('inventory:client:ItemBox',src, QBCore.Shared.Items[fromItemData.name], "remove", fromAmount)
				TriggerClientEvent("inventory:client:CheckWeapon", src, fromItemData.name)
				if toItemData then
					local itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						RemoveItem(playerId, itemInfo["name"], toAmount, fromSlot)
						AddItem(src, toItemData.name, toAmount, fromSlot, toItemData.info, toItemData.created)
						TriggerEvent("qb-log:server:CreateLog", "robbing", "Swapped Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | *"..src.."*) swapped item; name: **"..itemInfo["name"].."**, amount: **" .. toAmount .. "** with name: **" .. fromItemData.name .. "**, amount: **" .. fromAmount.. "** with player: **".. GetPlayerName(OtherPlayer.PlayerData.source) .. "** (citizenid: *"..OtherPlayer.PlayerData.citizenid.."* | id: *"..OtherPlayer.PlayerData.source.."*)")
					end
				else
					local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
					TriggerEvent("qb-log:server:CreateLog", "robbing", "Dropped Item", "red", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | *"..src.."*) dropped new item; name: **"..itemInfo["name"].."**, amount: **" .. fromAmount .. "** to player: **".. GetPlayerName(OtherPlayer.PlayerData.source) .. "** (citizenid: *"..OtherPlayer.PlayerData.citizenid.."* | id: *"..OtherPlayer.PlayerData.source.."*)")
				end
				local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
				AddItem(playerId, itemInfo["name"], fromAmount, toSlot, fromItemData.info, fromItemData.created)
				TriggerClientEvent('inventory:client:ItemBox',playerId, QBCore.Shared.Items[itemInfo["name"]], "add", fromAmount)
			elseif QBCore.Shared.SplitStr(toInventory, "-")[1] == "trunk" then
				local plate = QBCore.Shared.SplitStr(toInventory, "-")[2]
				local toItemData = Trunks[plate].items[toSlot]
				RemoveItem(src, fromItemData.name, fromAmount, fromSlot)
				TriggerClientEvent("inventory:client:CheckWeapon", src, fromItemData.name)
				if toItemData then
					local itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						RemoveFromTrunk(plate, fromSlot, itemInfo["name"], toAmount)
						AddItem(src, toItemData.name, toAmount, fromSlot, toItemData.info, toItemData.created)
						TriggerEvent("qb-log:server:CreateLog", "trunk", "Swapped Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) swapped item; name: **"..itemInfo["name"].."**, amount: **" .. toAmount .. "** with name: **" .. fromItemData.name .. "**, amount: **" .. fromAmount .. "** - plate: *" .. plate .. "*")
					end
				else
					local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
					TriggerEvent("qb-log:server:CreateLog", "trunk", "Dropped Item", "red", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) dropped new item; name: **"..itemInfo["name"].."**, amount: **" .. fromAmount .. "** - plate: *" .. plate .. "*")
				end
				local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
				AddToTrunk(plate, toSlot, fromSlot, itemInfo["name"], fromAmount, fromItemData.info, fromItemData.created)
			elseif QBCore.Shared.SplitStr(toInventory, "-")[1] == "glovebox" then
				local plate = QBCore.Shared.SplitStr(toInventory, "-")[2]
				local toItemData = Gloveboxes[plate].items[toSlot]
				RemoveItem(src, fromItemData.name, fromAmount, fromSlot)
				TriggerClientEvent("inventory:client:CheckWeapon", src, fromItemData.name)
				if toItemData then
					local itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						RemoveFromGlovebox(plate, fromSlot, itemInfo["name"], toAmount)
						AddItem(src, toItemData.name, toAmount, fromSlot, toItemData.info, toItemData.created)
						TriggerEvent("qb-log:server:CreateLog", "glovebox", "Swapped Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) swapped item; name: **"..itemInfo["name"].."**, amount: **" .. toAmount .. "** with name: **" .. fromItemData.name .. "**, amount: **" .. fromAmount .. "** - plate: *" .. plate .. "*")
					end
				else
					local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
					TriggerEvent("qb-log:server:CreateLog", "glovebox", "Dropped Item", "red", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) dropped new item; name: **"..itemInfo["name"].."**, amount: **" .. fromAmount .. "** - plate: *" .. plate .. "*")
				end
				local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
				AddToGlovebox(plate, toSlot, fromSlot, itemInfo["name"], fromAmount, fromItemData.info, fromItemData.created)
			elseif QBCore.Shared.SplitStr(toInventory, "-")[1] == "stash" then
				local stashId = QBCore.Shared.SplitStr(toInventory, "-")[2]
				
				print("^3[DEBUG] Stash detected! StashId:", stashId)
				print("^3[DEBUG] Checking if starts with PlayerBin_:", string.sub(stashId, 1, 10))
				
				if string.sub(stashId, 1, 10) == "PlayerBin_" then
					print("^2[DEBUG] BIN DETECTED! Calling CreateNewDrop")
					if RemoveItem(src, fromItemData.name, fromAmount, fromSlot) then
						TriggerClientEvent("inventory:client:CheckWeapon", src, fromItemData.name)
						if CreateNewDrop(src, fromSlot, toSlot, fromAmount, fromItemData, true) then
							TriggerEvent("qb-log:server:CreateLog", "drop", "Bin Drop", "red", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) dropped item via bin; name: **"..fromItemData.name.."**, amount: **" .. fromAmount .. "**")
						else
							AddItem(src, fromItemData.name, fromAmount, fromSlot, fromItemData.info, fromItemData.created)
							QBCore.Functions.Notify(src, "Failed to create drop", "error")
						end
					else
						QBCore.Functions.Notify(src, Lang:t("notify.missitem"), "error")
					end
				else
					print("^1[DEBUG] NOT a bin - regular stash behavior")
					local toItemData = Stashes[stashId] and Stashes[stashId].items and Stashes[stashId].items[toSlot] or nil
					RemoveItem(src, fromItemData.name, fromAmount, fromSlot)
					TriggerClientEvent("inventory:client:CheckWeapon", src, fromItemData.name)
					if toItemData then
						local itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
						toAmount = tonumber(toAmount) or toItemData.amount
						if toItemData.name ~= fromItemData.name then
							RemoveFromStash(stashId, toSlot, itemInfo["name"], toAmount)
							AddItem(src, toItemData.name, toAmount, fromSlot, toItemData.info, toItemData.created)
							TriggerEvent("qb-log:server:CreateLog", "stash", "Swapped Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) swapped item; name: **"..itemInfo["name"].."**, amount: **" .. toAmount .. "** with name: **" .. fromItemData.name .. "**, amount: **" .. fromAmount .. "** - stash: *" .. stashId .. "*")
						end
					else
						local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
						TriggerEvent("qb-log:server:CreateLog", "stash", "Dropped Item", "red", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) dropped new item; name: **"..itemInfo["name"].."**, amount: **" .. fromAmount .. "** - stash: *" .. stashId .. "*")
					end
					local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
					AddToStash(stashId, toSlot, fromSlot, itemInfo["name"], fromAmount, fromItemData.info, fromItemData.created)
				end
			elseif QBCore.Shared.SplitStr(toInventory, "-")[1] == "traphouse" then
				local traphouseId = QBCore.Shared.SplitStr(toInventory, "-")[2]
				local toItemData = exports['qb-traphouse']:GetInventoryData(traphouseId, toSlot)
				local IsItemValid = exports['qb-traphouse']:CanItemBeSaled(fromItemData.name:lower())
				if IsItemValid then
					RemoveItem(src, fromItemData.name, fromAmount, fromSlot)
					TriggerClientEvent("inventory:client:CheckWeapon", src, fromItemData.name)
					if toItemData  then
						local itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
						toAmount = tonumber(toAmount) or toItemData.amount
						if toItemData.name ~= fromItemData.name then
							exports['qb-traphouse']:RemoveHouseItem(traphouseId, fromSlot, itemInfo["name"], toAmount)
							AddItem(src, toItemData.name, toAmount, fromSlot, toItemData.info, 	toItemData.created)
							TriggerEvent("qb-log:server:CreateLog", "traphouse", "Swapped Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) swapped item; name: **"..itemInfo["name"].."**, amount: **" .. toAmount .. "** with name: **" .. fromItemData.name .. "**, amount: **" .. fromAmount .. "** - traphouse: *" .. traphouseId .. "*")
						end
					else
						local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
						TriggerEvent("qb-log:server:CreateLog", "traphouse", "Dropped Item", "red", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) dropped new item; name: **"..itemInfo["name"].."**, amount: **" .. fromAmount .. "** - traphouse: *" .. traphouseId .. "*")
					end
					local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
					exports['qb-traphouse']:AddHouseItem(traphouseId, toSlot, itemInfo["name"], fromAmount, fromItemData.info, src)
				else
					QBCore.Functions.Notify(src, Lang:t("notify.nosell"), 'error')
				end
			else
				TriggerEvent('qb-log:server:CreateLog', 'fuckers', 'Fuckers Founded', 'red', GetPlayerName(src) .. ' Have Been Marked As Cheater [ Drop Item ]', true)
				DropPlayer(src, 'Hmmmm nah nah nah try again noob')
			end
		else
			QBCore.Functions.Notify(src, Lang:t("notify.missitem"), "error")
		end
	elseif QBCore.Shared.SplitStr(fromInventory, "-")[1] == "otherplayer" then
		local playerId = tonumber(QBCore.Shared.SplitStr(fromInventory, "-")[2])
		local OtherPlayer = QBCore.Functions.GetPlayer(playerId)
		if not OtherPlayer then 
			TriggerEvent('qb-log:server:CreateLog', 'fuckers', 'Fuckers Founded', 'red', GetPlayerName(src) .. ' Have Been Marked As Cheater [ Spam or Using Item Without Having it from OtherPlayer]', true)
			DropPlayer(src, 'nah nah nah next time you will be banned')
			return
		end
		local fromItemData = OtherPlayer.PlayerData.items[fromSlot]
		fromAmount = tonumber(fromAmount) or fromItemData.amount
		if fromItemData and fromItemData.amount >= fromAmount then
			local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
			if toInventory == "player" or toInventory == "hotbar" then
				local toItemData = GetItemBySlot(src, toSlot)
				RemoveItem(playerId, itemInfo["name"], fromAmount, fromSlot)
				TriggerClientEvent('inventory:client:ItemBox',playerId, QBCore.Shared.Items[itemInfo["name"]], "remove", fromAmount)
				TriggerClientEvent("inventory:client:CheckWeapon", OtherPlayer.PlayerData.source, fromItemData.name)
				if toItemData then
					itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						RemoveItem(src, toItemData.name, toAmount, toSlot)
						AddItem(playerId, itemInfo["name"], toAmount, fromSlot, toItemData.info, toItemData.created)
						TriggerEvent("qb-log:server:CreateLog", "robbing", "Swapped Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) swapped item; name: **"..toItemData.name.."**, amount: **" .. toAmount .. "** with item; **"..itemInfo["name"].."**, amount: **" .. toAmount .. "** from player: **".. GetPlayerName(OtherPlayer.PlayerData.source) .. "** (citizenid: *"..OtherPlayer.PlayerData.citizenid.."* | *"..OtherPlayer.PlayerData.source.."*)")
					end
				else
					TriggerEvent("qb-log:server:CreateLog", "robbing", "Retrieved Item", "green", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) took item; name: **"..fromItemData.name.."**, amount: **" .. fromAmount .. "** from player: **".. GetPlayerName(OtherPlayer.PlayerData.source) .. "** (citizenid: *"..OtherPlayer.PlayerData.citizenid.."* | *"..OtherPlayer.PlayerData.source.."*)")
				end
				AddItem(src, fromItemData.name, fromAmount, toSlot, fromItemData.info, fromItemData.created)
				TriggerClientEvent('inventory:client:ItemBox',src, QBCore.Shared.Items[fromItemData.name], "add", fromAmount)
			else
				local toItemData = OtherPlayer.PlayerData.items[toSlot]
				RemoveItem(playerId, itemInfo["name"], fromAmount, fromSlot)
				if toItemData then
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
						RemoveItem(playerId, itemInfo["name"], toAmount, toSlot)
						AddItem(playerId, itemInfo["name"], toAmount, fromSlot, toItemData.info, toItemData.created)
					end
				end
				itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
				AddItem(playerId, itemInfo["name"], fromAmount, toSlot, fromItemData.info, fromItemData.created)
			end
		else
			QBCore.Functions.Notify(src, "Item doesn't exist", "error")
		end
	elseif QBCore.Shared.SplitStr(fromInventory, "-")[1] == "trunk" then
		local plate = QBCore.Shared.SplitStr(fromInventory, "-")[2]
		local fromItemData = Trunks[plate].items[fromSlot]
		fromAmount = tonumber(fromAmount) or fromItemData.amount
		if fromItemData and fromItemData.amount >= fromAmount then
			local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
			if toInventory == "player" or toInventory == "hotbar" then
				local toItemData = GetItemBySlot(src, toSlot)
				RemoveFromTrunk(plate, fromSlot, itemInfo["name"], fromAmount)
				if toItemData then
					itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						RemoveItem(src, toItemData.name, toAmount, toSlot)
						AddToTrunk(plate, fromSlot, toSlot, itemInfo["name"], toAmount, toItemData.info, toItemData.created)
						TriggerEvent("qb-log:server:CreateLog", "trunk", "Swapped Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) swapped item; name: **"..toItemData.name.."**, amount: **" .. toAmount .. "** with item; name: **"..itemInfo["name"].."**, amount: **" .. toAmount .. "** plate: *" .. plate .. "*")
					else
						TriggerEvent("qb-log:server:CreateLog", "trunk", "Stacked Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) stacked item; name: **"..toItemData.name.."**, amount: **" .. toAmount .. "** from plate: *" .. plate .. "*")
					end
				else
					TriggerEvent("qb-log:server:CreateLog", "trunk", "Received Item", "green", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) received item; name: **"..fromItemData.name.."**, amount: **" .. fromAmount.. "** plate: *" .. plate .. "*")
				end
				AddItem(src, fromItemData.name, fromAmount, toSlot, fromItemData.info, fromItemData.created)
			else
				local toItemData = Trunks[plate].items[toSlot]
				RemoveFromTrunk(plate, fromSlot, itemInfo["name"], fromAmount)
				if toItemData then
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
						RemoveFromTrunk(plate, toSlot, itemInfo["name"], toAmount)
						AddToTrunk(plate, fromSlot, toSlot, itemInfo["name"], toAmount, toItemData.info, toItemData.created)
					end
				end
				itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
				AddToTrunk(plate, toSlot, fromSlot, itemInfo["name"], fromAmount, fromItemData.info, fromItemData.created)
			end
		else
			QBCore.Functions.Notify(src, Lang:t("notify.itemexist"), "error")
		end
	elseif QBCore.Shared.SplitStr(fromInventory, "-")[1] == "glovebox" then
		local plate = QBCore.Shared.SplitStr(fromInventory, "-")[2]
		local fromItemData = Gloveboxes[plate].items[fromSlot]
		fromAmount = tonumber(fromAmount) or fromItemData.amount
		if fromItemData and fromItemData.amount >= fromAmount then
			local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
			if toInventory == "player" or toInventory == "hotbar" then
				local toItemData = GetItemBySlot(src, toSlot)
				RemoveFromGlovebox(plate, fromSlot, itemInfo["name"], fromAmount)
				if toItemData then
					itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						RemoveItem(src, toItemData.name, toAmount, toSlot)
						AddToGlovebox(plate, fromSlot, toSlot, itemInfo["name"], toAmount, toItemData.info, toItemData.created)
						TriggerEvent("qb-log:server:CreateLog", "glovebox", "Swapped", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src..")* swapped item; name: **"..toItemData.name.."**, amount: **" .. toAmount .. "** with item; name: **"..itemInfo["name"].."**, amount: **" .. toAmount .. "** plate: *" .. plate .. "*")
					else
						TriggerEvent("qb-log:server:CreateLog", "glovebox", "Stacked Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) stacked item; name: **"..toItemData.name.."**, amount: **" .. toAmount .. "** from plate: *" .. plate .. "*")
					end
				else
					TriggerEvent("qb-log:server:CreateLog", "glovebox", "Received Item", "green", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) received item; name: **"..fromItemData.name.."**, amount: **" .. fromAmount.. "** plate: *" .. plate .. "*")
				end
				AddItem(src, fromItemData.name, fromAmount, toSlot, fromItemData.info, fromItemData.created)
			else
				local toItemData = Gloveboxes[plate].items[toSlot]
				RemoveFromGlovebox(plate, fromSlot, itemInfo["name"], fromAmount)
				if toItemData then
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
						RemoveFromGlovebox(plate, toSlot, itemInfo["name"], toAmount)
						AddToGlovebox(plate, fromSlot, toSlot, itemInfo["name"], toAmount, toItemData.info, toItemData.created)
					end
				end
				itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
				AddToGlovebox(plate, toSlot, fromSlot, itemInfo["name"], fromAmount, fromItemData.info, fromItemData.created)
			end
		else
			QBCore.Functions.Notify(src, Lang:t("notify.itemexist"), "error")
		end
	elseif QBCore.Shared.SplitStr(fromInventory, "-")[1] == "stash" then
		local stashId = QBCore.Shared.SplitStr(fromInventory, "-")[2]
		local fromItemData = Stashes[stashId] and Stashes[stashId].items and Stashes[stashId].items[fromSlot] or nil
		if not fromItemData then return end
		fromAmount = tonumber(fromAmount) or fromItemData.amount
		if fromItemData and fromItemData.amount >= fromAmount then
			local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
			if toInventory == "player" or toInventory == "hotbar" then
				local toItemData = GetItemBySlot(src, toSlot)
				RemoveFromStash(stashId, fromSlot, itemInfo["name"], fromAmount)
				if toItemData then
					itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						RemoveItem(src, toItemData.name, toAmount, toSlot)
						AddToStash(stashId, fromSlot, toSlot, itemInfo["name"], toAmount, toItemData.info, toItemData.created)
						TriggerEvent("qb-log:server:CreateLog", "stash", "Swapped Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) swapped item; name: **"..toItemData.name.."**, amount: **" .. toAmount .. "** with item; name: **"..fromItemData.name.."**, amount: **" .. fromAmount .. "** stash: *" .. stashId .. "*")
					else
						TriggerEvent("qb-log:server:CreateLog", "stash", "Stacked Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) stacked item; name: **"..toItemData.name.."**, amount: **" .. toAmount .. "** from stash: *" .. stashId .. "*")
					end
				else
					TriggerEvent("qb-log:server:CreateLog", "stash", "Received Item", "green", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) received item; name: **"..fromItemData.name.."**, amount: **" .. fromAmount.. "** stash: *" .. stashId .. "*")
				end
				SaveStashItems(stashId, Stashes[stashId].items)
				AddItem(src, fromItemData.name, fromAmount, toSlot, fromItemData.info, fromItemData.created)
			else
				local toItemData = Stashes[stashId] and Stashes[stashId].items and Stashes[stashId].items[toSlot] or nil
				RemoveFromStash(stashId, fromSlot, itemInfo["name"], fromAmount)
				if toItemData then
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
						RemoveFromStash(stashId, toSlot, itemInfo["name"], toAmount)
						AddToStash(stashId, fromSlot, toSlot, itemInfo["name"], toAmount, toItemData.info, toItemData.created)
					end
				end
				itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
				AddToStash(stashId, toSlot, fromSlot, itemInfo["name"], fromAmount, fromItemData.info, fromItemData.created)
			end
		else
			QBCore.Functions.Notify(src, Lang:t("notify.itemexist"), "error")
		end
	elseif QBCore.Shared.SplitStr(fromInventory, "-")[1] == "traphouse" then
		local traphouseId = QBCore.Shared.SplitStr(fromInventory, "-")[2]
		local fromItemData = exports['qb-traphouse']:GetInventoryData(traphouseId, fromSlot)
		fromAmount = tonumber(fromAmount) or fromItemData.amount
		if fromItemData and fromItemData.amount >= fromAmount then
			local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
			if toInventory == "player" or toInventory == "hotbar" then
				local toItemData = GetItemBySlot(src, toSlot)
				exports['qb-traphouse']:RemoveHouseItem(traphouseId, fromSlot, itemInfo["name"], fromAmount)
				if toItemData then
					itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						RemoveItem(src, toItemData.name, toAmount, toSlot)
						exports['qb-traphouse']:AddHouseItem(traphouseId, fromSlot, itemInfo["name"], toAmount, toItemData.info, src)
						TriggerEvent("qb-log:server:CreateLog", "stash", "Swapped Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) swapped item; name: **"..toItemData.name.."**, amount: **" .. toAmount .. "** with item; name: **"..fromItemData.name.."**, amount: **" .. fromAmount .. "** stash: *" .. traphouseId .. "*")
					else
						TriggerEvent("qb-log:server:CreateLog", "stash", "Stacked Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) stacked item; name: **"..toItemData.name.."**, amount: **" .. toAmount .. "** from stash: *" .. traphouseId .. "*")
					end
				else
					TriggerEvent("qb-log:server:CreateLog", "stash", "Received Item", "green", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) received item; name: **"..fromItemData.name.."**, amount: **" .. fromAmount.. "** stash: *" .. traphouseId .. "*")
				end
				AddItem(src, fromItemData.name, fromAmount, toSlot, fromItemData.info, fromItemData.created)
			else
				local toItemData = exports['qb-traphouse']:GetInventoryData(traphouseId, toSlot)
				exports['qb-traphouse']:RemoveHouseItem(traphouseId, fromSlot, itemInfo["name"], fromAmount)
				if toItemData then
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
						exports['qb-traphouse']:RemoveHouseItem(traphouseId, toSlot, itemInfo["name"], toAmount)
						exports['qb-traphouse']:AddHouseItem(traphouseId, fromSlot, itemInfo["name"], toAmount, toItemData.info, src)
					end
				end
				itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
				exports['qb-traphouse']:AddHouseItem(traphouseId, toSlot, itemInfo["name"], fromAmount, fromItemData.info, src)
			end
		else
			QBCore.Functions.Notify(src, "Item doesn't exist??", "error")
		end
	elseif QBCore.Shared.SplitStr(fromInventory, "-")[1] == "itemshop" then
		local shopType = QBCore.Shared.SplitStr(fromInventory, "-")[2]
		local itemData = ShopItems[shopType].items[fromSlot]
		local itemInfo = QBCore.Shared.Items[itemData.name:lower()]
		local bankBalance = Player.PlayerData.money["bank"]
		local price = tonumber((itemData.price*fromAmount))

		if QBCore.Shared.SplitStr(shopType, "_")[1] == "Dealer" then
			if QBCore.Shared.SplitStr(itemData.name, "_")[1] == "weapon" then
				price = tonumber(itemData.price)
				if Player.Functions.RemoveMoney("cash", price, "dealer-item-bought") then
					itemData.info.serie = tostring(QBCore.Shared.RandomInt(2) .. QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(4))
					itemData.info.quality = 100
					AddItem(src, itemData.name, 1, toSlot, itemData.info)
					TriggerClientEvent('qb-drugs:client:updateDealerItems', src, itemData, 1)
					QBCore.Functions.Notify(src, itemInfo["label"] .. " bought!", "success")
					TriggerEvent("qb-log:server:CreateLog", "dealers", "Dealer item bought", "green", "**"..GetPlayerName(src) .. "** bought a " .. itemInfo["label"] .. " for $"..price)
				else
					QBCore.Functions.Notify(src, Lang:t("notify.notencash"), "error")
				end
			else
				if Player.Functions.RemoveMoney("cash", price, "dealer-item-bought") then
					AddItem(src, itemData.name, fromAmount, toSlot, itemData.info)
					TriggerClientEvent('qb-drugs:client:updateDealerItems', src, itemData, fromAmount)
					QBCore.Functions.Notify(src, itemInfo["label"] .. " bought!", "success")
					TriggerEvent("qb-log:server:CreateLog", "dealers", "Dealer item bought", "green", "**"..GetPlayerName(src) .. "** bought a " .. itemInfo["label"] .. "  for $"..price)
				else
					QBCore.Functions.Notify(src, "You don't have enough cash..", "error")
				end
			end
		elseif QBCore.Shared.SplitStr(shopType, "_")[1] == "Itemshop" then
			if Player.Functions.RemoveMoney("cash", price, "itemshop-bought-item") then
                if QBCore.Shared.SplitStr(itemData.name, "_")[1] == "weapon" then
                    itemData.info.serie = tostring(QBCore.Shared.RandomInt(2) .. QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(4))
					itemData.info.quality = 100
                end
				AddItem(src, itemData.name, fromAmount, toSlot, itemData.info)
				TriggerClientEvent('qb-shops:client:UpdateShop', src, QBCore.Shared.SplitStr(shopType, "_")[2], itemData, fromAmount)
				QBCore.Functions.Notify(src, itemInfo["label"] .. " bought!", "success")
				TriggerEvent("qb-log:server:CreateLog", "shops", "Shop item bought", "green", "**"..GetPlayerName(src) .. "** bought a " .. itemInfo["label"] .. " for $"..price)
			elseif bankBalance >= price then
				Player.Functions.RemoveMoney("bank", price, "itemshop-bought-item")
                if QBCore.Shared.SplitStr(itemData.name, "_")[1] == "weapon" then
                    itemData.info.serie = tostring(QBCore.Shared.RandomInt(2) .. QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(4))
					itemData.info.quality = 100
                end
				AddItem(src, itemData.name, fromAmount, toSlot, itemData.info)
				TriggerClientEvent('qb-shops:client:UpdateShop', src, QBCore.Shared.SplitStr(shopType, "_")[2], itemData, fromAmount)
				QBCore.Functions.Notify(src, itemInfo["label"] .. " bought!", "success")
				TriggerEvent("qb-log:server:CreateLog", "shops", "Shop item bought", "green", "**"..GetPlayerName(src) .. "** bought a " .. itemInfo["label"] .. " for $"..price)
			else
				QBCore.Functions.Notify(src, "You don't have enough cash..", "error")
			end
		elseif QBCore.Shared.SplitStr(shopType, "_")[1] == "toolsfactory" then
			QBCore.Functions.TriggerCallback('qb-toolsfactory:server:toolsfactoryinvecanbuy', src, function(CanBuy)
				if CanBuy then 
					if Player.Functions.RemoveMoney("cash", price, "toolsfactory-bought-item") then
						if QBCore.Shared.SplitStr(itemData.name, "_")[1] == "weapon" then
							itemData.info.serie = tostring(QBCore.Shared.RandomInt(2) .. QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(4))
						end
						AddItem(src, itemData.name, fromAmount, toSlot, itemData.info)
						TriggerEvent('qb-toolsfactory:server:UpdateShopItems', itemData, fromAmount)
						TriggerClientEvent('QBCore:Notify', src, itemInfo["label"] .. " bought!", "success")
						TriggerEvent("qb-log:server:CreateLog", "shops", "toolsfactory item bought", "green", "**"..GetPlayerName(src) .. "** bought a " .. itemInfo["label"] .. " for $"..price)
					else
						TriggerClientEvent('QBCore:Notify', src, "You don't have enough cash..", "error")
					end
				end
			end, itemData, fromAmount)
		else
			if Player.Functions.RemoveMoney("cash", price, "unkown-itemshop-bought-item") then
				AddItem(src, itemData.name, fromAmount, toSlot, itemData.info)
				QBCore.Functions.Notify(src, itemInfo["label"] .. " bought!", "success")
				TriggerEvent("qb-log:server:CreateLog", "shops", "Shop item bought", "green", "**"..GetPlayerName(src) .. "** bought a " .. itemInfo["label"] .. " for $"..price)
			elseif bankBalance >= price then
				Player.Functions.RemoveMoney("bank", price, "unkown-itemshop-bought-item")
				AddItem(src, itemData.name, fromAmount, toSlot, itemData.info)
				QBCore.Functions.Notify(src, itemInfo["label"] .. " bought!", "success")
				TriggerEvent("qb-log:server:CreateLog", "shops", "Shop item bought", "green", "**"..GetPlayerName(src) .. "** bought a " .. itemInfo["label"] .. " for $"..price)
			else
				QBCore.Functions.Notify(src, Lang:t("notify.notencash"), "error")
			end
		end
	elseif fromInventory == "crafting" then
		local itemData = Config.CraftingItems[fromSlot]
		if hasCraftItems(src, itemData.costs, fromAmount) then
			TriggerClientEvent("inventory:client:CraftItems", src, itemData.name, itemData.costs, fromAmount, toSlot, itemData.points)
		else
			TriggerClientEvent("inventory:client:UpdatePlayerInventory", src, true)
			QBCore.Functions.Notify(src, Lang:t("notify.noitem"), "error")
		end
	elseif fromInventory == "attachment_crafting" then
		local itemData = Config.AttachmentCrafting["items"][fromSlot]
		if hasCraftItems(src, itemData.costs, fromAmount) then
			TriggerClientEvent("inventory:client:CraftAttachment", src, itemData.name, itemData.costs, fromAmount, toSlot, itemData.points)
		else
			TriggerClientEvent("inventory:client:UpdatePlayerInventory", src, true)
			QBCore.Functions.Notify(src, Lang:t("notify.noitem"), "error")
		end
	else
		fromInventory = tonumber(fromInventory)
		if not Drops[fromInventory] or not Drops[fromInventory].items then
			print("^1[DEBUG] Drop not found or has no items:", fromInventory)
			return
		end
		
		local fromItemData = Drops[fromInventory].items[fromSlot]
		fromAmount = tonumber(fromAmount) or fromItemData.amount
		
		print("^2[DEBUG] Taking from drop - dropId:", fromInventory, "slot:", fromSlot, "item:", fromItemData and fromItemData.name)
		
		if fromItemData and fromItemData.amount >= fromAmount then
			local itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
			if not itemInfo then
				print("^1[ERROR] Item info not found:", fromItemData.name)
				QBCore.Functions.Notify(src, "Item info not found", "error")
				return
			end
			if toInventory == "player" or toInventory == "hotbar" then
				local toItemData = GetItemBySlot(src, toSlot)
				local addSuccess = AddItem(src, fromItemData.name, fromAmount, toSlot, fromItemData.info, fromItemData.created)
				if not addSuccess then
					print("^1[ERROR] Failed to add item to player inventory")
					QBCore.Functions.Notify(src, "Failed to add item to inventory", "error")
					return
				end
				if not RemoveFromDrop(fromInventory, fromSlot, itemInfo["name"], fromAmount) then
					RemoveItem(src, fromItemData.name, fromAmount, toSlot)
					QBCore.Functions.Notify(src, "Failed to remove item from drop", "error")
					return
				end
				if toItemData then
					toAmount = tonumber(toAmount) and tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
						RemoveItem(src, toItemData.name, toAmount, toSlot)
						AddToDrop(fromInventory, toSlot, itemInfo["name"], toAmount, toItemData.info)
						if itemInfo["name"] == "radio" then
							TriggerClientEvent('Radio.Set', src, false)
						end
						TriggerEvent("qb-log:server:CreateLog", "drop", "Swapped Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) swapped item; name: **"..toItemData.name.."**, amount: **" .. toAmount .. "** with item; name: **"..fromItemData.name.."**, amount: **" .. fromAmount .. "** - dropid: *" .. fromInventory .. "*")
					else
						TriggerEvent("qb-log:server:CreateLog", "drop", "Stacked Item", "orange", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) stacked item; name: **"..toItemData.name.."**, amount: **" .. toAmount .. "** - from dropid: *" .. fromInventory .. "*")
					end
				else
					TriggerEvent("qb-log:server:CreateLog", "drop", "Received Item", "green", "**".. GetPlayerName(src) .. "** (citizenid: *"..Player.PlayerData.citizenid.."* | id: *"..src.."*) received item; name: **"..fromItemData.name.."**, amount: **" .. fromAmount.. "** -  dropid: *" .. fromInventory .. "*")
				end
				print("^2[DEBUG] Item added to player inventory")
				
				if Drops[fromInventory] then
					local isEmpty = true
					if Drops[fromInventory].items then
						for slot, item in pairs(Drops[fromInventory].items) do
							if item ~= nil then
								isEmpty = false
								break
							end
						end
					end
					
					if isEmpty then
						print("^2[DEBUG] Drop is now empty - removing drop:", fromInventory)
						TriggerClientEvent('qb-inventory:updateDropVisualData', -1, fromInventory, Drops[fromInventory].coords, {})
						Drops[fromInventory] = nil
						TriggerClientEvent("inventory:client:RemoveDropItem", -1, fromInventory)
					end
				end
			else
				toInventory = tonumber(toInventory)
				if not Drops[toInventory] or not Drops[toInventory].items then
					print("^1[ERROR] Target drop does not exist:", toInventory)
					QBCore.Functions.Notify(src, "Target drop does not exist", "error")
					return
				end
				local toItemData = Drops[toInventory].items[toSlot]
				itemInfo = QBCore.Shared.Items[fromItemData.name:lower()]
				if not AddToDrop(toInventory, toSlot, itemInfo["name"], fromAmount, fromItemData.info) then
					print("^1[ERROR] Failed to add item to target drop")
					QBCore.Functions.Notify(src, "Failed to add item to drop", "error")
					return
				end
				if toItemData then
					toAmount = tonumber(toAmount) or toItemData.amount
					if toItemData.name ~= fromItemData.name then
						itemInfo = QBCore.Shared.Items[toItemData.name:lower()]
						if not RemoveFromDrop(toInventory, toSlot, itemInfo["name"], toAmount) then
							RemoveFromDrop(toInventory, toSlot, fromItemData.name, fromAmount)
							QBCore.Functions.Notify(src, "Failed to swap items", "error")
							return
						end
						if not AddToDrop(fromInventory, fromSlot, itemInfo["name"], toAmount, toItemData.info) then
							AddToDrop(toInventory, toSlot, itemInfo["name"], toAmount, toItemData.info)
							RemoveFromDrop(toInventory, toSlot, fromItemData.name, fromAmount)
							QBCore.Functions.Notify(src, "Failed to swap items", "error")
							return
						end
						if itemInfo["name"] == "radio" then
							TriggerClientEvent('Radio.Set', src, false)
						end
					end
				end
				if not RemoveFromDrop(fromInventory, fromSlot, fromItemData.name, fromAmount) then
					RemoveFromDrop(toInventory, toSlot, fromItemData.name, fromAmount)
					QBCore.Functions.Notify(src, "Failed to remove item from source drop", "error")
					return
				end
				if itemInfo["name"] == "radio" then
					TriggerClientEvent('Radio.Set', src, false)
				end
			end
		else
			QBCore.Functions.Notify(src, "Item doesn't exist??", "error")
		end
	end
	TriggerClientEvent("inventory:client:UpdatePlayerInventory", Player.PlayerData.source, false)
end)

RegisterNetEvent('qb-inventory:server:SaveStashItems', function(stashId, items)
    MySQL.insert('INSERT INTO stashitems (stash, items) VALUES (:stash, :items) ON DUPLICATE KEY UPDATE items = :items', {
        ['stash'] = stashId,
        ['items'] = json.encode(items)
    })
end)

QBCore.Functions.CreateCallback('qb-inventory:server:GetClosestPlayer', function(source, cb)
    local src = source 
    local myPlayer = QBCore.Functions.GetPlayer(src)
    local players = QBCore.Functions.GetQBPlayers()
    local ClosestPlayer = {}
    local myCoords = GetEntityCoords(GetPlayerPed(src))
    for k, player in pairs (players) do
        if player.PlayerData.source ~= src then 
            local targetped = GetPlayerPed(player.PlayerData.source)
            local TargetCoords = GetEntityCoords(targetped)
            if #(myCoords - TargetCoords) <= 2 then 
                local ped = QBCore.Functions.GetPlayer(player.PlayerData.source)
                ClosestPlayer[#ClosestPlayer+1] = {
                    name = ped.PlayerData.charinfo.firstname .. ' ' .. ped.PlayerData.charinfo.lastname,
                    id = ped.PlayerData.source,
                }
            end
        end
    end
    cb(ClosestPlayer)
end)

RegisterServerEvent("inventory:server:GiveItem", function(data)
    local src = source
	if not data then 
		return 
	end
	local name = data.name
	local amount = tonumber(data.amount)
	local slot = data.slot
    local Player = QBCore.Functions.GetPlayer(src)
	local target = tonumber(data.playerId)
    local OtherPlayer = QBCore.Functions.GetPlayer(target)
    local dist = #(GetEntityCoords(GetPlayerPed(src))-GetEntityCoords(GetPlayerPed(target)))
	if Player == OtherPlayer then return QBCore.Functions.Notify(src, Lang:t("notify.gsitem")) end
	if dist > 2 then return QBCore.Functions.Notify(src, Lang:t("notify.tftgitem")) end
	local item = GetItemBySlot(src, slot)
	if not item then QBCore.Functions.Notify(src, Lang:t("notify.infound")); return end
	if item.name ~= name then QBCore.Functions.Notify(src, Lang:t("notify.iifound")); return end

	if amount <= item.amount then
		if amount == 0 then
			amount = item.amount
		end
		local totalWeight = GetTotalWeight(OtherPlayer.PlayerData.items)
		local itemInfo = QBCore.Shared.Items[item.name:lower()]
		if (totalWeight + (itemInfo['weight'] * amount)) <= Config.MaxInventoryWeight then
			if RemoveItem(src, item.name, amount, item.slot) then
				if AddItem(tonumber(target), item.name, amount, false, item.info, item.created) then
					TriggerClientEvent('inventory:client:ItemBox',target, QBCore.Shared.Items[item.name], "add", amount)
					QBCore.Functions.Notify(target, Lang:t("notify.gitemrec")..amount..' '..item.label..Lang:t("notify.gitemfrom")..Player.PlayerData.charinfo.firstname.." "..Player.PlayerData.charinfo.lastname)
					TriggerClientEvent("inventory:client:UpdatePlayerInventory", target, true)
					TriggerClientEvent('inventory:client:ItemBox',src, QBCore.Shared.Items[item.name], "remove", amount)
					QBCore.Functions.Notify(src, Lang:t("notify.gitemyg") .. OtherPlayer.PlayerData.charinfo.firstname.." "..OtherPlayer.PlayerData.charinfo.lastname.. " " .. amount .. " " .. item.label .."!")
					TriggerClientEvent("inventory:client:UpdatePlayerInventory", src, true)
					TriggerClientEvent('qb-inventory:client:giveAnim', src)
					TriggerClientEvent('qb-inventory:client:giveAnim', target)
				else
					AddItem(tonumber(target), item.name, amount, item.slot, item.info, item.created)
					QBCore.Functions.Notify(src, Lang:t("notify.gitinvfull"), "error")
					QBCore.Functions.Notify(target, Lang:t("notify.giymif"), "error")
					TriggerClientEvent("inventory:client:UpdatePlayerInventory", src, false)
					TriggerClientEvent("inventory:client:UpdatePlayerInventory", target, false)
				end
				if item.type == 'weapon' then 
					TriggerClientEvent('inventory:client:GiveItemRemoveWeapon', src)
				end
				TriggerEvent("qb-log:server:CreateLog", 
					"giveitemplayer",
					"Give Item",
					"green",
					"**"..GetPlayerName(src) .. "** Has Gave **"..GetPlayerName(target) .. "** Item : "..item.label.." Amount : "..amount.."",
					false
				)
			else
				QBCore.Functions.Notify(src, Lang:t("notify.gitydhei"), "error")
			end
		elseif not Player.Offline then
			QBCore.Functions.Notify(src, "Player Inventory is full", 'error')
		end
	else
		QBCore.Functions.Notify(src, Lang:t("notify.gitydhitt"))
	end
end)

RegisterNetEvent('inventory:server:snowball', function(action)
	if action == "add" then
		AddItem(source, "weapon_snowball")
	elseif action == "remove" then
		RemoveItem(source, "weapon_snowball")
	end
end)

RegisterNetEvent('inventory:server:DropItem', function(itemData, amount)
    local src = source
    if not itemData or not itemData.slot then return end
    amount = tonumber(amount) or 1
    CreateNewDrop(src, itemData.slot, 1, amount)
end)

QBCore.Functions.CreateCallback('qb-inventory:server:GetStashItems', function(_, cb, stashId)
	cb(GetStashItems(stashId))
end)

QBCore.Functions.CreateCallback('inventory:server:GetCurrentDrops', function(_, cb)
	cb(Drops)
end)

QBCore.Functions.CreateCallback('QBCore:HasItem', function(source, cb, items, amount)
    local retval = false
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(false) end
    local isTable = type(items) == 'table'
    local isArray = isTable and table.type(items) == 'array' or false
    local totalItems = #items
    local count = 0
    local kvIndex = 2
    if isTable and not isArray then
        totalItems = 0
        for _ in pairs(items) do totalItems += 1 end
        kvIndex = 1
    end
    if isTable then
        for k, v in pairs(items) do
            local itemKV = {k, v}
            local item = GetItemByName(source, itemKV[kvIndex])
            if item and ((amount and item.amount >= amount) or (not amount and not isArray and item.amount >= v) or (not amount and isArray)) then
                count += 1
            end
        end
        if count == totalItems then
            retval = true
        end
    else
        local item = GetItemByName(source, items)
        if item and not amount or (item and amount and item.amount >= amount) then
            retval = true
        end
    end
    cb(retval)
end)

QBCore.Commands.Add("resetinv", "Reset Inventory (Admin Only)", {{name="type", help="stash/trunk/glovebox"},{name="id/plate", help="ID of stash or license plate"}}, true, function(source, args)
	local invType = args[1]:lower()
	table.remove(args, 1)
	local invId = table.concat(args, " ")
	if invType and invId then
		if invType == "trunk" then
			if Trunks[invId] then
				Trunks[invId].isOpen = false
			end
		elseif invType == "glovebox" then
			if Gloveboxes[invId] then
				Gloveboxes[invId].isOpen = false
			end
		elseif invType == "stash" then
			if Stashes[invId] then
				Stashes[invId].isOpen = false
			end
		else
			QBCore.Functions.Notify(source,  Lang:t("notify.navt"), "error")
		end
	else
		QBCore.Functions.Notify(source,  Lang:t("notify.anfoc"), "error")
	end
end, { 'god', 'admin', 'operator' })

QBCore.Commands.Add("rob", "Rob Player", {}, false, function(source, _)
	TriggerClientEvent("police:client:RobPlayer", source)
end)

QBCore.Commands.Add("gg", "Give An Item (Admin Only)", {{name="id", help="Player ID"},{name="item", help="Name of the item (not a label)"}, {name="amount", help="Amount of items"}}, false, function(source, args)
	local id = tonumber(args[1])
	local Player = QBCore.Functions.GetPlayer(id)
	local amount = tonumber(args[3]) or 1
	local itemData = QBCore.Shared.Items[tostring(args[2]):lower()]
	if Player then
			if itemData then
				local info = {}
				if itemData["name"] == "id_card" then
					info.citizenid = Player.PlayerData.citizenid
					info.firstname = Player.PlayerData.charinfo.firstname
					info.lastname = Player.PlayerData.charinfo.lastname
					info.birthdate = Player.PlayerData.charinfo.birthdate
					info.gender = Player.PlayerData.charinfo.gender
					info.nationality = Player.PlayerData.charinfo.nationality
				elseif itemData["name"] == "driver_license" then
					info.firstname = Player.PlayerData.charinfo.firstname
					info.lastname = Player.PlayerData.charinfo.lastname
					info.birthdate = Player.PlayerData.charinfo.birthdate
					info.type = "Class C Driver License"
				elseif itemData["type"] == "weapon" then
					amount = 1
					info.serie = tostring(QBCore.Shared.RandomInt(2) .. QBCore.Shared.RandomStr(3) .. QBCore.Shared.RandomInt(1) .. QBCore.Shared.RandomStr(2) .. QBCore.Shared.RandomInt(3) .. QBCore.Shared.RandomStr(4))
					info.quality = 100
				elseif itemData["name"] == "harness" then
					info.uses = 20
				elseif itemData["name"] == "markedbills" then
					info.worth = math.random(5000, 10000)
				elseif itemData["name"] == "labkey" then
					info.lab = exports["qb-methlab"]:GenerateRandomLab()
				elseif itemData["name"] == "printerdocument" then
					info.url = "https://cdn.discordapp.com/attachments/870094209783308299/870104331142189126/Logo_-_Display_Picture_-_Stylized_-_Red.png"
				elseif itemData["name"] == "hacking_device" then
					local timeex = "259200"
					info.exp = tonumber(os.time() + timeex)
					info.explable = QBCore.Functions.TimeFormate(info.exp)
				elseif itemData["name"] == "breaker" then
					info.uses = 10
				elseif itemData["name"] == "bighousecas" then
					info.worth = math.random(5000, 10000)
				elseif itemData["name"] == "moneybox" then
					info.money = math.random(10000, 15000)
				elseif itemData["name"] == "keycard1" then
					info.bighouse = exports["qb-houserobbery"]:GetHouseKeyData()
				elseif itemData["name"] == "syphoningkit" then
					info.gasamount = 0
				elseif itemData["name"] == "jerrycan01" then
					info.gasamount = 20
				end

				if AddItem(tonumber(args[1]), itemData["name"], amount, false, info) then
					QBCore.Functions.Notify(source, Lang:t("notify.yhg") ..GetPlayerName(id).." "..amount.." "..itemData["name"].. "", "success")
					QBCore.Functions.CreateLog(
						"giveitem",
						"Item Spawned",
						"green",
						"**"..GetPlayerName(source) .. "** Spawned Item TO **"..GetPlayerName(id).."** amount : **"..amount.."** Item Name : **"..itemData["label"].. "**",
						false
					)
				else
					QBCore.Functions.Notify(source,  Lang:t("notify.cgitem"), "error")
				end
			else
				QBCore.Functions.Notify(source,  Lang:t("notify.idne"), "error")
			end
	else
		QBCore.Functions.Notify(source,  Lang:t("notify.pdne"), "error")
	end
end, { 'god', 'admin', 'operator', 'staff', 'supervisor', 'trusted' })

QBCore.Commands.Add("randomitems", "Give Random Items (God Only)", {}, false, function(source, _)
	local filteredItems = {}
	for k, v in pairs(QBCore.Shared.Items) do
		if QBCore.Shared.Items[k]["type"] ~= "weapon" then
			filteredItems[#filteredItems+1] = v
		end
	end
	for _ = 1, 10, 1 do
		local randitem = filteredItems[math.random(1, #filteredItems)]
		local amount = math.random(1, 10)
		if randitem["unique"] then
			amount = 1
		end
		if AddItem(source, randitem["name"], amount) then
			TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[randitem["name"]], 'add')
            Wait(500)
		end
	end
end, "god")

QBCore.Commands.Add('clearinv', 'Clear Players Inventory (Admin Only)', { { name = 'id', help = 'Player ID' } }, false, function(source, args)
    local playerId = args[1] ~= '' and tonumber(args[1]) or source
    local Player = QBCore.Functions.GetPlayer(playerId)
    if Player then
        ClearInventory(playerId)
    else
        QBCore.Functions.Notify(source, "Player not online", 'error')
    end
end, { 'god', 'admin', 'operator' })

CreateThread(function()
	while true do
		for k, v in pairs(Drops) do
			if v and (v.createdTime + Config.CleanupDropTime < os.time()) and not Drops[k].isOpen then
				TriggerClientEvent('qb-inventory:updateDropVisualData', -1, k, v.coords, {})
				Drops[k] = nil
				TriggerClientEvent("inventory:client:RemoveDropItem", -1, k)
			end
		end
		Wait(60 * 1000)
	end
end)
