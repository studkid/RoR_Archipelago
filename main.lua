require("apclient")

callback.register("onStageEntry", function(npc)
	-- print(Stage.getCurrentStage())
end)

callback.register("onMinute", function(min, sec)
	-- print("enemy_buff: " .. misc.director:get("enemy_buff"))
end)
