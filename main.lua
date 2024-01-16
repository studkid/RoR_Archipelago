require("apclient")
require("prefs")
require("utils")

local runStarted = false



callback.register("onStageEntry", function(npc)
	print(Stage.getCurrentStage())
end)

