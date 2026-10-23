-- Made with <3 by Taze
--!optimize 2

-- References
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Client = LocalPlayer.PlayerScripts.TS
local Shared = ReplicatedStorage.TS
local Network = require(Client.network)
local Events = Network.Events
local Signals = Network.Signals
local Sugar = require(Shared.packages.sugar).Sugar
local PlayerSelectors = require(Client.store["player-selectors-atom"])
local SceneReplica = require(Client.store["scene-replica-atom"])
local ActiveScene = require(Client.store["active-scene-atom"])
local SceneContext = require(Client.utilities["scene-request-context"])
local PlayerPlot = require(Client.utilities["player-plot"])
local WorldInteractionsBlocked = require(Client.store["world-interactions-blocked-atom"]).worldInteractionsBlockedAtom
local CharacterPosition = require(Shared.utilities["character-position"])
local PlotPlacements = require(Shared.store.placements["plots-atom"])
local CropShop = require(Shared.store["crop-shop-atom"])
local CropRegistry = require(Shared.data["crop-registry"])
local CropStage = require(Shared.utilities["crop-stage"])
local CropUtilities = require(Shared.utilities.crop)
local Grid = require(Shared.utilities.grid)
local Datastore = require(Shared.utilities.datastore)
local ItemUtilities = require(Shared.utilities.items)
local ShopPrice = require(Shared.utilities["shop-price"])
local ItemData = require(Shared.data.items).items
local TreasureChests = require(Shared.data["treasure-chests"])
local DailyRewardUi = require(Client.store["daily-reward-atom"]).dailyRewardUiAtom
local LocalPlayerLock = require(Client.store["local-player-lock-atom"]).localPlayerLockAtom
local PlayerState = require(Shared.store.players["player-state-atom"])
local Flamework = require(ReplicatedStorage.rbxts_include.node_modules["@flamework"].core.out).Flamework
local DailyRewardController = Flamework.resolveDependency("client/controllers/gameplay/daily-reward-controller@DailyRewardController")

-- UI Init
local Environment = getgenv()

if Environment.Caramel and not Environment.Caramel.Unloaded then
	Environment.Caramel:Unload()
end

local Repository = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(`{Repository}Library.lua`))()
local ThemeManager = loadstring(game:HttpGet(`{Repository}addons/ThemeManager.lua`))()
local SaveManager = loadstring(game:HttpGet(`{Repository}addons/SaveManager.lua`))()
local Options = Library.Options
local Toggles = Library.Toggles
local FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.SemiBold)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"MenuKeybind"})
ThemeManager:SetFolder("Caramel")
SaveManager:SetFolder("Caramel")

Library.Scheme.BackgroundColor = Color3.fromRGB(12, 13, 15)
Library.Scheme.MainColor = Color3.fromRGB(21, 22, 25)
Library.Scheme.AccentColor = Color3.fromRGB(209, 164, 111)
Library.Scheme.OutlineColor = Color3.fromRGB(43, 43, 48)
Library.Scheme.FontColor = Color3.fromRGB(237, 231, 222)
Library.Scheme.Font = FontFace
Environment.Caramel = Library

-- Settings
local AutoFarmEnabled = false
local AutoForageEnabled = false
local AutoSellEnabled = false
local AutoBuyEnabled = false
local AutoRewardsEnabled = false
local AutoChestsEnabled = false
local AutoGiftsEnabled = false
local ResourceMarkersEnabled = false
local AutoFarmGeneration = 0
local AutoForageGeneration = 0
local AutoSellGeneration = 0
local AutoBuyGeneration = 0
local AutoRewardsGeneration = 0
local AutoChestsGeneration = 0
local AutoGiftsGeneration = 0
local ResourceMarkersGeneration = 0
local MovementBusy = false
local MovementCharacter = nil
local MovementPivot = nil
local MovementSceneId = nil
local MovementSceneEpoch = nil
local BookmarkPosition = nil
local BookmarkSceneId = nil
local BookmarkSceneEpoch = nil
local OriginalWalkSpeeds = {}
local WalkSpeedHumanoid = nil
local WalkSpeedConnection = nil
local MarkerLabels = {}
local MarkerTargets = {}
local MarkerNextRefresh = 0
local MarkerSceneEpoch = nil
local IdleConnections = {}
local FailedTargets = {}
local SeedNames = {}
local SeedIds = {}
local ProtectedItemNames = {}
local LandmarkNames = {"My Plot"}
local LandmarkIds = {}
local ForageIds = {
	["Dewcap"] = "dewcap",
	["Gleaming Stone"] = "gem-stone",
	["Loose Rock"] = "loose-rock",
	["Moonthistle"] = "moonthistle",
	["Mushroom"] = "mushroom",
	["Pebbles"] = "pebbles",
	["Rainblossom"] = "rainblossom",
	["Seashell"] = "seashell",
	["Starfall Petal"] = "starfall-petal",
	["Zephyr Bloom"] = "zephyr-bloom",
}
local SessionStartedAt = os.clock()
local SessionGold = PlayerSelectors.getLocalAccount().gold
local SessionPlants = 0
local SessionWatered = 0
local SessionHarvests = 0
local SessionForage = 0
local SessionSales = 0
local SessionSeeds = 0
local SessionRewards = 0
local SessionChests = 0
local SessionGifts = 0
local FarmStatus = "Idle"
local ForageStatus = "Idle"
local SupplyStatus = "Idle"
local ChestStatus = "Idle"
local GiftStatus = "Idle"
local Fishing = {
	Utilities = require(Shared.utilities.fishing),
	Data = require(Shared.data.fishing),
	Water = require(Shared.data["fishing-water"]),
	Atom = require(Client.store["fishing-atom"]).fishingAtom,
	Runtime = require(Client.store["fishing-minigame-runtime-atom"]).fishingMinigameRuntimeAtom,
	Runner = require(Client.utilities["fishing-minigame-runner"]),
	Controller = Flamework.resolveDependency("client/controllers/gameplay/items/fishing-rod-controller@FishingRodController"),
	Enabled = false,
	Generation = 0,
	Owned = false,
	SessionId = nil,
	Status = "Idle",
	Catches = 0,
	Treasures = 0,
	Pending = {},
	SpotNames = {"Nearest"},
	RodNames = {"Best owned"},
}
local Mining = {
	Utilities = require(Shared.utilities.mining),
	Data = require(Shared.data.mining),
	Types = require(Shared.types.mining),
	ChestData = require(Shared.data["mine-chests"]),
	Atom = require(Client.store["mining-atom"]).miningAtom,
	Runtime = require(Client.store["mining-minigame-runtime-atom"]).miningMinigameRuntimeAtom,
	Controller = Flamework.resolveDependency("client/controllers/gameplay/items/pickaxe-controller@PickaxeController"),
	Travel = require(Client.actions["travel-actions"]).sceneTravelAction,
	Enabled = false,
	Generation = 0,
	Owned = false,
	SessionId = nil,
	Status = "Idle",
	Nodes = 0,
	Chests = 0,
	RestartPending = false,
	Pending = {},
	PickaxeNames = {"Best owned"},
	NodeNames = {},
}
local Crafting = {
	Data = require(Shared.data.crafting),
	Utilities = require(Shared.utilities.crafting),
	Scene = require(Shared.utilities.furniture.scene),
	Enabled = false,
	Generation = 0,
	Status = "Idle",
	Recipes = {},
	RecipeStations = {},
	Completed = 0,
}
local Garden = {
	Data = require(Shared.data.gardens),
	SickleData = require(Shared.data.sickles),
	Sickle = require(Shared.utilities.sickle),
}
local Foraging = {
	Data = require(Shared.data.foraging),
	Ambience = require(Shared.store.ambience["ambience-atom"]).ambienceAtom,
	Conditions = require(Shared.data.ambience),
}
local Updates = {
	CodeAtom = require(Client.store["code-redeem-atom"]).codeRedeemAtom,
	Changelog = require(Shared.data.changelog),
	Forecast = Flamework.resolveDependency("client/controllers/gameplay/weather-forecast-controller@WeatherForecastController"),
	NextForecastAt = 0,
}
local Trading = {
	Conversation = require(Client.store["conversation-atom"]).conversationAtom,
	Window = require(Client.store["window-atom"]),
	Dialogue = Flamework.resolveDependency("client/controllers/presentation/dialogue-controller@DialogueController"),
	Owned = false,
	NpcId = nil,
	SellStatus = "Idle",
}

for _, Section in Updates.Changelog.CHANGELOG[1].sections do
	for _, Change in Section.changes do
		Updates.Code = Updates.Code or string.match(Change, "code%s+([A-Z0-9]+)")
	end
end

for ItemId, Data in ItemData do
	if Data.type == "seeds" and Data.use and CropRegistry.getCropData(Data.use.crop) then
		local Name = string.gsub(string.gsub(ItemId, "%-seeds$", ""), "%-", " ")

		table.insert(SeedNames, Name)
		SeedIds[Name] = ItemId
	end

	if ItemUtilities.canSellItem(Data) and Data.type ~= "tool" and Data.type ~= "seeds" then
		table.insert(ProtectedItemNames, ItemId)
	end
end

table.sort(SeedNames)
table.sort(ProtectedItemNames)

for ItemId in Fishing.Data.FISHING_ROD_STATS_BY_ITEM_ID do
	table.insert(Fishing.RodNames, ItemId)
end

for ItemId in Mining.Data.PICKAXE_STATS_BY_ITEM_ID do
	table.insert(Mining.PickaxeNames, ItemId)
end

for NodeId in Mining.Data.mineNodes do
	table.insert(Mining.NodeNames, NodeId)
end

for _, Area in Fishing.Water.MAIN_MAP_OCEAN_FISHING_AREAS do
	table.insert(Fishing.SpotNames, Area.id)
end

for StationId, Station in Crafting.Data.CRAFTING_STATIONS do
	for _, Tab in Station.tabs do
		for _, Recipe in Tab.recipes do
			table.insert(Crafting.Recipes, Recipe.id)
			Crafting.RecipeStations[Recipe.id] = StationId
		end
	end
end

table.sort(Mining.NodeNames)
table.sort(Crafting.Recipes)
table.sort(Fishing.RodNames)
table.sort(Mining.PickaxeNames)

-- Functions
local function GetCharacter()
	local Character = LocalPlayer.Character

	if not Character then
		return
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	local RootPart = Character:FindFirstChild("HumanoidRootPart")

	if not Humanoid or not RootPart or Humanoid.Health <= 0 then
		return
	end

	return Character, Humanoid, RootPart
end

local function IsReady()
	local Scene = ActiveScene.activeSceneStateAtom()

	return not Library.Unloaded and Scene.sceneId ~= nil and Scene.epoch ~= nil and not WorldInteractionsBlocked() and not SceneReplica.sceneCommandsBlockedAtom() and GetCharacter() ~= nil
end

local function GetComponent(Entity, Name)
	for _, Component in Entity.components or {} do
		if Component.type == Name then
			return Component
		end
	end
end

local function GetObjectPosition(Id)
	local Object = Sugar.Renderer.query:get(Id)

	if Object then
		return Object:getPosition()
	end

	local Node = SceneReplica.getAuthoritativeScene().nodesById[Id]

	if Node and Node.parentId == "folder/forageables" then
		return Node.entity.position
	end
end

