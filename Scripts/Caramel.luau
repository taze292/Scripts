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
Library.ScreenGui.Parent = LocalPlayer.PlayerGui
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
	["Mushroom"] = "mushroom",
	["Pebbles"] = "pebbles",
	["Seashell"] = "seashell",
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
				code = "tazetap",
			},
		}),
	})
end

local function CopyDiscord()
	setclipboard("https://discord.gg/tazetap")
	Library:Notify("Copied discord.gg/tazetap", 3)
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

	if Action == "Harvest" then
		local Data = CropRegistry.getCropData(CurrentCrop.type)

		if CurrentCrop.stage ~= CropStage.getCropStage(Data, "ripe") or not Toggles.HarvestCrops.Value then
			RestoreMovement(false)
			return
		end

		Events.harvestCrop(SceneContext.createSceneRequestContext("crop-harvest"), Crop.id)
	else
		if not Toggles.WaterCrops.Value or not CropUtilities.canWaterCrop(CurrentCrop, CropRegistry.getCropData(CurrentCrop.type)) then
			RestoreMovement(false)
			return
		end

		Events.useToolOnCrop(SceneContext.createSceneRequestContext("crop-water"), "waterCrop", Crop.id)
	end

	local Confirmed = WaitForResult(function()
		local Updated = PlayerSelectors.getLocalCropById(Crop.id)

		if Action == "Water" then
			return Updated and Updated.watered == true
		end

		return not Updated or Updated.timesHarvested > CurrentCrop.timesHarvested or Updated.stage ~= CurrentCrop.stage
	end, Active)

	if Confirmed then
		if Action == "Harvest" then
			SessionHarvests += 1
		else
			SessionWatered += 1
		end
	else
		FailedTargets[Crop.id] = os.clock() + 10
	end

	RestoreMovement(not Active())
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

			if PlotPlacements.areTilesFree(LocalPlayer.UserId, Grid.getTilesOccupied(Tile, Data.gridSize)) then
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
		or #PlayerSelectors.getLocalCrops() >= Options.CropLimit.Value
	then
		RestoreMovement(false)
		return
	end

	local Data = CropRegistry.getCropData(CropId)

	if not PlotPlacements.areTilesFree(LocalPlayer.UserId, Grid.getTilesOccupied(Tile, Data.gridSize)) then
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

	if not SceneReplica.getAuthoritativeScene().nodesById[Id] then
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

-- Trading Functions
local function GetSellSlots()
	local Account = PlayerSelectors.getLocalAccount()
	local Totals = {}
	local Slots = {}

	if not Account then
		return Slots
	end

	for _, Slot in Account.inventory do
		Totals[Slot.itemId] = (Totals[Slot.itemId] or 0) + Slot.quantity
	end

	for Index, Slot in Account.inventory do
		local Data = ItemUtilities.getItemData(Slot.itemId)

		if not ItemUtilities.canSellItem(Data) or Data.type == "tool" or Data.type == "seeds" then
			continue
		end

		if Options.ProtectedItems.Value[Slot.itemId] or (Toggles.KeepRare.Value and Data.rarity ~= "common" and Data.rarity ~= "uncommon") then
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

	if #Slots == 0 or not Active() or not IsReady() then
		return
	end

	local Before = PlayerSelectors.getLocalAccount().gold

	Events.sellInventorySlots(Slots)

	if WaitForResult(function()
		local Account = PlayerSelectors.getLocalAccount()

		return Account and Account.gold > Before
	end, Active) then
		SessionSales += 1
	end
end

local function BuySeeds(Active)
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
		if not Active() or not IsReady() or SeedIds[Options.Seed.Value] ~= ItemId then
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
end

