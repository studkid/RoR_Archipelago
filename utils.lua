local common = nil
local uncommon = nil
local rare = nil
local equipment = nil

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
end

function collectItem(item)
    print(item)
end