local function CountItem(ItemId)
	local Account = PlayerSelectors.getLocalAccount()
	local Quantity = 0

	if not Account then
		return Quantity
	end

	for _, Container in {Account.toolbar, Account.inventory} do
		for _, Slot in Container do
			if Slot.itemId == ItemId then
				Quantity += Slot.quantity
			end
		end
	end

	return Quantity
end

local function GetSeedSlot()
	local Account = PlayerSelectors.getLocalAccount()
	local ItemId = SeedIds[Options.Seed.Value]

	if not Account or not ItemId then
		return
	end

	for _, ContainerName in {"toolbar", "inventory"} do
		for Index, Slot in Account[ContainerName] do
			if Slot.itemId == ItemId and Slot.quantity > 0 then
				return ContainerName, tonumber(Index), ItemData[ItemId].use.crop
			end
		end
	end
end

local function WaitForResult(Check, Active)
	local Deadline = os.clock() + 2.5

	while Active() and IsReady() and os.clock() < Deadline do
		local Scene = ActiveScene.activeSceneStateAtom()

		if MovementBusy and (LocalPlayer.Character ~= MovementCharacter or Scene.sceneId ~= MovementSceneId or Scene.epoch ~= MovementSceneEpoch) then
			return false
		end

		if Check() then
			return true
		end

		task.wait(0.1)
	end

	return false
end

local function MoveCharacter(Position)
	local Character, _, RootPart = GetCharacter()

	if not Character then
		return false
	end

	local Center = Position + Vector2.new(0, Sugar.DEFAULT_CHARACTER_CELL_SIZE.Y / 2)
	local WorldPosition = Sugar.toRoblox({position = Center}).position

	Character:PivotTo(CFrame.new(WorldPosition.X, RootPart.Position.Y, WorldPosition.Z) * Character:GetPivot().Rotation)
	RootPart.AssemblyLinearVelocity = Vector3.zero
	RootPart.AssemblyAngularVelocity = Vector3.zero

	return true
end

local function RestoreMovement(Force)
	local Scene = ActiveScene.activeSceneStateAtom()
	local Character = MovementCharacter
	local Pivot = MovementPivot

	if
		Character and Pivot and LocalPlayer.Character == Character
		and Scene.sceneId == MovementSceneId and Scene.epoch == MovementSceneEpoch
		and (Force or Toggles.ReturnAfterAction.Value)
	then
		Character:PivotTo(Pivot)
		local RootPart = Character:FindFirstChild("HumanoidRootPart")

		if RootPart then
			RootPart.AssemblyLinearVelocity = Vector3.zero
		end
	end

	MovementCharacter = nil
	MovementPivot = nil
	MovementSceneId = nil
	MovementSceneEpoch = nil
	MovementBusy = false
end

local function BeginMovement(Position, Active)
	if MovementBusy or not Active() or not IsReady() then
		return false
	end

	local Character = GetCharacter()
	local Scene = ActiveScene.activeSceneStateAtom()

	MovementBusy = true
	MovementCharacter = Character
	MovementPivot = Character:GetPivot()
	MovementSceneId = Scene.sceneId
	MovementSceneEpoch = Scene.epoch

	MoveCharacter(Position)
	task.wait(Options.ActionDelay.Value)

	local CurrentScene = ActiveScene.activeSceneStateAtom()

	if
		not Active() or not IsReady() or LocalPlayer.Character ~= Character
		or CurrentScene.sceneId ~= Scene.sceneId or CurrentScene.epoch ~= Scene.epoch
	then
		RestoreMovement(true)
		return false
	end

	return true
end

local function CanRetry(Id)
	return not FailedTargets[Id] or os.clock() >= FailedTargets[Id]
end

local function UpdateWalkSpeed()
	local _, Humanoid = GetCharacter()

	if not Humanoid then
		return
	end

	if WalkSpeedHumanoid ~= Humanoid then
		if WalkSpeedConnection then
			WalkSpeedConnection:Disconnect()
		end

		WalkSpeedHumanoid = Humanoid
		WalkSpeedConnection = Humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
			if not Library.Unloaded and Toggles.WalkSpeedEnabled.Value and LocalPlayer.Character == Humanoid.Parent then
				UpdateWalkSpeed()
			end
		end)
	end

	if Toggles.WalkSpeedEnabled.Value then
		local State = PlayerState.getPlayerState(LocalPlayer)

		if LocalPlayerLock().lockCount > 0 or (State and State.lockCount > 0) then
			return
		end

		if not OriginalWalkSpeeds[Humanoid] then
			OriginalWalkSpeeds[Humanoid] = Humanoid.WalkSpeed
		end

		if Humanoid.WalkSpeed ~= Options.WalkSpeed.Value then
			Humanoid.WalkSpeed = Options.WalkSpeed.Value
		end
	elseif OriginalWalkSpeeds[Humanoid] then
		Humanoid.WalkSpeed = OriginalWalkSpeeds[Humanoid]
	end
end

local function SetAntiIdle(Enabled)
	if Enabled then
		for _, Connection in getconnections(LocalPlayer.Idled) do
			if Connection.Enabled then
				table.insert(IdleConnections, Connection)
				Connection:Disable()
			end
		end
	else
		for _, Connection in IdleConnections do
			Connection:Enable()
		end

		table.clear(IdleConnections)
	end
end

local function OpenDiscord()
	pcall(request, {
		Url = "http://127.0.0.1:6463/rpc?v=1",
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
			Origin = "https://discord.com",
		},
		Body = HttpService:JSONEncode({
			cmd = "INVITE_BROWSER",
			nonce = HttpService:GenerateGUID(false),
			args = {
				code = "cyjC3QejpG",
			},
		}),
	})
end

local function CopyDiscord()
	setclipboard("https://discord.gg/cyjC3QejpG")
	Library:Notify("Copied discord.gg/cyjC3QejpG", 3)
end

-- Farm Functions
local function GetCropTarget()
	local Position = CharacterPosition.getPlayerFeetPosition(LocalPlayer)
	local BestCrop = nil
	local BestAction = nil
	local BestPosition = nil
	local BestDistance = math.huge
	local Scene = SceneReplica.getAuthoritativeScene()
	local HasWateringCan = CountItem("watering-can") > 0

	for _, Crop in PlayerSelectors.getLocalCrops() do
		if not Scene.nodesById[Crop.id] or not CanRetry(Crop.id) then
			continue
		end

		local Data = CropRegistry.getCropData(Crop.type)
		local Action = nil

		if not Data then
			continue
		end

		if Toggles.HarvestCrops.Value and Crop.stage == CropStage.getCropStage(Data, "ripe") then
			Action = "Harvest"
		elseif Toggles.WaterCrops.Value and HasWateringCan and CropUtilities.canWaterCrop(Crop, Data) then
			Action = "Water"
		end

		local TargetPosition = Action and GetObjectPosition(Crop.id)

		if not TargetPosition then
			continue
		end

		local Distance = (TargetPosition - Position).Magnitude

		if Distance < BestDistance then
			BestCrop = Crop
			BestAction = Action
			BestPosition = TargetPosition
			BestDistance = Distance
		end
	end

	return BestCrop, BestAction, BestPosition
end

local function GetBestSickle()
	local BestId = nil
	local BestArea = 0

	for Id, Swing in Garden.SickleData.SICKLE_SWINGS_BY_ITEM_ID do
		local Area = Swing.pattern == "square" and (Swing.radius * 2 + 1) ^ 2 or 1 + 2 * Swing.radius * (Swing.radius + 1)

		if Area > BestArea and CountItem(Id) > 0 then
			BestId = Id
			BestArea = Area
		end
	end

	return BestId
end

local function UseCrop(Crop, Action, Position, Active)
	if not BeginMovement(Position, Active) then
		return
	end

	local CurrentCrop = PlayerSelectors.getLocalCropById(Crop.id)

	if not CurrentCrop then
		RestoreMovement(false)
		return
	end

	FarmStatus = `{Action}: {Crop.type}`
	local Targets = {CurrentCrop}

	if Action == "Harvest" then
		local Data = CropRegistry.getCropData(CurrentCrop.type)

		if CurrentCrop.stage ~= CropStage.getCropStage(Data, "ripe") or not Toggles.HarvestCrops.Value then
			RestoreMovement(false)
			return
		end

		local SickleId = Toggles.UseSickle.Value and GetBestSickle()

		if SickleId then
			Targets = Garden.Sickle.getRipeCropsInSickleSwing(PlayerSelectors.getLocalCrops(), CurrentCrop, Garden.Sickle.getSickleSwing(SickleId))
			Events.harvestCropsWithSickle(SceneContext.createSceneRequestContext("sickle-swing"), SickleId, Crop.id)
		else
			Events.harvestCrop(SceneContext.createSceneRequestContext("crop-harvest"), Crop.id)
		end
	else
		if not Toggles.WaterCrops.Value or not CropUtilities.canWaterCrop(CurrentCrop, CropRegistry.getCropData(CurrentCrop.type)) then
			RestoreMovement(false)
			return
		end

		Events.useToolOnCrop(SceneContext.createSceneRequestContext("crop-water"), "waterCrop", Crop.id)
	end

	local Confirmed = WaitForResult(function()
		if Action == "Water" then
			local Updated = PlayerSelectors.getLocalCropById(Crop.id)

			return Updated and Updated.watered == true
		end

		for _, Target in Targets do
			local Updated = PlayerSelectors.getLocalCropById(Target.id)

			if not Updated or Updated.timesHarvested > Target.timesHarvested or Updated.stage ~= Target.stage then
				return true
			end
		end

		return false
	end, Active)

	if Confirmed then
		if Action == "Harvest" then
			for _, Target in Targets do
				local Updated = PlayerSelectors.getLocalCropById(Target.id)

				if not Updated or Updated.timesHarvested > Target.timesHarvested or Updated.stage ~= Target.stage then
					SessionHarvests += 1
				end
			end
		else
			SessionWatered += 1
		end
	else
		FailedTargets[Crop.id] = os.clock() + 10
	end

	RestoreMovement(not Active())
end

local function GetCropLimit()
	local Account = PlayerSelectors.getLocalAccount()

	for _, Tier in Garden.Data.GARDEN_TIERS do
		if Account and Tier.id == Account.gardenTierId then
			return math.min(Options.CropLimit.Value, Tier.cropLimit)
		end
	end

	return 0
end

local function CanPlantTile(CropId, Tile)
	local Data = CropRegistry.getCropData(CropId)
	local Crop = {
		id = "caramel-plant-preview",
		type = CropId,
		position = Datastore.serializeVector2Position(Tile),
	}

	return Data and PlotPlacements.canPlacePlacement(LocalPlayer.UserId, CropUtilities.createCropPlacementState(Crop, Data))
end

local function FindFreeTile(CropId)
	local Plot = PlayerPlot.tryGetLocalPlayerPlot()
	local Data = CropRegistry.getCropData(CropId)

	if not Plot or not Data then
		return
	end

	local Size = PlotPlacements.getPlotContainerSize(LocalPlayer.UserId)

	for Y = 0, Size.Y - 1 do
		for X = 0, Size.X - 1 do
			local Tile = Vector2.new(X, Y)

			if not Grid.isFootprintWithinBounds(Tile, Data.gridSize, Size) then
				continue
			end

			if CanPlantTile(CropId, Tile) then
				return Tile, Grid.calculateCropWorldPosition(Tile, Plot.origin, Data.gridSize, Size)
			end
		end
	end
end

