require("apclient")

callback.register("onStageEntry", function()
	-- print(Stage.getCurrentStage().interactables)
end)

callback.register("onMinute", function(min, sec)
	-- print("enemy_buff: " .. misc.director:get("enemy_buff")
end)

callback.register("globalRoomEnd", function(room)
	-- print(room:getName())
end)