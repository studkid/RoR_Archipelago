local chests = { 'Chest1', 'Chest2', 'Chest3', 'Chest4', 'Chest5'}

local game_name = "Risk of Rain"
local items_handling = 7
local message_format = AP.RenderFormat.TEXT
local ap = nil

local playerInst = nil
local common = nil
local uncommon = nil
local rare = nil
local equipment = nil
local boss = nil

local connected = false
local runStarted = false
local skipItemSend = false
local slotData = nil

local itemsCollected = {}

-----------------------------------------------------------------------
-- AP Client Handling                                                --
-----------------------------------------------------------------------
function connect(server, slot, password)
    function on_socket_connected()
        print("Socket connected")
    end

    function on_socket_error(msg)
        print("Socket error: " .. msg)
    end

    function on_socket_disconnected()
        print("Socket disconnected")
        connected = false
        skipItemSend = true
        itemsCollected = {}
    end

    function on_room_info()
        print("Room info")
        ap:ConnectSlot(slot, password, items_handling, {"Lua-APClientPP"}, {0, 4, 4})
    end

    function on_slot_connected(data)
        print("Slot connected")
        slotData = data
        
        curPlayerSlot = ap:get_player_number()
        connected = true

        print(slotData)
        print(ap.checked_locations)
        print(ap.missing_locations)

        local missingLocations = {}
    end

    function on_slot_refused(reasons)
        print("Slot refused: " .. table.concat(reasons, ", "))
    end

    function on_items_received(items)
        print("Items received:")
        for _, item in ipairs(items) do
            print(ap:get_item_name(item.item))

            if playerInst == nil then -- Check if playerInst has been initialized
                return
            end

            if(skipItemSend) then
                return
            elseif item.item == 250001 then -- Common Item
		        playerInst:giveItem(common:roll())
            elseif item.item == 250002 then -- Uncommon Item
		        playerInst:giveItem(uncommon:roll())
	        elseif item.item == 250003 then -- Rare Item
		        playerInst:giveItem(rare:roll())
	        elseif item.item == 250004 then -- Boss Item
                bossItem = boss:roll()

                if bossItem.isUseItem then
                    bossItem:create(playerInst.x, playerInst.y)
                else 
                    playerInst:giveItem(bossItem)
                end
            elseif item.item == 250005 then -- Equipment
                equipment:roll():create(playerInst.x, playerInst.y)
            end

            table.insert(itemsCollected, item)
        end

        skipItemSend = false
        runStarted = true
    end

    function on_location_info(items)
        print("Locations scouted:")
        for _, item in ipairs(items) do
            print(item.item)
        end
    end

    function on_location_checked(locations)
        print("Locations checked:" .. table.concat(locations, ", "))
        print("Checked locations: " .. table.concat(ap.checked_locations, ", "))
    end

    function on_data_package_changed(data_package)
        print("Data package changed:")
        print(data_package)
    end

    function on_print(msg)
        print(msg)
    end

    function on_print_json(msg, extra)
        print(ap:render_json(msg, message_format))
        for key, value in pairs(extra) do
            print("  " .. key .. ": " .. tostring(value))
        end
    end

    function on_bounced(bounce)
        print("Bounced:")
        print(bounce)
    end

    function on_retrieved(map, keys, extra)
        print("Retrieved:")    
    end

    function on_set_reply(message)
        print("Set Reply:")
    end


    local uuid = ""
    ap = AP(uuid, game_name, server);

    ap:set_socket_connected_handler(on_socket_connected)
    ap:set_socket_error_handler(on_socket_error)
    ap:set_socket_disconnected_handler(on_socket_disconnected)
    ap:set_room_info_handler(on_room_info)
    ap:set_slot_connected_handler(on_slot_connected)
    ap:set_slot_refused_handler(on_slot_refused)
    ap:set_items_received_handler(on_items_received)
    ap:set_location_info_handler(on_location_info)
    ap:set_location_checked_handler(on_location_checked)
    ap:set_data_package_changed_handler(on_data_package_changed)
    ap:set_print_handler(on_print)
    ap:set_print_json_handler(on_print_json)
    ap:set_bounced_handler(on_bounced)
    ap:set_retrieved_handler(on_retrieved)
    ap:set_set_reply_handler(on_set_reply)
end

-----------------------------------------------------------------------
-- Game Callbacks                                                    --
-----------------------------------------------------------------------

-- Runs on initial game load
callback.register("onLoad", function(item)
    getItemPools(ItemPool.findAll()) 
	connect(server, slot, password)
end)

-- Save the player instance to a local variable
callback.register("onPlayerInit", function(playerInstance)
    playerInst = playerInstance
end)

-- Give player collected items between runs
callback.register("onPlayerDraw", function(playerInstance)
    if not runStarted and connected then
        -- Would have this a seperate function but game locks up if run in on_items_recieved
        for _, item in ipairs(itemsCollected) do 

            if item.item == 250001 then -- Common Item
                playerInstance:giveItem(common:roll())
            elseif item.item == 250002 then -- Uncommon Item
                playerInstance:giveItem(uncommon:roll())
            elseif item.item == 250003 then -- Rare Item
                playerInstance:giveItem(rare:roll())
            elseif item.item == 250004 then -- Boss Item
                bossItem = boss:roll()

                if bossItem.isUseItem then
                    bossItem:create(playerInstance.x, playerInstance.y)
                else 
                    playerInstance:giveItem(bossItem)
                end
            elseif item.item == 250005 then -- Equipment
                equipment:roll():create(playerInstance.x, playerInstance.y)
            end
        end

        runStarted = true
    end
end)

-- Runs poll() every game tick while in game
callback.register("onStep", function()
	if ap then
        ap:poll() 
    end
end)

-- Location checker (WIP)
callback.register("onMapObjectActivate", function(mapObject, activator)
    print(mapObject:getObject():getName())
    if connected then
        object = mapObject:getObject():getName()
        location = ap.missing_locations[1]
        print(location)

        if tableContains(chests, object) and not location == nil then
            print(ap:get_location_name(location))
        end
    end
end) 

-- Tracks when a current run ends
callback.register("onGameEnd", function()
    runStarted = false
    playerInst = nil
end)

-- Registers every necessary itemPool
function getItemPools(itemPools) 
    for i, pool in pairs(itemPools) do
        if pool:getName() == "common" then
			common = pool
		end

		if pool:getName() == "uncommon" then
			uncommon = pool
		end

		if pool:getName() == "rare" then
			rare = pool
		end

		if pool:getName() == "use" then
			equipment = pool
		end
    end

    boss = ItemPool.new("boss")
    
    boss:add(Item.find("ifrit's horn"))
    boss:add(Item.find("Colossal Knurl"))
    boss:add(Item.find("Nematocyst Nozzle"))
    boss:add(Item.find("Burning Witness"))
    boss:add(Item.find("Legendary Spark"))
    boss:add(Item.find("Imp Overlord's Tentacle"))
end