local function PlantCrop(Active)
	local Container, Index, CropId = GetSeedSlot()

	if not CropId then
		FarmStatus = "Waiting for seeds"
		return
	end

	local Tile, Position = FindFreeTile(CropId)

	if not Tile then
		FarmStatus = "Plot is full"
		return
	end

	if not BeginMovement(Position, Active) then
		return
	end

	local CurrentContainer, CurrentIndex, CurrentCropId = GetSeedSlot()

	if
		not Toggles.PlantCrops.Value or CurrentCropId ~= CropId
		or CurrentContainer ~= Container or CurrentIndex ~= Index
		or #PlayerSelectors.getLocalCrops() >= GetCropLimit()
	then
		RestoreMovement(false)
		return
	end

	if not CanPlantTile(CropId, Tile) then
		RestoreMovement(false)
		return
	end

	FarmStatus = `Planting: {CropId}`
	Events.placeCrop(SceneContext.createSceneRequestContext("crop-place"), CropId, Container, Index, Datastore.serializeVector2Position(Tile))

	local Confirmed = WaitForResult(function()
		for _, Crop in PlayerSelectors.getLocalCrops() do
			if Crop.type == CropId and Crop.position.x == Tile.X and Crop.position.y == Tile.Y then
				return true
			end
		end

		return false
	end, Active)

	if Confirmed then
		SessionPlants += 1
	else
		FarmStatus = "Planting was declined"
	end

	RestoreMovement(not Active())
end

-- Gathering Functions
local function CanForage()
	local State = Foraging.Ambience()

	if Toggles.ForageRainOnly.Value and State.weather ~= Foraging.Conditions.Weather.RAINY then
		return false, "Waiting for rain"
	end

	if Toggles.ForageNightOnly.Value and not Foraging.Conditions.isNightTimeOfDay(State.timeOfDay) then
		return false, "Waiting for evening or night"
	end

	return true
end

local function GetForageTarget()
	local Position = CharacterPosition.getPlayerFeetPosition(LocalPlayer)
	local BestId = nil
	local BestName = nil
	local BestPosition = nil
	local BestDistance = Options.ForageRadius.Value

	for Id, Node in SceneReplica.getAuthoritativeScene().nodesById do
		if Node.parentId ~= "folder/forageables" or not CanRetry(Id) then
			continue
		end

		local Identity = GetComponent(Node.entity, "ForageIdentity")
		local Interaction = GetComponent(Node.entity, "Interactable")
		local Selected = false

		if not Identity or not Interaction or not Interaction.enabled then
			continue
		end

		for Name, Enabled in Options.ForageTypes.Value do
			if Enabled and ForageIds[Name] == Identity.forageableId then
				Selected = true
				break
			end
		end

		local TargetPosition = Selected and GetObjectPosition(Id)

		if not TargetPosition then
			continue
		end

		local Distance = (TargetPosition - Position).Magnitude

		if Distance < BestDistance then
			BestId = Id
			BestName = Node.entity.name
			BestPosition = TargetPosition
			BestDistance = Distance
		end
	end

	return BestId, BestName, BestPosition
end

local function CollectForage(Id, Name, Position, Active)
	if not BeginMovement(Position, Active) then
		return
	end

	if not CanForage() or not SceneReplica.getAuthoritativeScene().nodesById[Id] then
		RestoreMovement(false)
		return
	end

	ForageStatus = `Collecting: {Name}`
	Events.pickupForageable(SceneContext.createSceneRequestContext("forage-pickup"), Id)

	local Confirmed = WaitForResult(function()
		return SceneReplica.getAuthoritativeScene().nodesById[Id] == nil
	end, Active)

	if Confirmed then
		SessionForage += 1
	else
		FailedTargets[Id] = os.clock() + 15
	end

	RestoreMovement(not Active())
end

-- Tool Functions
local function GetFishingRod()
	local Selected = Options.FishingRod.Value
	local BestId = nil
	local BestTier = -1

	for ItemId, Stats in Fishing.Data.FISHING_ROD_STATS_BY_ITEM_ID do
		if (Selected == "Best owned" or Selected == ItemId) and CountItem(ItemId) > 0 and Stats.tier > BestTier then
			BestId = ItemId
			BestTier = Stats.tier
		end
	end

	return BestId
end

local function GetPickaxe()
	local Selected = Options.MiningPickaxe.Value
	local BestId = nil
	local BestStats = nil

	for ItemId, Stats in Mining.Data.PICKAXE_STATS_BY_ITEM_ID do
		if (Selected == "Best owned" or Selected == ItemId) and CountItem(ItemId) > 0 and (not BestStats or Stats.tier > BestStats.tier) then
			BestId = ItemId
			BestStats = Stats
		end
	end

	return BestId, BestStats
end

local function ToolMovementValid(Active)
	local Scene = ActiveScene.activeSceneStateAtom()

	return Active() and MovementBusy and GetCharacter() == MovementCharacter and Scene.sceneId == MovementSceneId and Scene.epoch == MovementSceneEpoch
end

local function StopFishing()
	if Fishing.Owned then
		Fishing.Runner.setFishingMinigameUseHeld(false)
		Fishing.Controller:stopFishing(true)
		Fishing.Owned = false
		Fishing.SessionId = nil
	end
end

local function StopMining()
	if Mining.Owned then
		Mining.Controller:stopMining(true)
		Mining.Owned = false
		Mining.SessionId = nil
	end
end

-- Fishing Functions
local function GetFishingSpot()
	local Position = CharacterPosition.getPlayerFeetPosition(LocalPlayer)
	local BestStand = nil
	local BestCast = nil
	local BestId = nil
	local BestDistance = math.huge

	if not Position then
		return
	end

	for _, Area in Fishing.Water.MAIN_MAP_OCEAN_FISHING_AREAS do
		if Options.FishingSpot.Value ~= "Nearest" and Options.FishingSpot.Value ~= Area.id then
			continue
		end

		if not CanRetry(`fishing:{Area.id}`) then
			continue
		end

		if not Fishing.Water.isFishingCastTarget("main-map", Area.center) then
			continue
		end

		for Distance = 80, 160, 20 do
			for Direction = 0, 7 do
				local Angle = Direction * math.pi / 4
				local Stand = Area.center + Vector2.new(math.cos(Angle), math.sin(Angle)) * Distance
				local Center = Stand + Vector2.new(0, Sugar.DEFAULT_CHARACTER_CELL_SIZE.Y / 2)
				local TravelDistance = (Stand - Position).Magnitude

				if Fishing.Water.isWaterPosition(Stand) or Fishing.Utilities.getOceanFishingCastDistanceViolation(Area.center, Center) then
					continue
				end

				if TravelDistance < BestDistance then
					BestStand = Stand
					BestCast = Area.center
					BestId = Area.id
					BestDistance = TravelDistance
				end
			end
		end
	end

	return BestStand, BestCast, BestId
end

local function Fish(Active)
	local RodId = GetFishingRod()

	if not RodId then
		Fishing.Status = "Craft or equip a fishing rod"
		return
	end

	local Stand, Cast, SpotId = GetFishingSpot()

	if not Stand then
		Fishing.Status = "Waiting for a fishing spot"
		return
	end

	if not BeginMovement(Stand, Active) then
		return
	end

	if Fishing.Utilities.getOceanFishingCastDistanceViolation(Cast, CharacterPosition.getPlayerCenterPosition(LocalPlayer)) then
		Fishing.Status = "Fishing spot is obstructed"
		RestoreMovement(false)
		return
	end

	Fishing.Owned = true
	Fishing.Controller:startFishing(RodId)
	Fishing.Status = `Casting: {SpotId}`
	Fishing.Controller.actions.cast:run(Cast)
	Fishing.SessionId = Fishing.Atom().sessionId

	if Fishing.SessionId then
		Fishing.Pending[Fishing.SessionId] = SpotId
	end

	local Deadline = os.clock() + 75

	while ToolMovementValid(Active) and os.clock() < Deadline do
		local State = Fishing.Atom()

		if State.phase == "ready" or State.phase == "inactive" then
			break
		end

		if State.phase == "bite" then
			Fishing.Status = "Hooking fish"
			Fishing.Controller:hookFish()
		elseif State.phase == "minigame" then
			local Runtime = Fishing.Runtime()
			local Simulation = Runtime.state

			if Simulation then
				local Target = Simulation.fish.center + Simulation.fish.velocity * 0.1
				local PredictedBar = Simulation.barCenter + Simulation.barVelocity * 0.12

				Fishing.Runner.setFishingMinigameUseHeld(PredictedBar > Target)
				Fishing.Status = `Reeling: {math.floor(Simulation.progress * 100)}%`
			end
		elseif State.phase == "settling" then
			Fishing.Status = "Waiting for catch"
		end

		RunService.RenderStepped:Wait()
	end

	StopFishing()
	RestoreMovement(not Active())
end

-- Mining Functions
local function GetMineChest()
	local Floor = Mining.Utilities.getMineFloorFromSceneId(ActiveScene.activeSceneIdAtom())

	if not Floor then
		return
	end

	local Id = Mining.ChestData.getMineChestObjectId(Floor)
	local Node = SceneReplica.getAuthoritativeScene().nodesById[Id]
	local Interaction = Node and GetComponent(Node.entity, "Interactable")
	local Action = Interaction and Interaction.action
	local Position = Node and GetObjectPosition(Id)

	if Interaction and Interaction.enabled ~= false and Action and Action.type == "custom" and Action.eventId == Mining.ChestData.MINE_CHEST_INTERACT_EVENT_ID and Position then
		return Id, Position, Action
	end
end

local function OpenMineChest(Id, Position, Action, Active)
	local Key = `mine-chest:{ActiveScene.activeSceneStateAtom().epoch}:{Id}`

	if not CanRetry(Key) then
		Mining.Status = "Waiting to retry mine chest"
		return
	end

	if not BeginMovement(Position + Vector2.new(0, 20), Active) then
		return
	end

	local Sprite = Sugar.Renderer.query:get(Id)
	local CurrentId = GetMineChest()

	if CurrentId ~= Id or not Sprite then
		RestoreMovement(not Active())
		return
	end

	Mining.Status = "Opening mine chest"
	Sugar.events.interaction:Fire(Action, Sprite)

	if WaitForResult(function()
		local Node = SceneReplica.getAuthoritativeScene().nodesById[Id]
		local Interaction = Node and GetComponent(Node.entity, "Interactable")

		return not Node or not Interaction or Interaction.enabled == false
	end, Active) then
		Mining.Chests += 1
		Mining.Status = "Mine chest collected"
	elseif Active() then
		Mining.Status = "Mine chest was not confirmed"
		FailedTargets[Key] = os.clock() + 15
	end

	RestoreMovement(not Active())
end

local function GetMineTarget(Stats)
	local Position = CharacterPosition.getPlayerFeetPosition(LocalPlayer)
	local BestId = nil
	local BestPosition = nil
	local BestName = nil
	local BestScore = math.huge

	if not Position then
		return
	end

	for Id, Node in SceneReplica.getAuthoritativeScene().nodesById do
		local Identity = GetComponent(Node.entity, "MineIdentity")
		local Data = Identity and Mining.Utilities.getMineNodeData(Identity.nodeId)

		if not Data or Stats.tier < Data.minPickaxeTier or not Options.MiningNodes.Value[Identity.nodeId] or not CanRetry(Id) then
			continue
		end

		local TargetPosition = GetObjectPosition(Id)

		if not TargetPosition then
			continue
		end

		local Score = (TargetPosition - Position).Magnitude

		if Options.MiningPriority.Value == "Ore first" and Identity.nodeId == "stone" then
			Score += 100000
		end

		if Score < BestScore then
			BestId = Id
			BestPosition = TargetPosition
			BestName = Identity.nodeId
			BestScore = Score
		end
	end

	return BestId, BestPosition, BestName