local function UpdateMarkers()
	local Camera = workspace.CurrentCamera
	local Position = CharacterPosition.getPlayerFeetPosition(LocalPlayer)
	local Account = PlayerSelectors.getLocalAccount()
	local Targets = {}
	local Scene = SceneReplica.getAuthoritativeScene()

	if not Camera or not Position or not Account then
		ClearMarkers()
		return
	end

	if Options.MarkerTypes.Value["Rare forage"] then
		for _, Id in Scene.childrenByParentId["folder/forageables"] or {} do
			local Node = Scene.nodesById[Id]
			local Identity = Node and GetComponent(Node.entity, "ForageIdentity")

			if Identity and (Identity.forageableId == "dewcap" or Identity.forageableId == "gem-stone") then
				table.insert(Targets, {
					Position = GetObjectPosition(Id),
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
					Position = GetObjectPosition(Crop.id),
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
					Position = GetObjectPosition(TreasureChests.getTreasureChestObjectId(Chest.id)),
					Name = "Treasure chest",
					Color = Library.Scheme.AccentColor,
				})
			end
		end
	end

	local VisibleTargets = {}

	for _, Target in Targets do
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
	for _, Name in {"AutoFarm", "AutoForage", "AutoSell", "AutoBuy", "AutoRewards", "AutoChests", "AutoGifts"} do
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
			local Crop, Action, Position = GetCropTarget()

			if Crop then
				UseCrop(Crop, Action, Position, Active)
			elseif Toggles.PlantCrops.Value and #PlayerSelectors.getLocalCrops() < Options.CropLimit.Value then
				PlantCrop(Active)
			else
				FarmStatus = "Waiting for crops"
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
			local Id, Name, Position = GetForageTarget()

			if Id then
				CollectForage(Id, Name, Position, Active)
			else
				ForageStatus = "No selected forage nearby"
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
		if IsReady() then
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
		if IsReady() then
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

-- Interface
local Window = Library:CreateWindow({
	Title = "Caramel",
	Footer = "Made with <3 by Taze | discord.gg/tazetap",
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

CropGroup:AddToggle("AutoFarm", {
	Text = "Auto farm",
	Default = false,
})

CropGroup:AddToggle("HarvestCrops", {
	Text = "Harvest ripe crops",
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

local TimeLabel = StatsGroup:AddLabel("Time: 0m")
local GoldLabel = StatsGroup:AddLabel("Gold change: 0")
local CropLabel = StatsGroup:AddLabel("Planted: 0 | Watered: 0")
local HarvestLabel = StatsGroup:AddLabel("Harvests: 0 | Forage: 0")
local SaleLabel = StatsGroup:AddLabel("Sales: 0 | Seeds bought: 0")

ForageGroup:AddToggle("AutoForage", {
	Text = "Auto forage",
	Default = false,
})

ForageGroup:AddDropdown("ForageTypes", {
	Values = {"Dewcap", "Gleaming Stone", "Loose Rock", "Mushroom", "Pebbles", "Seashell"},
	Default = {"Dewcap", "Gleaming Stone", "Loose Rock", "Mushroom", "Pebbles", "Seashell"},
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

local GiftLabel = GiftGroup:AddLabel("Idle")
local GiftCountLabel = GiftGroup:AddLabel("Gifts claimed: 0")

MarkerGroup:AddToggle("ResourceMarkers", {
	Text = "Show resource markers",
	Default = false,
})

MarkerGroup:AddDropdown("MarkerTypes", {
	Values = {"Rare forage", "Ripe crops", "Treasure chests"},
	Default = {"Rare forage", "Ripe crops", "Treasure chests"},
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

DiscordGroup:AddLabel("discord.gg/tazetap")

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
Library:SetFont(FontFace)

Library:Notify("Join my community: discord.gg/tazetap", 7)
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
		ChestLabel:SetText(ChestStatus)
		ChestCountLabel:SetText(`Chests collected: {SessionChests}`)
		GiftLabel:SetText(GiftStatus)
		GiftCountLabel:SetText(`Gifts claimed: {SessionGifts}`)
		task.wait(1)
	end
end)