end

local function TravelMine(Destination, Active)
	local Position = nil

	if Destination == "surface" then
		Position = GetObjectPosition("mine-elevator")
	elseif ActiveScene.activeSceneIdAtom() == "main-map" then
		Position = Mining.Data.MINE_ENTRY_WORLD_POSITION
	else
		for Id, Node in SceneReplica.getAuthoritativeScene().nodesById do
			local Interaction = GetComponent(Node.entity, "Interactable")

			if Interaction and Interaction.action and Interaction.action.type == "scene" and Interaction.action.sceneId == Destination then
				Position = GetObjectPosition(Id)
				break
			end
		end
	end

	if not Position or not BeginMovement(Position, Active) then
		return
	end

	Mining.Status = Destination == "surface" and "Returning to surface" or "Entering mine"
	Mining.Travel:run(Destination)

	local Deadline = os.clock() + 12

	while Active() and os.clock() < Deadline do
		local SceneId = ActiveScene.activeSceneIdAtom()

		if (Destination == "surface" and SceneId == "main-map") or (Destination ~= "surface" and SceneId == Destination) then
			break
		end

		task.wait(0.1)
	end

	RestoreMovement(false)

	return ActiveScene.activeSceneIdAtom() == (Destination == "surface" and "main-map" or Destination)
end

local function Mine(Active)
	local PickaxeId, Stats = GetPickaxe()

	if not PickaxeId then
		Mining.Status = "Craft or equip a pickaxe"
		return
	end

	local Id, Position, Name = GetMineTarget(Stats)

	if not Id then
		Mining.Status = "Waiting for matching nodes"
		local NextScene = Mining.Utilities.getNextMineSceneId(ActiveScene.activeSceneIdAtom())

		if Toggles.MineDescend.Value and NextScene then
			TravelMine(NextScene, Active)
		end

		return
	end

	if not BeginMovement(Position + Vector2.new(0, 12), Active) then
		return
	end

	Mining.Owned = true
	Mining.Status = `Mining: {Name}`
	Mining.Controller:startMining(PickaxeId)
	Mining.Controller:tryStartMining(Id)
	Mining.SessionId = Mining.Atom().sessionId

	local Deadline = os.clock() + 65
	local NextStrikeAt = 0
	local StartedAt = os.clock()

	while ToolMovementValid(Active) and os.clock() < Deadline do
		local State = Mining.Atom()

		if State.phase == "minigame" then
			Mining.SessionId = State.sessionId
			Mining.Pending[State.sessionId] = true
			local Runtime = Mining.Runtime()
			local Marker = (workspace:GetServerTimeNow() - Runtime.startTime) * State.config.markerSpeed
			local Offset = (Marker - State.config.zoneStart) % 1

			if os.clock() >= NextStrikeAt and Offset >= State.config.zoneSize * 0.35 and Offset <= State.config.zoneSize * 0.65 then
				Mining.Controller:strikeIfMining()
				NextStrikeAt = os.clock() + Mining.Data.MINING_STRIKE_MIN_INTERVAL_SECONDS + 0.03
			end
		elseif os.clock() - StartedAt > 0.5 and State.phase ~= "pending" then
			break
		end

		RunService.RenderStepped:Wait()
	end

	StopMining()

	if SceneReplica.getAuthoritativeScene().nodesById[Id] then
		FailedTargets[Id] = os.clock() + 5
	end

	RestoreMovement(not Active())
end

-- Crafting Functions
local function GetWorkbench(StationId)
	local Account = PlayerSelectors.getLocalAccount()
	local Scene = SceneReplica.getAuthoritativeScene()

	for Id, Node in Scene.nodesById do
		if Crafting.Utilities.getWorldCraftingStationId(Node.entity.objectRegistryId or "") == StationId then
			local Position = GetObjectPosition(Id)

			if Position then
				return {kind = "world", objectId = Id}, Position
			end
		end
	end

	for _, House in Account and Account.houses.entries or {} do
		for _, Furniture in House.furniture do
			local Definition = Crafting.Scene.getPlacedFurnitureDefinition(Furniture)

			if Furniture.ownerUserId == LocalPlayer.UserId and Definition and Definition.craftingStationId == StationId then
				local Position = GetObjectPosition(Furniture.id)

				if Position then
					return {kind = "placement", placementId = Furniture.id}, Position
				end
			end
		end
	end
end

local function CraftItem(Active)
	local StationId = Crafting.RecipeStations[Options.ToolRecipe.Value]
	local Recipe = StationId and Crafting.Utilities.getCraftingRecipe(StationId, Options.ToolRecipe.Value)
	local Account = PlayerSelectors.getLocalAccount()

	if not Recipe or not Account then
		return
	end

	if CountItem(Recipe.rewards[1].itemId) >= Options.CraftTarget.Value then
		Crafting.Status = "Crafting target reached"
		return
	end

	for _, Ingredient in Recipe.ingredients do
		local Missing = Ingredient.quantity - CountItem(Ingredient.itemId)

		if Missing > 0 then
			Crafting.Status = `Need {Missing} {Ingredient.itemId}`
			return
		end
	end

	if Recipe.cost.currency ~= "gold" or Account.gold - Recipe.cost.amount < Options.GoldReserve.Value then
		Crafting.Status = "Gold reserve reached"
		return
	end

	local Target, Position = GetWorkbench(StationId)

	if not Target then
		Crafting.Status = StationId == "tool-workbench" and "Visit your tool workbench" or "Visit your furniture workbench"
		return
	end

	if not BeginMovement(Position + Vector2.new(0, 20), Active) then
		return
	end

	Crafting.Status = "Crafting item"
	local Before = CountItem(Recipe.rewards[1].itemId)
	local Success, Resolved, Response = pcall(function()
		return Network.Functions.craftItem:invokeWithTimeout(10, {
			context = SceneContext.createSceneRequestContext("craft-item"),
			target = Target,
			recipeId = Recipe.id,
		}):await()
	end)

	if Active() and Success and Resolved and Response and Response.ok then
		if WaitForResult(function()
			return CountItem(Recipe.rewards[1].itemId) > Before
		end, Active) then
			Crafting.Completed += 1
			Crafting.Status = "Item crafted"
		else
			Crafting.Status = "Craft was not confirmed"
		end
	elseif Active() then
		Crafting.Status = Response and Response.reason or "Craft request failed"
	end

	RestoreMovement(not Active())
end

-- Trading Functions
function Trading.Close()
	if not Trading.Owned then
		return
	end

	local State = Trading.Conversation()

	if not State.active or State.npcId == Trading.NpcId then
		Trading.Window.windowAtom(Trading.Window.Window.NONE)
		Trading.Dialogue:abortActiveConversation()
	end

	Trading.Owned = false
	Trading.NpcId = nil
end

function Trading.Open(NpcId, ChoiceId, WindowId, Active)
	local Node = SceneReplica.getAuthoritativeScene().nodesById[NpcId]
	local Interaction = Node and GetComponent(Node.entity, "Interactable")
	local Object = Sugar.Renderer.query:get(NpcId)

	if not Object or not Interaction or Interaction.enabled == false or not BeginMovement(Object:getPosition() + Vector2.new(0, 20), Active) then
		return false
	end

	Trading.Owned = true
	Trading.NpcId = NpcId
	Sugar.events.interaction:Fire(Interaction.action, Object)

	local Deadline = os.clock() + 12
	local Selected = false

	while ToolMovementValid(Active) and os.clock() < Deadline do
		if Trading.Window.windowAtom() == WindowId then
			return true
		end

		local State = Trading.Conversation()

		if State.active and State.npcId == NpcId then
			if #State.choices > 0 and not Selected then
				for Index, Choice in State.choices do
					if Choice.id == ChoiceId and not Choice.disabled then
						Trading.Dialogue:selectChoice(Index - 1)
						Selected = true
						break
					end
				end

				if not Selected then
					break
				end
			elseif #State.choices == 0 and not Selected then
				Trading.Dialogue:advance()
			end
		end

		task.wait(0.2)
	end

	Trading.Close()
	RestoreMovement(not Active())

	return false
end

function Trading.Wait(Check, Active)
	local Deadline = os.clock() + 4

	while ToolMovementValid(Active) and os.clock() < Deadline do
		if Check() then
			return true
		end

		task.wait(0.1)
	end

	return false
end

local function GetSellSlots()
	local Account = PlayerSelectors.getLocalAccount()
	local Totals = {}
	local Slots = {}
	local CraftIngredients = {}

	if not Account then
		return Slots
	end

	if Crafting.Enabled then
		local StationId = Crafting.RecipeStations[Options.ToolRecipe.Value]
		local Recipe = StationId and Crafting.Utilities.getCraftingRecipe(StationId, Options.ToolRecipe.Value)

		if Recipe and CountItem(Recipe.rewards[1].itemId) < Options.CraftTarget.Value then
			for _, Ingredient in Recipe.ingredients do
				CraftIngredients[Ingredient.itemId] = true
			end
		end
	end

	for _, Slot in Account.inventory do
		Totals[Slot.itemId] = (Totals[Slot.itemId] or 0) + Slot.quantity
	end

	for Index, Slot in Account.inventory do
		local Data = ItemUtilities.getItemData(Slot.itemId)

		if not ItemUtilities.canSellItem(Data) or Data.type == "tool" or Data.type == "seeds" then
			continue
		end

		if CraftIngredients[Slot.itemId] or Options.ProtectedItems.Value[Slot.itemId] or (Toggles.KeepRare.Value and Data.rarity ~= "common" and Data.rarity ~= "uncommon") then
			continue
		end

		local Category = Data.type == "crop" and "Crops" or Data.type == "fish" and "Fish" or Data.type == "material" and "Materials"

		if not Category or not Options.SellCategories.Value[Category] or Totals[Slot.itemId] - Slot.quantity < Options.KeepItems.Value then
			continue
		end

		Totals[Slot.itemId] -= Slot.quantity
		table.insert(Slots, tonumber(Index))
	end

	return Slots
end

local function SellItems(Active)
	local Slots = GetSellSlots()

	if #Slots == 0 then
		Trading.SellStatus = "No eligible inventory items"
		return
	end

	Trading.SellStatus = "Visiting Kalt"

	if not Trading.Open("kalt", "sell_select", Trading.Window.Window.INVENTORY, Active) then
		Trading.SellStatus = "Kalt is unavailable"
		return
	end

	Slots = GetSellSlots()
	local Before = PlayerSelectors.getLocalAccount().gold

	if #Slots > 0 and Active() then
		Trading.SellStatus = "Selling inventory"
		Events.sellInventorySlots(Slots)

		if Trading.Wait(function()
			local Account = PlayerSelectors.getLocalAccount()

			return Account and Account.gold > Before
		end, Active) then
			SessionSales += 1
			Trading.SellStatus = "Inventory sold"
		elseif Active() then
			Trading.SellStatus = "Sale was not confirmed"
		end
	end

	Trading.Close()
	RestoreMovement(not Active())
end

function Trading.Restock(Active)
	local ItemId = SeedIds[Options.Seed.Value]
	local Data = ItemId and ItemUtilities.getItemData(ItemId)

	if not Data then
		return
	end

	local Needed = math.max(0, Options.SeedReserve.Value - CountItem(ItemId))

	if Needed <= 0 then
		SupplyStatus = "Seeds stocked"
		return
	end

	for _ = 1, Needed do
		if not ToolMovementValid(Active) or SeedIds[Options.Seed.Value] ~= ItemId then
			return
		end

		if CountItem(ItemId) >= Options.SeedReserve.Value then
			SupplyStatus = "Seeds stocked"
			return
		end

		local Account = PlayerSelectors.getLocalAccount()
		local Stock = CropShop.cropShopAtom()
		local Remaining = 0

		if not Account then
			return
		end

		for _, Entry in Stock.stock do
			if Entry.itemId == ItemId then
				Remaining = CropShop.getCropShopRemainingStock(Stock, Entry, Account.cropShopPurchases)
				break
			end
		end

		if Remaining <= 0 then
			SupplyStatus = "Waiting for restock"
			return
		end

		local Quote = ShopPrice.quoteCropShopPrice(Data, Account, Remaining)

		if not Quote or not Quote.gold or Quote.gold <= 0 then
			SupplyStatus = "Seed price unavailable"
			return
		end

		if Account.gold - Quote.gold < Options.GoldReserve.Value then
			SupplyStatus = "Gold reserve reached"
			return
		end

		local Purchases = Account.cropShopPurchases
		local BeforePurchased = Purchases and Purchases.restockAt == Stock.nextRestockAt and (Purchases.quantities[ItemId] or 0) or 0
		local Confirmed = false
		local Deadline = os.clock() + 4

		SupplyStatus = "Buying seeds"
		Signals.buyShopItem:Fire({
			shop = "crop",
			itemId = ItemId,
			quantity = 1,
			currency = "gold",
			expectedPrice = Quote.gold,
		})

		while Active() and os.clock() < Deadline do
			local Current = PlayerSelectors.getLocalAccount()
			local Updated = Current and Current.cropShopPurchases

			if Updated and Updated.restockAt == Stock.nextRestockAt and (Updated.quantities[ItemId] or 0) > BeforePurchased then
				Confirmed = true
				break
			end

			task.wait(0.1)
		end

		if not Active() then
			return
		end

		if not Confirmed then
			SupplyStatus = "Purchase was not confirmed"
			return
		end

		SessionSeeds += 1
		task.wait(0.3)
	end

	SupplyStatus = CountItem(ItemId) >= Options.SeedReserve.Value and "Seeds stocked" or "Refilling seeds"
end

local function BuySeeds(Active)
	local ItemId = SeedIds[Options.Seed.Value]
	local Account = PlayerSelectors.getLocalAccount()
	local Data = ItemId and ItemUtilities.getItemData(ItemId)
	local Quote = Account and Data and ShopPrice.quoteCropShopPrice(Data, Account, 1)

	if not Quote or not Quote.gold then
		SupplyStatus = "Seed price unavailable"
		return
	end

	if CountItem(ItemId) >= Options.SeedReserve.Value then
		SupplyStatus = "Seeds stocked"
		return
	end

	if Account.gold - Quote.gold < Options.GoldReserve.Value then
		SupplyStatus = "Gold reserve reached"
		return
	end

	SupplyStatus = "Visiting Maya"

	if not Trading.Open("maya", "open_seed_shop", Trading.Window.Window.CROP_SHOP, Active) then
		SupplyStatus = "Maya is unavailable"
		return
	end

	Trading.Restock(Active)
	Trading.Close()
	RestoreMovement(not Active())
end

-- Treasure Functions
local function GetChestTarget()
	local Account = PlayerSelectors.getLocalAccount()
	local Position = CharacterPosition.getPlayerFeetPosition(LocalPlayer)
	local BestChest = nil
	local BestPosition = nil
	local BestDistance = math.huge

	if not Account or not Position then
		return
	end

	for _, Chest in TreasureChests.TREASURE_CHESTS do
		if table.find(Account.claimedTreasureChestIds, Chest.id) or not CanRetry(Chest.id) then
			continue
		end

		local TargetPosition = GetObjectPosition(TreasureChests.getTreasureChestObjectId(Chest.id))

		if not TargetPosition then
			continue
		end

		local Distance = (TargetPosition - Position).Magnitude

		if Distance < BestDistance then
			BestChest = Chest
			BestPosition = TargetPosition
			BestDistance = Distance
		end
	end

	return BestChest, BestPosition
end

local function OpenChest(Chest, Position, Active)
	if not BeginMovement(Position, Active) then
		return
	end

	local Account = PlayerSelectors.getLocalAccount()

	if not Account or table.find(Account.claimedTreasureChestIds, Chest.id) then
		RestoreMovement(false)
		return
	end

	ChestStatus = `Opening: {Chest.id}`
	Events.claimTreasureChest(SceneContext.createSceneRequestContext("treasure-chest"), Chest.id)

	if WaitForResult(function()
		local Current = PlayerSelectors.getLocalAccount()

		return Current and table.find(Current.claimedTreasureChestIds, Chest.id) ~= nil
	end, Active) then
		SessionChests += 1
	else
		FailedTargets[Chest.id] = os.clock() + 20
	end

	RestoreMovement(not Active())
end

-- Reward Functions
local function ClaimGifts(Active)
	local Daily = DailyRewardUi()

	if Toggles.ClaimDaily.Value and Daily and Daily.claimStatus == "idle" and Active() and IsReady() then
		GiftStatus = "Claiming daily reward"
		DailyRewardController:claim()

		if WaitForResult(function()
			local Updated = DailyRewardUi()

			return Updated and Updated.day == Daily.day and Updated.claimStatus == "claimed"
		end, Active) then
			SessionGifts += 1
		end
	end

	if not Toggles.ClaimMail.Value or not Active() or not IsReady() then
		return
	end

	for _, Mail in PlayerSelectors.localMailAtom() do
		if not Active() or not IsReady() or not Toggles.ClaimMail.Value then
			break
		end

		if Mail.claimed then
			continue
		end

		GiftStatus = "Claiming mail attachments"
		Signals.claimMailAttachments:Fire(Mail.id)

		if WaitForResult(function()
			for _, Updated in PlayerSelectors.localMailAtom() do
				if Updated.id == Mail.id then
					return Updated.claimed == true
				end
			end

			return false
		end, Active) then
			SessionGifts += 1
		end

		task.wait(0.3)
	end

	GiftStatus = "Rewards up to date"
end

-- Visual Functions
local function ClearMarkers()
	for _, Label in MarkerLabels do
		Label:Destroy()
	end

	table.clear(MarkerLabels)
	table.clear(MarkerTargets)
	MarkerNextRefresh = 0
end

local function UpdateMarkers()
	local Camera = workspace.CurrentCamera
	local Position = CharacterPosition.getPlayerFeetPosition(LocalPlayer)
	local Account = PlayerSelectors.getLocalAccount()
	local Scene = SceneReplica.getAuthoritativeScene()
	local SceneState = ActiveScene.activeSceneStateAtom()

	if not Camera or not Position or not Account then
		ClearMarkers()
		return
	end

	if os.clock() >= MarkerNextRefresh or SceneState.epoch ~= MarkerSceneEpoch then
		local Targets = {}

		if Options.MarkerTypes.Value["Rare forage"] then
			for _, Id in Scene.childrenByParentId["folder/forageables"] or {} do
				local Node = Scene.nodesById[Id]
				local Identity = Node and GetComponent(Node.entity, "ForageIdentity")

				if Identity and (Identity.forageableId == "dewcap" or Identity.forageableId == "gem-stone") then
					table.insert(Targets, {
						Id = Id,
						Name = Node.entity.name,
						Color = Color3.fromRGB(184, 156, 222),
					})
				end
			end
		end

		if Options.MarkerTypes.Value["Ripe crops"] then
			for _, Crop in PlayerSelectors.getLocalCrops() do
				local Data = CropRegistry.getCropData(Crop.type)

				if Data and Crop.stage == CropStage.getCropStage(Data, "ripe") then
					table.insert(Targets, {
						Id = Crop.id,
						Name = Crop.type,
						Color = Color3.fromRGB(153, 207, 156),
					})
				end
			end
		end

		if Options.MarkerTypes.Value["Treasure chests"] then
			for _, Chest in TreasureChests.TREASURE_CHESTS do
				if not table.find(Account.claimedTreasureChestIds, Chest.id) then
					table.insert(Targets, {
						Id = TreasureChests.getTreasureChestObjectId(Chest.id),
						Name = "Treasure chest",
						Color = Library.Scheme.AccentColor,
					})
				end
			end
		end

		if Options.MarkerTypes.Value["Mine nodes"] then
			for Id, Node in Scene.nodesById do
				local Identity = GetComponent(Node.entity, "MineIdentity")

				if Identity then
					table.insert(Targets, {
						Id = Id,
						Name = Identity.nodeId,
						Color = Color3.fromRGB(145, 187, 214),
					})
				end
			end
		end

		MarkerTargets = Targets
		MarkerNextRefresh = os.clock() + 0.5
		MarkerSceneEpoch = SceneState.epoch
	end

	local VisibleTargets = {}

	for _, Target in MarkerTargets do
		Target.Position = GetObjectPosition(Target.Id)

		if not Target.Position then
			continue
		end

		local WorldPosition = Sugar.toRoblox({position = Target.Position}).position
		local ScreenPosition, Visible = Camera:WorldToViewportPoint(WorldPosition)

		if Visible and (Target.Position - Position).Magnitude <= Options.MarkerRadius.Value then
			Target.ScreenPosition = ScreenPosition
			Target.Distance = (Target.Position - Position).Magnitude
			table.insert(VisibleTargets, Target)
		end
	end

	table.sort(VisibleTargets, function(First, Second)
		return First.Distance < Second.Distance
	end)

	local Count = math.min(#VisibleTargets, Options.MarkerLimit.Value)

	for Index = 1, Count do
		local Target = VisibleTargets[Index]
		local Label = MarkerLabels[Index]

		if not Label then
			Label = Instance.new("TextLabel")
			Label.Name = "CaramelResourceMarker"
			Label.AnchorPoint = Vector2.new(0.5, 1)
			Label.Size = UDim2.fromOffset(160, 22)
			Label.BackgroundColor3 = Library.Scheme.BackgroundColor
			Label.BackgroundTransparency = 0.2
			Label.BorderSizePixel = 0
			Label.FontFace = FontFace
			Label.TextSize = 12
			Label.ZIndex = 5
			Label.Parent = Library.ScreenGui
			MarkerLabels[Index] = Label
		end

		Label.Position = UDim2.fromOffset(Target.ScreenPosition.X, Target.ScreenPosition.Y - 12)
		Label.Text = Target.Name
		Label.TextColor3 = Target.Color
		Label.Visible = true
	end

	for Index = #MarkerLabels, Count + 1, -1 do
		MarkerLabels[Index]:Destroy()
		MarkerLabels[Index] = nil
	end
end

-- Teleport Functions
local function RefreshLandmarks()
	LandmarkNames = {"My Plot"}
	table.clear(LandmarkIds)

	for Id, Node in SceneReplica.getAuthoritativeScene().nodesById do
		if Node.parentId == "folder/npcs" and Node.entity.name and GetObjectPosition(Id) then
			local Name = Node.entity.name

			if not LandmarkIds[Name] then
				table.insert(LandmarkNames, Name)
				LandmarkIds[Name] = Id
			end
		end
	end

	table.sort(LandmarkNames)

	if Options.Landmark then
		Options.Landmark:SetValues(LandmarkNames)
		Options.Landmark:SetValue("My Plot")
	end
end

local function TravelTo(Position)
	if MovementBusy or not IsReady() then
		Library:Notify("Travel is busy", 3)
		return
	end

	MoveCharacter(Position)
end

local function TravelToLandmark()
	if Options.Landmark.Value == "My Plot" then
		if not MovementBusy and IsReady() then
			Events.teleportToAssignedPlot:fire()
		end

		return
	end

	local Id = LandmarkIds[Options.Landmark.Value]
	local Position = Id and GetObjectPosition(Id)

	if Position then
		TravelTo(Position + Vector2.new(0, 25))
	else
		Library:Notify("Destination is outside this scene", 3)
	end
end

local function StopAutomation()
	for _, Name in {"AutoFarm", "AutoForage", "AutoSell", "AutoBuy", "AutoRewards", "AutoChests", "AutoGifts", "AutoFish", "AutoMine", "AutoCraft"} do
		Toggles[Name]:SetValue(false)
	end
end

-- Automation
local function AutoFarm(Generation)
	local function Active()
		return AutoFarmEnabled and AutoFarmGeneration == Generation and not Library.Unloaded
	end

	while Active() do
		if IsReady() and not MovementBusy and ActiveScene.activeSceneIdAtom() == "main-map" then
			local State = PlayerState.getPlayerState(LocalPlayer)

			if State and State.inBuilding then
				FarmStatus = "Leave the house to farm"
			else
				local Crop, Action, Position = GetCropTarget()

				if Crop then
					UseCrop(Crop, Action, Position, Active)
				elseif Toggles.PlantCrops.Value and #PlayerSelectors.getLocalCrops() < GetCropLimit() then
					PlantCrop(Active)
				else
					FarmStatus = "Waiting for crops"
				end
			end
		end

		task.wait(0.6)
	end
end

local function AutoForage(Generation)
	local function Active()
		return AutoForageEnabled and AutoForageGeneration == Generation and not Library.Unloaded
	end

	while Active() do
		if IsReady() and not MovementBusy then
			local Allowed, Status = CanForage()

			if not Allowed then
				ForageStatus = Status
			else
				local Id, Name, Position = GetForageTarget()

				if Id then
					CollectForage(Id, Name, Position, Active)
				else
					ForageStatus = "No selected forage nearby"
				end
			end
		end

		task.wait(0.6)
	end
end

local function AutoSell(Generation)
	local function Active()
		return AutoSellEnabled and AutoSellGeneration == Generation and not Library.Unloaded
	end

	while Active() do
		if IsReady() and not MovementBusy and ActiveScene.activeSceneIdAtom() == "main-map" then
			SellItems(Active)
		end

		task.wait(5)
	end
end

local function AutoBuy(Generation)
	local function Active()
		return AutoBuyEnabled and AutoBuyGeneration == Generation and not Library.Unloaded
	end

	while Active() do
		if IsReady() and not MovementBusy and ActiveScene.activeSceneIdAtom() == "main-map" then
			BuySeeds(Active)
		end

		task.wait(8)
	end
end

local function AutoRewards(Generation)
	local function Active()
		return AutoRewardsEnabled and AutoRewardsGeneration == Generation and not Library.Unloaded
	end

	while Active() do
		local Account = PlayerSelectors.getLocalAccount()

		if Account and IsReady() then
			for Id, Entry in Account.achievements.entries do
				if not Active() or not IsReady() then
					break
				end

				if not Entry.unlockedTimestamp or Entry.claimedTimestamp then
					continue
				end

				Signals.claimAchievementReward:Fire(Id)

				if WaitForResult(function()
					local Current = PlayerSelectors.getLocalAccount()
					local Updated = Current and Current.achievements.entries[Id]

					return Updated and Updated.claimedTimestamp ~= nil
				end, Active) then
					SessionRewards += 1
				end

				task.wait(0.3)
			end
		end

		task.wait(15)
	end
end

local function AutoChests(Generation)
	local function Active()
		return AutoChestsEnabled and AutoChestsGeneration == Generation and not Library.Unloaded
	end

	while Active() do
		if IsReady() and not MovementBusy then
			local Chest, Position = GetChestTarget()

			if Chest then
				OpenChest(Chest, Position, Active)
			else
				ChestStatus = "All available chests collected"
			end
		end

		task.wait(1)
	end
end

local function AutoGifts(Generation)
	local function Active()
		return AutoGiftsEnabled and AutoGiftsGeneration == Generation and not Library.Unloaded
	end

	while Active() do
		if IsReady() then
			ClaimGifts(Active)
		end

		task.wait(20)
	end
end

local function ResourceMarkers(Generation)
	while ResourceMarkersEnabled and ResourceMarkersGeneration == Generation and not Library.Unloaded do
		if IsReady() then
			UpdateMarkers()
		else
			ClearMarkers()
		end

		RunService.PreRender:Wait()
	end
end

local function AutoFish(Generation)
	local function Active()
		return Fishing.Enabled and Fishing.Generation == Generation and not Library.Unloaded
	end

	while Active() do
		if IsReady() and not MovementBusy and ActiveScene.activeSceneIdAtom() == "main-map" then
			local State = PlayerState.getPlayerState(LocalPlayer)

			if State and State.inBuilding then
				Fishing.Status = "Leave the house to fish"
			else
				Fish(Active)
			end
		elseif ActiveScene.activeSceneIdAtom() ~= "main-map" then
			Fishing.Status = "Return to the main map to fish"
		end

		task.wait(math.max(1, Fishing.Data.OCEAN_FISHING_COOLDOWN_SECONDS))
	end
end

local function AutoMine(Generation)
	local function Active()
		return Mining.Enabled and Mining.Generation == Generation and not Library.Unloaded
	end

	while Active() do
		if IsReady() and not MovementBusy then
			local SceneId = ActiveScene.activeSceneIdAtom()

			if Mining.Utilities.isMineSceneId(SceneId) then
				local ChestId, ChestPosition, ChestAction = GetMineChest()
				local Floor = Mining.Utilities.getMineFloorFromSceneId(SceneId)
				local NextScene = Mining.Utilities.getNextMineSceneId(SceneId)

				if Toggles.MineChestPriority.Value and ChestId then
					OpenMineChest(ChestId, ChestPosition, ChestAction, Active)
				elseif Toggles.MineRestart.Value and Floor and Floor >= Mining.Types.MAX_RESOURCE_MINE_FLOOR then
					if TravelMine("surface", Active) and Active() then
						Mining.RestartPending = true
					end
				elseif not (Toggles.MineDescend.Value and NextScene and TravelMine(NextScene, Active)) then
					Mine(Active)
				end
			elseif SceneId == "main-map" and (Toggles.EnterMine.Value or (Toggles.MineRestart.Value and Mining.RestartPending)) and GetPickaxe() then
				local State = PlayerState.getPlayerState(LocalPlayer)

				if State and State.inBuilding then
					Mining.Status = "Leave the house to enter the mine"
				else
					if TravelMine("mine-1", Active) then
						Mining.RestartPending = false
					end
				end
			else
				Mining.Status = GetPickaxe() and "Enter a mine to begin" or "Craft or equip a pickaxe"
			end
		end

		task.wait(0.8)
	end
end

local function AutoCraft(Generation)
	local function Active()
		return Crafting.Enabled and Crafting.Generation == Generation and not Library.Unloaded
	end

	while Active() do
		if IsReady() and not MovementBusy then
			CraftItem(Active)
		end

		task.wait(3)
	end
end

-- Interface
local Window = Library:CreateWindow({
	Title = "Caramel",
	Footer = "Made with <3 by Taze | discord.gg/cyjC3QejpG",
	Font = FontFace,
	Size = UDim2.fromOffset(720, 620),
	Center = true,
	AutoShow = true,
	Resizable = true,
	ShowCustomCursor = false,
})

local Tabs = {
	Farm = Window:AddTab("Farm", "sprout"),
	Gathering = Window:AddTab("Gathering", "leaf"),
	Fishing = Window:AddTab("Fishing", "fish"),
	Mining = Window:AddTab("Mining", "pickaxe"),
	Crafting = Window:AddTab("Crafting", "hammer"),
	Travel = Window:AddTab("Travel", "map-pin"),
	Settings = Window:AddTab("Settings", "settings"),
}

local CropGroup = Tabs.Farm:AddGroupbox({
	Side = "Left",
	Name = "Crops",
	IconName = "sprout",
})

local SupplyGroup = Tabs.Farm:AddGroupbox({
	Side = "Right",
	Name = "Seeds",
	IconName = "shopping-basket",
})

local SaleGroup = Tabs.Farm:AddGroupbox({
	Side = "Right",
	Name = "Selling",
	IconName = "coins",
})

local StatsGroup = Tabs.Farm:AddGroupbox({
	Side = "Left",
	Name = "Session",
	IconName = "chart-no-axes-combined",
})

local ForageGroup = Tabs.Gathering:AddGroupbox({
	Side = "Left",
	Name = "Foraging",
	IconName = "leaf",
})

local RewardGroup = Tabs.Gathering:AddGroupbox({
	Side = "Right",
	Name = "Achievements",
	IconName = "award",
})

local TravelGroup = Tabs.Travel:AddGroupbox({
	Side = "Left",
	Name = "Destinations",
	IconName = "map-pin",
})

local PlayerGroup = Tabs.Travel:AddGroupbox({
	Side = "Right",
	Name = "Player",
	IconName = "person-standing",
})

local MenuGroup = Tabs.Settings:AddGroupbox({
	Side = "Left",
	Name = "Menu",
	IconName = "settings",
})

local ChestGroup = Tabs.Gathering:AddGroupbox({
	Side = "Left",
	Name = "Treasure",
	IconName = "gem",
})

local GiftGroup = Tabs.Gathering:AddGroupbox({
	Side = "Right",
	Name = "Daily and Mail",
	IconName = "gift",
})

local MarkerGroup = Tabs.Travel:AddGroupbox({
	Side = "Left",
	Name = "Resource Markers",
	IconName = "scan-eye",
})

local DiscordGroup = Tabs.Settings:AddGroupbox({
	Side = "Left",
	Name = "Discord",
	IconName = "message-circle",
})

do
	local FishGroup = Tabs.Fishing:AddGroupbox({
		Side = "Left",
		Name = "Auto Fish",
		IconName = "fish",
	})

	FishGroup:AddToggle("AutoFish", {
		Text = "Auto fish",
		Default = false,
	})

	FishGroup:AddDropdown("FishingRod", {
		Values = Fishing.RodNames,
		Default = 1,
		Text = "Fishing rod",
	})

	FishGroup:AddDropdown("FishingSpot", {
		Values = Fishing.SpotNames,
		Default = 1,
		Text = "Fishing spot",
	})

	Fishing.Label = FishGroup:AddLabel("Idle")
	Fishing.CountLabel = FishGroup:AddLabel("Fish: 0 | Treasures: 0")
end

do
	local MineGroup = Tabs.Mining:AddGroupbox({
		Side = "Left",
		Name = "Auto Mine",
		IconName = "pickaxe",
	})

	MineGroup:AddToggle("AutoMine", {
		Text = "Auto mine",
		Default = false,
	})

	MineGroup:AddToggle("EnterMine", {
		Text = "Enter mine automatically",
		Default = true,
	})

	MineGroup:AddToggle("MineDescend", {
		Text = "Descend when a ladder opens",
		Default = true,
	})

	MineGroup:AddToggle("MineChestPriority", {
		Text = "Prioritize mine treasure chests",
		Default = true,
	})

	MineGroup:AddToggle("MineRestart", {
		Text = "Restart after floor 30",
		Default = false,
	})

	MineGroup:AddDropdown("MiningPickaxe", {
		Values = Mining.PickaxeNames,
		Default = 1,
		Text = "Pickaxe",
	})

	MineGroup:AddDropdown("MiningNodes", {
		Values = Mining.NodeNames,
		Default = Mining.NodeNames,
		Multi = true,
		Text = "Mine these nodes",
	})

	MineGroup:AddDropdown("MiningPriority", {
		Values = {"Nearest", "Ore first"},
		Default = 1,
		Text = "Priority",
	})

	MineGroup:AddButton({
		Text = "Return to surface",
		Func = function()
			if not Mining.Utilities.isMineSceneId(ActiveScene.activeSceneIdAtom()) then
				return
			end

			Toggles.AutoMine:SetValue(false)
			task.spawn(function()
				local Deadline = os.clock() + 5

				while MovementBusy and not Library.Unloaded and os.clock() < Deadline do
					task.wait(0.1)
				end

				if IsReady() and not MovementBusy then
					TravelMine("surface", function()
						return not Library.Unloaded
					end)
				end
			end)
		end,
	})

	Mining.Label = MineGroup:AddLabel("Idle")
	Mining.CountLabel = MineGroup:AddLabel("Nodes mined: 0 | Chests: 0")
end

do
	local CraftGroup = Tabs.Crafting:AddGroupbox({
		Side = "Left",
		Name = "Workbench",
		IconName = "hammer",
	})

	CraftGroup:AddToggle("AutoCraft", {
		Text = "Auto craft selected item",
		Default = false,
	})

	CraftGroup:AddDropdown("ToolRecipe", {
		Values = Crafting.Recipes,
		Default = table.find(Crafting.Recipes, "scrappy-fishing-rod") or 1,
		Text = "Recipe",
		Searchable = true,
	})

	CraftGroup:AddSlider("CraftTarget", {
		Text = "Items to keep",
		Default = 1,
		Min = 1,
		Max = 5,
		Rounding = 0,
	})

	CraftGroup:AddButton({
		Text = "Visit own workbench",
		Func = function()
			if MovementBusy or not IsReady() or ActiveScene.activeSceneIdAtom() ~= "main-map" then
				return
			end

			local Account = PlayerSelectors.getLocalAccount()
			local Plot = PlayerPlot.tryGetLocalPlayerPlot()

			if not Account or not Account.houses.activeHouseId or not Plot then
				Library:Notify("Build a house and place a workbench first", 4)
				return
			end

			local Character = GetCharacter()
			local Scene = ActiveScene.activeSceneStateAtom()
			local Position = require(Shared.utilities.plots).getPlayerHomePosition(Plot) + Vector2.new(0, -40)

			task.spawn(function()
				local function Active()
					local Current = ActiveScene.activeSceneStateAtom()

					return not Library.Unloaded and LocalPlayer.Character == Character and Current.sceneId == Scene.sceneId and Current.epoch == Scene.epoch
				end

				if not BeginMovement(Position, Active) then
					return
				end

				Events.enterBuilding()
				task.wait(0.5)

				if Active() then
					MovementPivot = nil
					Crafting.Status = "Inside your house"
				end

				RestoreMovement(not Active())
			end)
		end,
	})

	Crafting.Label = CraftGroup:AddLabel("Idle")
	Crafting.CountLabel = CraftGroup:AddLabel("Items crafted: 0")
end

do
	local ForecastGroup = Tabs.Gathering:AddGroupbox({
		Side = "Right",
		Name = "Weather Forecast",
		IconName = "cloud-sun",
	})

	Updates.WeatherLabel = ForecastGroup:AddLabel("Next weather: unknown")
	Updates.TimeLabel = ForecastGroup:AddLabel("Waiting for forecast")
end

CropGroup:AddToggle("AutoFarm", {
	Text = "Auto farm",
	Default = false,
})

CropGroup:AddToggle("HarvestCrops", {
	Text = "Harvest ripe crops",
	Default = true,
})

CropGroup:AddToggle("UseSickle", {
	Text = "Use best owned sickle",
	Default = true,
})

CropGroup:AddToggle("WaterCrops", {
	Text = "Water growing crops",
	Default = true,
})

CropGroup:AddToggle("PlantCrops", {
	Text = "Plant empty tiles",
	Default = true,
})

CropGroup:AddDropdown("Seed", {
	Values = SeedNames,
	Default = table.find(SeedNames, "carrot") or 1,
	Text = "Crop to plant",
})

CropGroup:AddSlider("CropLimit", {
	Text = "Crop limit",
	Default = 15,
	Min = 1,
	Max = 225,
	Rounding = 0,
})

local FarmLabel = CropGroup:AddLabel("Idle")
Garden.Label = CropGroup:AddLabel("Crop target: 0")

SupplyGroup:AddToggle("AutoBuy", {
	Text = "Restock selected seeds",
	Default = false,
})

SupplyGroup:AddSlider("SeedReserve", {
	Text = "Seeds to keep",
	Default = 5,
	Min = 1,
	Max = 50,
	Rounding = 0,
})

SupplyGroup:AddSlider("GoldReserve", {
	Text = "Gold to keep",
	Default = 50,
	Min = 0,
	Max = 10000,
	Rounding = 0,
})

local SupplyLabel = SupplyGroup:AddLabel("Idle")

SaleGroup:AddToggle("AutoSell", {
	Text = "Auto sell inventory",
	Default = false,
})

SaleGroup:AddDropdown("SellCategories", {
	Values = {"Crops", "Fish", "Materials"},
	Default = {"Crops"},
	Multi = true,
	Text = "Sell categories",
})

SaleGroup:AddToggle("KeepRare", {
	Text = "Keep rare items",
	Default = true,
})

SaleGroup:AddSlider("KeepItems", {
	Text = "Keep per item",
	Default = 0,
	Min = 0,
	Max = 100,
	Rounding = 0,
})

SaleGroup:AddDropdown("ProtectedItems", {
	Values = ProtectedItemNames,
	Default = {},
	Multi = true,
	Text = "Keep these items",
	Searchable = true,
})

Trading.Label = SaleGroup:AddLabel("Idle")

local TimeLabel = StatsGroup:AddLabel("Time: 0m")
local GoldLabel = StatsGroup:AddLabel("Gold change: 0")
local CropLabel = StatsGroup:AddLabel("Planted: 0 | Watered: 0")
local HarvestLabel = StatsGroup:AddLabel("Harvests: 0 | Forage: 0")
local SaleLabel = StatsGroup:AddLabel("Sales: 0 | Seeds bought: 0")

ForageGroup:AddToggle("AutoForage", {
	Text = "Auto forage",
	Default = false,
})

ForageGroup:AddToggle("ForageRainOnly", {
	Text = "Only forage during rain",
	Default = false,
})

ForageGroup:AddToggle("ForageNightOnly", {
	Text = "Only forage at night",
	Default = false,
})

ForageGroup:AddDropdown("ForageTypes", {
	Values = {"Dewcap", "Gleaming Stone", "Loose Rock", "Moonthistle", "Mushroom", "Pebbles", "Rainblossom", "Seashell", "Starfall Petal", "Zephyr Bloom"},
	Default = {"Dewcap", "Gleaming Stone", "Loose Rock", "Moonthistle", "Mushroom", "Pebbles", "Rainblossom", "Seashell", "Starfall Petal", "Zephyr Bloom"},
	Multi = true,
	Text = "Collect",
})

ForageGroup:AddSlider("ForageRadius", {
	Text = "Search radius",
	Default = 2500,
	Min = 100,
	Max = 5000,
	Rounding = 0,
})

local ForageLabel = ForageGroup:AddLabel("Idle")

RewardGroup:AddToggle("AutoRewards", {
	Text = "Claim achievements",
	Default = false,
})

local RewardLabel = RewardGroup:AddLabel("Rewards claimed: 0")

ChestGroup:AddToggle("AutoChests", {
	Text = "Auto collect treasure chests",
	Default = false,
})

local ChestLabel = ChestGroup:AddLabel("Idle")
local ChestCountLabel = ChestGroup:AddLabel("Chests collected: 0")

GiftGroup:AddToggle("AutoGifts", {
	Text = "Auto claim gifts",
	Default = false,
})

GiftGroup:AddToggle("ClaimDaily", {
	Text = "Claim daily reward",
	Default = true,
})

GiftGroup:AddToggle("ClaimMail", {
	Text = "Claim mail attachments",
	Default = true,
})

if Updates.Code then
	GiftGroup:AddButton({
		Text = `Redeem {Updates.Code}`,
		Func = function()
			local State = Updates.CodeAtom()

			if not Library.Unloaded and not State.coolingDown and State.status ~= "checking" then
				Signals.requestCodeRedeem:Fire(Updates.Code)
			end
		end,
	})
end

local GiftLabel = GiftGroup:AddLabel("Idle")
local GiftCountLabel = GiftGroup:AddLabel("Gifts claimed: 0")

MarkerGroup:AddToggle("ResourceMarkers", {
	Text = "Show resource markers",
	Default = false,
})

MarkerGroup:AddDropdown("MarkerTypes", {
	Values = {"Rare forage", "Ripe crops", "Treasure chests", "Mine nodes"},
	Default = {"Rare forage", "Ripe crops", "Treasure chests", "Mine nodes"},
	Multi = true,
	Text = "Show",
})

MarkerGroup:AddSlider("MarkerLimit", {
	Text = "Marker limit",
	Default = 12,
	Min = 1,
	Max = 30,
	Rounding = 0,
})

MarkerGroup:AddSlider("MarkerRadius", {
	Text = "Marker radius",
	Default = 2500,
	Min = 100,
	Max = 5000,
	Rounding = 0,
})

RefreshLandmarks()

TravelGroup:AddDropdown("Landmark", {
	Values = LandmarkNames,
	Default = table.find(LandmarkNames, "My Plot") or 1,
	Text = "Destination",
})

TravelGroup:AddButton({
	Text = "Travel",
	Func = TravelToLandmark,
})

TravelGroup:AddButton({
	Text = "Refresh destinations",
	Func = RefreshLandmarks,
})

TravelGroup:AddButton({
	Text = "Save current position",
	Func = function()
		if not IsReady() or MovementBusy then
			return
		end

		local Scene = ActiveScene.activeSceneStateAtom()

		BookmarkPosition = CharacterPosition.getPlayerFeetPosition(LocalPlayer)
		BookmarkSceneId = Scene.sceneId
		BookmarkSceneEpoch = Scene.epoch
		Library:Notify("Position saved", 3)
	end,
})

TravelGroup:AddButton({
	Text = "Return to saved position",
	Func = function()
		local Scene = ActiveScene.activeSceneStateAtom()

		if not BookmarkPosition or Scene.sceneId ~= BookmarkSceneId or Scene.epoch ~= BookmarkSceneEpoch then
			Library:Notify("Save a position in this scene first", 3)
			return
		end

		TravelTo(BookmarkPosition)
	end,
})

PlayerGroup:AddToggle("WalkSpeedEnabled", {
	Text = "Custom walk speed",
	Default = false,
})

PlayerGroup:AddSlider("WalkSpeed", {
	Text = "Walk speed",
	Default = 24,
	Min = 8,
	Max = 60,
	Rounding = 0,
})

PlayerGroup:AddToggle("AntiIdle", {
	Text = "Anti idle",
	Default = false,
})

PlayerGroup:AddToggle("ReturnAfterAction", {
	Text = "Return after farming",
	Default = true,
})

PlayerGroup:AddSlider("ActionDelay", {
	Text = "Movement settle time",
	Default = 0.35,
	Min = 0.2,
	Max = 1,
	Rounding = 2,
})

MenuGroup:AddLabel("Menu key"):AddKeyPicker("MenuKeybind", {
	Default = "RightControl",
	NoUI = true,
	Text = "Menu key",
})

MenuGroup:AddButton({
	Text = "Stop automation",
	Func = StopAutomation,
})

MenuGroup:AddButton({
	Text = "Unload",
	Func = function()
		Library:Unload()
	end,
})

DiscordGroup:AddLabel("discord.gg/cyjC3QejpG")

DiscordGroup:AddButton({
	Text = "Copy Discord invite",
	Func = CopyDiscord,
})

DiscordGroup:AddButton({
	Text = "Open Discord invite",
	Func = function()
		task.spawn(OpenDiscord)
	end,
})

Library.ToggleKeybind = Options.MenuKeybind
ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

-- Events
Toggles.AutoFish:OnChanged(function()
	Fishing.Enabled = Toggles.AutoFish.Value
	Fishing.Generation += 1

	if Fishing.Enabled then
		task.spawn(AutoFish, Fishing.Generation)
	else
		StopFishing()
		Fishing.Status = "Idle"
	end
end)

Toggles.AutoMine:OnChanged(function()
	Mining.Enabled = Toggles.AutoMine.Value
	Mining.Generation += 1

	if Mining.Enabled then
		task.spawn(AutoMine, Mining.Generation)
	else
		StopMining()
		Mining.RestartPending = false
		Mining.Status = "Idle"
	end
end)

Toggles.MineRestart:OnChanged(function()
	Mining.RestartPending = false
end)

Toggles.AutoCraft:OnChanged(function()
	Crafting.Enabled = Toggles.AutoCraft.Value
	Crafting.Generation += 1

	if Crafting.Enabled then
		task.spawn(AutoCraft, Crafting.Generation)
	else
		Crafting.Status = "Idle"
	end
end)

Fishing.EndConnection = Events.oceanFishingEnded:connect(function(Result)
	if Library.Unloaded or not Result.sessionId or not Fishing.Pending[Result.sessionId] or (Result.playerUserId and Result.playerUserId ~= LocalPlayer.UserId) then
		return
	end

	local SpotId = Fishing.Pending[Result.sessionId]

	Fishing.Pending[Result.sessionId] = nil

	if Result.reason == "reward" then
		Fishing.Catches += Result.rewardQuantity or 1

		if Result.treasure then
			Fishing.Treasures += 1
		end

		if Fishing.Enabled then
			Fishing.Status = `Caught: {Result.rewardItemId or "fish"}`
		end
	elseif Fishing.Enabled then
		Fishing.Status = `Fishing: {Result.reason}`

		if Result.reason == "failed" or Result.reason == "missed" or Result.reason == "too-far" then
			FailedTargets[`fishing:{SpotId}`] = os.clock() + 30
		end
	end
end)

Mining.EndConnection = Events.miningEnded:connect(function(Result)
	if Library.Unloaded or not Result.sessionId or not Mining.Pending[Result.sessionId] or (Result.playerUserId and Result.playerUserId ~= LocalPlayer.UserId) then
		return
	end

	Mining.Pending[Result.sessionId] = nil

	if Result.reason == "reward" then
		Mining.Nodes += 1

		if Mining.Enabled then
			Mining.Status = `Collected: {Result.rewardItemId or "ore"}`
		end
	elseif Mining.Enabled then
		Mining.Status = `Mining: {Result.reason}`
	end
end)

Toggles.AutoFarm:OnChanged(function()
	AutoFarmEnabled = Toggles.AutoFarm.Value
	AutoFarmGeneration += 1

	if AutoFarmEnabled then
		task.spawn(AutoFarm, AutoFarmGeneration)
	else
		FarmStatus = "Idle"
	end
end)

Toggles.AutoForage:OnChanged(function()
	AutoForageEnabled = Toggles.AutoForage.Value
	AutoForageGeneration += 1

	if AutoForageEnabled then
		task.spawn(AutoForage, AutoForageGeneration)
	else
		ForageStatus = "Idle"
	end
end)

Toggles.AutoSell:OnChanged(function()
	AutoSellEnabled = Toggles.AutoSell.Value
	AutoSellGeneration += 1

	if AutoSellEnabled then
		task.spawn(AutoSell, AutoSellGeneration)
	else
		Trading.SellStatus = "Idle"
	end
end)

Toggles.AutoBuy:OnChanged(function()
	AutoBuyEnabled = Toggles.AutoBuy.Value
	AutoBuyGeneration += 1

	if AutoBuyEnabled then
		task.spawn(AutoBuy, AutoBuyGeneration)
	else
		SupplyStatus = "Idle"
	end
end)

Toggles.AutoRewards:OnChanged(function()
	AutoRewardsEnabled = Toggles.AutoRewards.Value
	AutoRewardsGeneration += 1

	if AutoRewardsEnabled then
		task.spawn(AutoRewards, AutoRewardsGeneration)
	end
end)

Toggles.AutoChests:OnChanged(function()
	AutoChestsEnabled = Toggles.AutoChests.Value
	AutoChestsGeneration += 1

	if AutoChestsEnabled then
		task.spawn(AutoChests, AutoChestsGeneration)
	else
		ChestStatus = "Idle"
	end
end)

Toggles.AutoGifts:OnChanged(function()
	AutoGiftsEnabled = Toggles.AutoGifts.Value
	AutoGiftsGeneration += 1

	if AutoGiftsEnabled then
		task.spawn(AutoGifts, AutoGiftsGeneration)
	else
		GiftStatus = "Idle"
	end
end)

Toggles.ResourceMarkers:OnChanged(function()
	ResourceMarkersEnabled = Toggles.ResourceMarkers.Value
	ResourceMarkersGeneration += 1

	if ResourceMarkersEnabled then
		task.spawn(ResourceMarkers, ResourceMarkersGeneration)
	else
		ClearMarkers()
	end
end)

Toggles.WalkSpeedEnabled:OnChanged(UpdateWalkSpeed)
Options.WalkSpeed:OnChanged(UpdateWalkSpeed)

Toggles.AntiIdle:OnChanged(function()
	SetAntiIdle(Toggles.AntiIdle.Value)
end)

local CharacterConnection = LocalPlayer.CharacterAdded:Connect(function(Character)
	local Humanoid = Character:WaitForChild("Humanoid", 10)

	if Library.Unloaded or LocalPlayer.Character ~= Character or not Humanoid then
		return
	end

	UpdateWalkSpeed()
end)

local WalkSpeedElapsed = 0
local WalkSpeedHeartbeat = RunService.Heartbeat:Connect(function(DeltaTime)
	WalkSpeedElapsed += DeltaTime

	if Library.Unloaded or not Toggles.WalkSpeedEnabled.Value or WalkSpeedElapsed < 0.25 then
		return
	end

	WalkSpeedElapsed = 0
	UpdateWalkSpeed()
end)

Library:OnUnload(function()
	Fishing.Enabled = false
	Mining.Enabled = false
	Crafting.Enabled = false
	Fishing.Generation += 1
	Mining.Generation += 1
	Crafting.Generation += 1
	StopFishing()
	StopMining()
	Trading.Close()
	Fishing.EndConnection:Disconnect()
	Mining.EndConnection:Disconnect()
	table.clear(Fishing.Pending)
	table.clear(Mining.Pending)
	AutoFarmEnabled = false
	AutoForageEnabled = false
	AutoSellEnabled = false
	AutoBuyEnabled = false
	AutoRewardsEnabled = false
	AutoChestsEnabled = false
	AutoGiftsEnabled = false
	ResourceMarkersEnabled = false
	AutoFarmGeneration += 1
	AutoForageGeneration += 1
	AutoSellGeneration += 1
	AutoBuyGeneration += 1
	AutoRewardsGeneration += 1
	AutoChestsGeneration += 1
	AutoGiftsGeneration += 1
	ResourceMarkersGeneration += 1
	RestoreMovement(true)
	CharacterConnection:Disconnect()
	WalkSpeedHeartbeat:Disconnect()

	if WalkSpeedConnection then
		WalkSpeedConnection:Disconnect()
	end

	WalkSpeedHumanoid = nil
	ClearMarkers()
	SetAntiIdle(false)

	for Humanoid, WalkSpeed in OriginalWalkSpeeds do
		if Humanoid.Parent then
			Humanoid.WalkSpeed = WalkSpeed
		end
	end

	table.clear(OriginalWalkSpeeds)

	if Environment.Caramel == Library then
		Environment.Caramel = nil
	end
end)

SaveManager:LoadAutoloadConfig()

pcall(function()
	Library:Notify("Join my community: discord.gg/cyjC3QejpG", 7)
end)
task.spawn(OpenDiscord)

-- Session Stats
task.spawn(function()
	while not Library.Unloaded do
		local Account = PlayerSelectors.getLocalAccount()
		local Minutes = math.floor((os.clock() - SessionStartedAt) / 60)

		TimeLabel:SetText(`Time: {Minutes}m`)
		GoldLabel:SetText(`Gold change: {Account and Account.gold - SessionGold or 0}`)
		CropLabel:SetText(`Planted: {SessionPlants} | Watered: {SessionWatered}`)
		HarvestLabel:SetText(`Harvests: {SessionHarvests} | Forage: {SessionForage}`)
		SaleLabel:SetText(`Sales: {SessionSales} | Seeds bought: {SessionSeeds}`)
		RewardLabel:SetText(`Rewards claimed: {SessionRewards}`)
		FarmLabel:SetText(FarmStatus)
		ForageLabel:SetText(ForageStatus)
		SupplyLabel:SetText(SupplyStatus)
		Trading.Label:SetText(Trading.SellStatus)
		ChestLabel:SetText(ChestStatus)
		ChestCountLabel:SetText(`Chests collected: {SessionChests}`)
		GiftLabel:SetText(GiftStatus)
		GiftCountLabel:SetText(`Gifts claimed: {SessionGifts}`)
		Fishing.Label:SetText(Fishing.Status)
		Fishing.CountLabel:SetText(`Fish: {Fishing.Catches} | Treasures: {Fishing.Treasures}`)
		Mining.Label:SetText(Mining.Status)
		Mining.CountLabel:SetText(`Nodes mined: {Mining.Nodes} | Chests: {Mining.Chests}`)
		Crafting.Label:SetText(Crafting.Status)
		Crafting.CountLabel:SetText(`Items crafted: {Crafting.Completed}`)
		Garden.Label:SetText(`Crops: {#PlayerSelectors.getLocalCrops()} / {GetCropLimit()}`)

		if os.clock() >= Updates.NextForecastAt then
			local Forecast = Updates.Forecast:getForecastParameters()

			Updates.WeatherLabel:SetText(`Next weather: {Forecast.forecastWeather}`)
			Updates.TimeLabel:SetText(`{Forecast.forecastStart} - {Forecast.forecastEnd}`)
			Updates.NextForecastAt = os.clock() + 5
		end

		task.wait(1)
	end
end)
