local _, wepHash
local compss = {}
local wep
local added = {}
local weaponid
local globalhash
local comps = {}
local sum = 0
local wepobject
local createdobject = false
local previewCoords = nil
local nearbyPreviews = {}
local activePreviewsData = {}
local h
local roll
local pricing = {}
local crafting = false
local craftingammoitem
local craftingammoitem2
local itemtosend
local materialtosend
local craftcost
local cal = false
local modelz = false
local next = next
local OpenStores
local blips = {}

local function createBlips()
	for _, b in ipairs(blips) do
		RemoveBlip(b)
	end
	blips = {}

	if Config.General.Blips and Config.General.Blips.Enable then
		for k, v in pairs(Config.General.customizationLocations) do
			local blip = nil
			if BlipAddForCoords then
				blip = BlipAddForCoords(1664425300, v.Pos.x, v.Pos.y, v.Pos.z)
			else
				blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, v.Pos.x, v.Pos.y, v.Pos.z)
			end

			if blip and blip ~= 0 then
				SetBlipSprite(blip, Config.General.Blips.Sprite, true)
				if SetBlipName then
					SetBlipName(blip, Config.General.Blips.Name)
				else
					Citizen.InvokeNative(0x9CB1A1623062F402, blip, Config.General.Blips.Name)
				end
				table.insert(blips, blip)
			end
		end
	end
end

local OpenGroup = GetRandomIntInRange(0, 0xffffff)

local progressbar
if GetResourceState('cas-progressbar') == 'started' then
	progressbar = {
		start = function(message, milliseconds, cb)
			exports['cas-progressbar']:Progress({
				name = "gunsmith_action",
				duration = milliseconds,
				label = message,
				useWhileDead = false,
				canCancel = false,
				controlDisables = {
					disableMovement = true,
					disableCarMovement = true,
					disableMouse = false,
					disableCombat = true,
				}
			}, function(cancelled)
				if not cancelled and cb then
					cb()
				end
			end)
		end
	}
else
	progressbar = exports.vorp_progressbar:initiate()
end

local Core = exports.vorp_core:GetCore()

local function RemoveWeaponComponentFromPed(ped, componentHash, weaponHash)
	return Citizen.InvokeNative(0x19F70C4D80494FF8, ped, componentHash, weaponHash)
end

local function GiveWeaponComponentToEntity(entity, componentHash, weaponHash, p3)
	return Citizen.InvokeNative(0x74C9090FDD1BB48E, entity, componentHash, weaponHash, p3)
end

local function LoadModel(model)
	if not IsModelInCdimage(model) then
		return false
	end
	if not HasModelLoaded(model) then
		RequestModel(model, false)
		while not HasModelLoaded(model) do
			Wait(0)
		end
	end
	return true
end

local function makeEntityFaceEntity(entity)
	local p2 = GetEntityCoords(entity, true)
	local p1 = GetEntityCoords(PlayerPedId(), true)
	local dx = p2.x - p1.x
	local dy = p2.y - p1.y
	local heading = GetHeadingFromVector_2d(dx, dy)
	SetEntityHeading(PlayerPedId(), heading)
end

local function playanim(anim, msg)
	local playerPed = PlayerPedId()
	TaskStartScenarioInPlaceHash(playerPed, GetHashKey(anim), 20000, true, 0, 0, false)
	progressbar.start(msg, 20000, function()
	end)
	Wait(20000)
	ClearPedTasksImmediately(PlayerPedId())
end
local function whenKeyJustPressed(key)
	if Citizen.InvokeNative(0x580417101DDB492F, 0, key) or Citizen.InvokeNative(0x91AEF906BCA88877, 0, key) then
		return true
	else
		return false
	end
end

local function PromptSetUp()
	local str = "Press"
	OpenStores = UiPromptRegisterBegin()
	UiPromptSetControlAction(OpenStores, Config.General.keys["G"])
	str = VarString(10, 'LITERAL_STRING', str)
	UiPromptSetText(OpenStores, str)
	UiPromptSetEnabled(OpenStores, true)
	UiPromptSetVisible(OpenStores, true)
	UiPromptSetStandardMode(OpenStores, true)
	UiPromptSetGroup(OpenStores, OpenGroup, 0)
	UiPromptRegisterEnd(OpenStores)
end



RegisterNetEvent("vorp:SelectedCharacter")
AddEventHandler("vorp:SelectedCharacter", function()
	TriggerEvent("vorp_weapons:initalizing")
	Wait(1000)
	RemoveAllPedWeapons(PlayerPedId(), true, true)
end)


RegisterNetEvent("vorp_weapons:itemcheckpassed", function()
	playanim("WORLD_HUMAN_CROUCH_INSPECT", Config.Language.craftingloading)
	crafting = false
	craftingammoitem = nil
	craftingammoitem2 = nil
	itemtosend = nil
	materialtosend = nil
	craftcost = nil
	FreezeEntityPosition(PlayerPedId(), false)
end)

RegisterNetEvent("vorp_weapons:itemcheckpassed2", function()
	playanim(Config.General.craftinganimations, Config.Language.craftingloading)
	crafting = false
	craftingammoitem = nil
	craftingammoitem2 = nil
	itemtosend = nil
	materialtosend = nil
	craftcost = nil
	FreezeEntityPosition(PlayerPedId(), false)
end)

RegisterNetEvent("vorp_weapons:itemcheckfailed")
AddEventHandler("vorp_weapons:itemcheckfailed", function()
	crafting = false
	craftingammoitem = nil
	craftingammoitem2 = nil
	itemtosend = nil
	materialtosend = nil
	craftcost = nil
	FreezeEntityPosition(PlayerPedId(), false)
end)

RegisterNetEvent("vorp_weapons:applymods")
AddEventHandler("vorp_weapons:applymods", function()
	makeEntityFaceEntity(wepobject)
	playanim(Config.General.customizationanimation, Config.Language.customloading)
	TriggerServerEvent("vorp_weapons:addcomp", weaponid, added)
	for k, v in pairs(compss) do
		RemoveWeaponComponentFromPed(PlayerPedId(), v.name, globalhash)
	end
	for i = 1, #added do
		if added[i].model ~= 0 then
			LoadModel(added[i].model)
		end
		GiveWeaponComponentToEntity(PlayerPedId(), added[i].name, globalhash, true)
		if added[i].model ~= 0 then
			SetModelAsNoLongerNeeded(added[i].model)
		end
	end
	createdobject = false
	FreezeEntityPosition(PlayerPedId(), false)
	DeleteEntity(wepobject)
	added = {}
	wephash = nil
	compss = {}
	globalhash = nil
	weaponid = nil
end)

RegisterNetEvent("vorp_weapons:nomods")
AddEventHandler("vorp_weapons:nomods", function()
	createdobject = false
	DeleteEntity(wepobject)
	FreezeEntityPosition(PlayerPedId(), false)
	added = {}
	wephash = nil
	compss = {}
	globalhash = nil
	weaponid = nil
end)


AddEventHandler("onResourceStart", function(resourceName)
	if resourceName == GetCurrentResourceName() then
		TriggerEvent("vorp_weapons:initalizing")
	end
end
)

local function copy_components(t)
	local res = {}
	if t then
		for i = 1, #t do
			res[i] = { name = t[i].name, model = t[i].model }
		end
	end
	return res
end

local function table_equal(t1, t2)
	if not t1 or not t2 then return false end
	if #t1 ~= #t2 then return false end
	local matched = {}
	for i = 1, #t1 do
		local found = false
		for j = 1, #t2 do
			if not matched[j] and t1[i].name == t2[j].name then
				matched[j] = true
				found = true
				break
			end
		end
		if not found then return false end
	end
	return true
end

local function contains(table, element, element2)
	for k, v in pairs(table) do
		if v.comp == element and v.type == element2 then
			return true
		end
	end
	return false
end

local function contains2(table, element)
	for k, v in pairs(table) do
		if v.comp == element then
			return true
		end
	end
	return false
end

local function jobcheck(table, element)
	for k, v in pairs(table) do
		if v == element then
			return true
		end
	end
	return false
end

RegisterNetEvent("vorp_weapons:initalizing")
AddEventHandler("vorp_weapons:initalizing", function()
	comps = json.decode(LoadResourceFile(GetCurrentResourceName(), 'wepcomps.json'))
	Wait(1000)
	for k, v in pairs(comps) do
		for x, l in pairs(v) do
			if l.confirmed == 1 then
				if l.comp == "variant" then
					l.price = Config.General.price.variant
				elseif l.comp == "gripbody" then
					l.price = Config.General.price.griptype
				elseif l.comp == "grip" then
					l.price = Config.General.price.gripdecal
				elseif l.comp == "decal" then
					if l.type == "cylinder" then
						l.price = Config.General.price.decalextra
					elseif l.type == "frame" then
						l.price = Config.General.price.decalframe
					elseif l.type == "barrel" then
						l.price = Config.General.price.decalbarrel
					end
				elseif l.comp == "wrapcolor" then
					l.price = Config.General.price.wrapcolor
				elseif l.comp == "comp" then
					if l.type == "scope" then
						l.price = Config.General.price.sight
					elseif l.type == "rifling" then
						l.price = Config.General.price.rifling
					elseif l.type == "other" then
						l.price = Config.General.price.barrel
					elseif l.type == "wrap" then
						l.price = Config.General.price.wrap
					end
				elseif l.comp == "barrel" or l.comp == "trigger" or l.comp == "cylinder" or l.comp == "frontsight" or
					l.comp == "frame" or l.comp == "scope" then
					if l.label == "Gold" then
						l.price = Config.General.price.gold
					elseif l.label == "Silver" then
						l.price = Config.General.price.silver
					elseif l.label == "Blued Steel" then
						l.price = Config.General.price.bluesteel
					elseif l.label == "Browned Steel" then
						l.price = Config.General.price.brownsteel
					elseif l.label == "Blackened Steel" then
						l.price = Config.General.price.blacksteel
					elseif l.label == "Copper" then
						l.price = Config.General.price.copper
					elseif l.label == "Nickel" then
						l.price = Config.General.price.nickle
					elseif l.label == "Brass" then
						l.price = Config.General.price.brass
					elseif l.label == "Iron" then
						l.price = Config.General.price.iron
					end
				elseif l.comp == "decalcolor" then
					if l.label == "Gold" then
						l.price = Config.General.price.gold
					elseif l.label == "Silver" then
						l.price = Config.General.price.silver
					elseif l.label == "Blued Steel" then
						l.price = Config.General.price.bluesteel
					elseif l.label == "Browned Steel" then
						l.price = Config.General.price.brownsteel
					elseif l.label == "Blackened Steel" then
						l.price = Config.General.price.blacksteel
					elseif l.label == "Copper" then
						l.price = Config.General.price.copper
					elseif l.label == "Nickel" then
						l.price = Config.General.price.nickle
					elseif l.label == "Brass" then
						l.price = Config.General.price.brass
					elseif l.label == "Iron" then
						l.price = Config.General.price.iron
					end
				end
			end
		end
	end
	createBlips()
end)

function GetClosestPlayer()
	local players, closestDistance, closestPlayer = GetActivePlayers(), -1, -1
	local playerPed, playerId = PlayerPedId(), PlayerId()
	local usePlayerPed = true
	local coords = GetEntityCoords(playerPed)
	local playerid = 0
	local tgt1 = 0


	for i = 1, #players, 1 do
		local tgt = GetPlayerPed(players[i])
		if not usePlayerPed or (usePlayerPed and players[i] ~= playerId) then
			local targetCoords = GetEntityCoords(tgt)
			local distance = #(coords - targetCoords)

			if closestDistance == -1 or closestDistance > distance then
				closestPlayer = players[i]
				closestDistance = distance
				playerid = GetPlayerServerId(players[i])
				tgt1 = GetPlayerPed(players[i])
			end
		end
	end
	return closestPlayer, closestDistance, playerid, tgt1
end

function DrawText3D(x, y, z, text)
	local onScreen, _x, _y = GetScreenCoordFromWorldCoord(x, y, z)
	local px, py, pz = table.unpack(GetGameplayCamCoord())
	local str = VarString(10, "LITERAL_STRING", text, Citizen.ResultAsLong())
	if onScreen then
		SetTextScale(0.30, 0.30)
		SetTextFontForCurrentCommand(1)
		BgSetTextColor(255, 255, 255, 215)
		SetTextCentre(1)
		BgDisplayText(str, _x, _y)
		local factor = (string.len(text)) / 225
		DrawSprite("feeds", "hud_menu_4a", _x, _y + 0.0125, 0.015 + factor, 0.03, 0.1, 35, 35, 35, 190, false)
	end
end

AddEventHandler("onResourceStop", function(resourceName)
	if GetCurrentResourceName() == resourceName then
		FreezeEntityPosition(PlayerPedId(), false)
		for _, b in ipairs(blips) do
			RemoveBlip(b)
		end
		if createdobject then
			DeleteEntity(wepobject)
		end
		for ownerId, preview in pairs(nearbyPreviews) do
			if preview and DoesEntityExist(preview.entity) then
				DeleteEntity(preview.entity)
			end
		end
	end
end
)

local function drawtext(str, x, y, w, h, enableShadow, col1, col2, col3, a, centre)
	str = VarString(10, "LITERAL_STRING", str, Citizen.ResultAsLong())
	SetTextScale(w, h)
	BgSetTextColor(math.floor(col1), math.floor(col2), math.floor(col3), math.floor(a))
	SetTextCentre(centre)
	if enableShadow then
		SetTextDropshadow(1, 0, 0, 0, 255)
	end
	Citizen.InvokeNative(0xADA9255D, 10);
	BgDisplayText(str, x, y)
end

local function createobject(x, y, z, objecthash)
	if not createdobject then
		previewCoords = {x = x, y = y, z = z}
		wepobject = Citizen.InvokeNative(0x9888652B8BA77F73, objecthash, 0, x, y, z, true, 1.0)
		h = GetEntityHeading(wepobject)
		local tabley = GetEntityRotation(wepobject, 1)
		roll = tabley.x
		if next(added) ~= nil then
			for k, v in pairs(compss) do
				RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
			end
			for i = 1, #added do
				if added[i].model ~= 0 then
					LoadModel(added[i].model)
				end
				GiveWeaponComponentToEntity(wepobject, added[i].name, -1, true)
				if added[i].model ~= 0 then
					SetModelAsNoLongerNeeded(added[i].model)
				end
			end
		end
		createdobject = true
	end
end

local wasCreated = false
local lastSyncedH = nil
local lastSyncedRoll = nil
local lastSyncedAdded = {}

Citizen.CreateThread(function()
	repeat Wait(1000) until LocalPlayer.state.IsInSession
	while true do
		local sleep = 1000
		if createdobject then
			sleep = 0
			if not wasCreated then
				wasCreated = true
				lastSyncedH = h
				lastSyncedRoll = roll
				lastSyncedAdded = copy_components(added)
				TriggerServerEvent("coi_gunsmith:server:startPreview", globalhash, previewCoords, h, roll, added)
			end

			drawtext(Config.Language.rotateitem1, 0.25, 0.74, 0.3, 0.2, true, 255, 255, 255, 255, true)
			drawtext(Config.Language.rotateitem2, 0.25, 0.76, 0.3, 0.2, true, 255, 255, 255, 255, true)
			drawtext(Config.Language.rotateitem3, 0.25, 0.78, 0.3, 0.2, true, 255, 255, 255, 255, true)
			drawtext(Config.Language.rotateitem4, 0.25, 0.80, 0.3, 0.2, true, 255, 255, 255, 255, true)
			HasStreamedTextureDictLoaded("menu_textures")
			DrawSprite("menu_textures", "translate_bg_1a", 0.25, 0.78, 0.14, 0.12, 1.8, 0, 0, 0, 255, true)
			if whenKeyJustPressed(Config.General.keys["1"]) then
				h = h + 10
				SetEntityRotation(wepobject, roll % 360, 0, h % 360, 1, true)
			end
			if whenKeyJustPressed(Config.General.keys["2"]) then
				h = h - 10
				SetEntityRotation(wepobject, roll % 360, 0, h % 360, 1, true)
			end
			if whenKeyJustPressed(Config.General.keys["3"]) then
				roll = roll - 20
				SetEntityRotation(wepobject, roll % 360, 0, h % 360, 1, true)
			end
			if whenKeyJustPressed(Config.General.keys["4"]) then
				roll = roll + 20
				SetEntityRotation(wepobject, roll % 360, 0, h % 360, 1, true)
			end

			if h ~= lastSyncedH or roll ~= lastSyncedRoll or not table_equal(added, lastSyncedAdded) then
				lastSyncedH = h
				lastSyncedRoll = roll
				lastSyncedAdded = copy_components(added)
				TriggerServerEvent("coi_gunsmith:server:updatePreview", h, roll, added)
			end
		else
			if wasCreated then
				wasCreated = false
				TriggerServerEvent("coi_gunsmith:server:stopPreview")
			end
		end
		Wait(sleep)
	end
end)

CreateThread(function()
	repeat Wait(1000) until LocalPlayer.state.IsInSession
	while true do
		local sleep = 1000

		if not createdobject and not crafting then
			local coords = GetEntityCoords(PlayerPedId())

			for k, v in pairs(Config.General.customizationLocations) do
				local dist = GetDistanceBetweenCoords(coords.x, coords.y, coords.z, v.Pos.x, v.Pos.y, v.Pos.z, true)

				if dist < 1 then
					sleep = 0
					local Label = VarString(10, 'LITERAL_STRING', Config.Language.presstobuy)
					UiPromptSetActiveGroupThisFrame(OpenGroup, Label, 0, 0, 0, 0)

					if Citizen.InvokeNative(0xC92AC953F0A982AE, OpenStores) then
						if Config.General.jobonly then
							local result = Core.Callback.TriggerAwait("vorp_weapons:getjob")
							local playerjob = result[1]
							local playerrank = result[2]
							if jobcheck(Config.General.job, playerjob) and tonumber(playerrank) >= Config.General.jobrankcustomization then
								local closestPlayer, closestDistance, playerid, tgt1 = GetClosestPlayer()
								if closestPlayer ~= -1 and closestDistance <= 2.0 then
									TriggerEvent("vorp:TipBottom", Config.Language.tooclose, 4000)
								else
									if weaponid == nil then
										TriggerEvent("vorp:TipBottom", Config.Language.pleaserequip, 4000)
									else
										local ped = PlayerPedId()
										_, wepHash = GetCurrentPedWeapon(ped, true, 0, true)
										wep = GetCurrentPedWeaponEntityIndex(ped, 0)
										if globalhash ~= wepHash then
											TriggerEvent("vorp:TipBottom", Config.Language.pleaserequip, 4000)
										else
											if wep ~= nil and wep ~= 0 and globalhash ~= nil then
												TriggerEvent("vorp_weapons:wepcomp")
												Citizen.Wait(1000)
												WarMenu.OpenMenu('wepcomp')
												TaskStandStill(ped, -1)
												createobject(v.Pos2.x, v.Pos2.y, v.Pos2.z, globalhash)
											else
												TriggerEvent("vorp:TipBottom", Config.Language.pleaserequip, 4000)
											end
										end
									end
								end
							else
								TriggerEvent("vorp:TipBottom", Config.Language.wrongjobcuztom, 4000)
							end
						else
							local closestPlayer, closestDistance, playerid, tgt1 = GetClosestPlayer()
							if closestPlayer ~= -1 and closestDistance <= 2.0 then
								TriggerEvent("vorp:TipBottom", Config.Language.tooclose, 4000)
							else
								if weaponid == nil then
									TriggerEvent("vorp:TipBottom", Config.Language.pleaserequip, 4000)
								else
									local ped = PlayerPedId()
									_, wepHash = GetCurrentPedWeapon(ped, true, 0, true)
									wep = GetCurrentPedWeaponEntityIndex(ped, 0)
									if globalhash ~= wepHash then
										TriggerEvent("vorp:TipBottom", Config.Language.pleaserequip, 4000)
									else
										if wep ~= nil and wep ~= 0 and globalhash ~= nil then
											TriggerEvent("vorp_weapons:wepcomp")
											Citizen.Wait(1000)
											WarMenu.OpenMenu('wepcomp')
											createobject(v.Pos2.x, v.Pos2.y, v.Pos2.z, globalhash)
										else
											TriggerEvent("vorp:TipBottom", Config.Language.pleaserequip, 4000)
										end
									end
								end
							end
						end
					end
				end
			end
		end
		Wait(sleep)
	end
end)

CreateThread(function()
	repeat Wait(1000) until LocalPlayer.state.IsInSession
	PromptSetUp()

	while true do
		local letSleep = 1000

		if not crafting and not createdobject then
			local coords = GetEntityCoords(PlayerPedId())

			for k, v in pairs(Config.General.craftinglocation) do
				local dist = GetDistanceBetweenCoords(coords.x, coords.y, coords.z, v.Pos.x, v.Pos.y, v.Pos.z, false)
				if dist < 1 then
					letSleep    = 0
					local Label = VarString(10, 'LITERAL_STRING', Config.Language.presstocraft)
					UiPromptSetActiveGroupThisFrame(OpenGroup, Label, 0, 0, 0, 0)

					if Citizen.InvokeNative(0xC92AC953F0A982AE, OpenStores) then
						if Config.General.jobonly then
							local result = Core.Callback.TriggerAwait("vorp_weapons:getjob")
							local playerjob = result[1]
							local playerrank = result[2]
							if jobcheck(Config.General.job, playerjob) and tonumber(playerrank) >= Config.General.jobrankcrafting then
								crafting = true
								WarMenu.OpenMenu('crafting')
							else
								Core.NotifyObjective(Config.Language.wrongjobcrafting, 5000)
							end
						else
							crafting = true
							WarMenu.OpenMenu('crafting')
						end
					end
				end
			end
		end
		Wait(letSleep)
	end
end)








RegisterNetEvent("vorp_weapons:wepcomp")
AddEventHandler("vorp_weapons:wepcomp", function()
	local ped = PlayerPedId()
	local _, wepHash = GetCurrentPedWeapon(ped, true, 0, true)
	compss = {}
	if next(compss) == nil then
		for k, v in pairs(comps) do
			local hash = GetHashKey(k)
			if hash == wepHash then
				for x, l in pairs(v) do
					table.insert(compss, {
						label = l.label,
						model = l.model,
						name = l.name,
						type = l.type,
						comp = l.comp,
						confirmed = l.confirmed,
						price = l.price
					})
				end
			end
		end
	end
end)

CreateThread(function()
	repeat Wait(2000) until LocalPlayer.state.IsInSession

	WarMenu.CreateMenu('wepcomp', Config.Language.customization)
	WarMenu.CreateMenu('crafting', Config.Language.crafting)

	WarMenu.CreateSubMenu('wepcraft', 'crafting', Config.Language.weaponcrafting)
	WarMenu.CreateSubMenu('wepcraft2', 'wepcraft', Config.Language.weaponcrafting)
	WarMenu.CreateSubMenu('wepcraft3', 'wepcraft2', Config.Language.weaponcrafting)
	WarMenu.CreateSubMenu('ammocraft', 'crafting', Config.Language.ammocrafting)
	WarMenu.CreateSubMenu('ammocraft2', 'ammocraft', Config.Language.ammocrafting)
	WarMenu.CreateSubMenu('ammocraft3', 'ammocraft2', Config.Language.ammocrafting)
	WarMenu.CreateSubMenu('confirmexit2', 'crafting', Config.Language.areusureexit)
	WarMenu.CreateSubMenu('confirmed', 'wepcomp', Config.Language.customization)
	WarMenu.CreateSubMenu('comp', 'confirmed', Config.Language.comps)
	WarMenu.CreateSubMenu('scope', 'comp', Config.Language.sights)
	WarMenu.CreateSubMenu('rifling', 'comp', Config.Language.rifling)
	WarMenu.CreateSubMenu('other', 'comp', Config.Language.other)
	WarMenu.CreateSubMenu('scopecolor', 'confirmed', Config.Language.scopecolor)
	WarMenu.CreateSubMenu('wrap', 'comp', Config.Language.wrap)
	WarMenu.CreateSubMenu('wrapcolor', 'confirmed', Config.Language.wrapcolor)
	WarMenu.CreateSubMenu('barrel', 'confirmed', Config.Language.barrel)
	WarMenu.CreateSubMenu('trigger', 'confirmed', Config.Language.trigger)
	WarMenu.CreateSubMenu('variant', 'confirmed', Config.Language.variant)
	WarMenu.CreateSubMenu('frame', 'confirmed', Config.Language.frame)
	WarMenu.CreateSubMenu('frontsight', 'confirmed', Config.Language.frontsight)
	WarMenu.CreateSubMenu('cylinder', 'confirmed', Config.Language.cylinder)
	WarMenu.CreateSubMenu('gripbody', 'confirmed', Config.Language.gripbody)
	WarMenu.CreateSubMenu('grip', 'confirmed', Config.Language.grip)
	WarMenu.CreateSubMenu('decal', 'confirmed', Config.Language.decal)
	WarMenu.CreateSubMenu('decalcylinder', 'decal', Config.Language.decalcylinder)
	WarMenu.CreateSubMenu('decalframe', 'decal', Config.Language.decalframe)
	WarMenu.CreateSubMenu('decalbarrel', 'decal', Config.Language.decalbarrel)
	WarMenu.CreateSubMenu('decalcolor', 'confirmed', Config.Language.decalcolor)
	WarMenu.CreateSubMenu('cylinder2', 'decalcolor', Config.Language.cylinder2)
	WarMenu.CreateSubMenu('frame2', 'decalcolor', Config.Language.frame2)
	WarMenu.CreateSubMenu('barrel2', 'decalcolor', Config.Language.barrel2)
	WarMenu.CreateSubMenu('confirmexit', 'wepcomp', Config.Language.areusureexit)
	WarMenu.CreateSubMenu('confirmbuy', 'wepcomp', Config.Language.buyselect)
	local GetJob = false
	while true do
		if WarMenu.IsMenuOpened('wepcomp') then
			if cal == true then
				sum = 0
				for k, v in pairs(pricing) do
					sum = sum + v.price
				end
				cal = false
			end
			WarMenu.MenuButton(Config.Language.customization, "confirmed")
			WarMenu.Button(Config.Language.total .. sum .. Config.Language.dollar)
			WarMenu.MenuButton(Config.Language.buyselect, "confirmbuy")
			WarMenu.MenuButton(Config.Language.exitmenu, "confirmexit")
		elseif WarMenu.IsMenuOpened('crafting') then
			WarMenu.MenuButton(Config.Language.weaponcrafting, "wepcraft")
			WarMenu.MenuButton(Config.Language.ammocrafting, "ammocraft")
			WarMenu.MenuButton(Config.Language.exitmenu, "confirmexit2")
		elseif WarMenu.IsMenuOpened('wepcraft') then
			for k, _ in pairs(Config.weapons) do
				if WarMenu.MenuButton("" .. k .. "", "wepcraft2") then
					craftingammoitem = k
				end
			end
		elseif WarMenu.IsMenuOpened('wepcraft3') then
			if WarMenu.Button(Config.Language.craft) then
				TriggerServerEvent("vorp_weapons:itemscheck2", craftingammoitem2, itemtosend, materialtosend, craftcost)
				WarMenu.CloseMenu()
				GetJob = false
			end
			for k, v in pairs(Config.weapons) do
				if k == craftingammoitem then
					for l, m in pairs(v) do
						if l == craftingammoitem2 then
							if Config.General.craftingcost then
								if WarMenu.Button(Config.Language.craftcost .. "" .. m.craftcost .. "$") then end
							end
							for x, y in pairs(m.materials) do
								if WarMenu.Button(y.name .. " / " .. Config.Language.count .. y.amount) then end
							end
						end
					end
				end
			end
		elseif WarMenu.IsMenuOpened('wepcraft2') then
			local playerjob
			if not GetJob then
				GetJob       = true
				local result = Core.Callback.TriggerAwait("vorp_weapons:getjob")
				playerjob    = result[1]
			end
			for k, v in pairs(Config.weapons) do
				if k == craftingammoitem then
					for l, m in pairs(v) do
						if m.letcraft then
							if m.jobonly then
								for p, q in pairs(m.jobs) do
									if playerjob == q then
										if WarMenu.MenuButton("" .. l .. "", "wepcraft3") then
											craftingammoitem2 = l
											materialtosend = m.materials
											itemtosend = m.hashname
											craftcost = m.craftcost
										end
									end
								end
							else
								if WarMenu.MenuButton("" .. l .. "", "wepcraft3") then
									craftingammoitem2 = l
									materialtosend = m.materials
									itemtosend = m.hashname
									craftcost = m.craftcost
								end
							end
						end
					end
				end
			end
		elseif WarMenu.IsMenuOpened('ammocraft') then
			for k, v in pairs(Config.ammo) do
				if WarMenu.MenuButton("" .. k .. "", "ammocraft2") then
					craftingammoitem = k
				end
			end
		elseif WarMenu.IsMenuOpened('ammocraft3') then
			if WarMenu.Button(Config.Language.craft) then
				TriggerServerEvent("vorp_weapons:itemscheck", itemtosend, materialtosend, craftcost)
				WarMenu.CloseMenu()
				GetJob = false
			end
			for k, v in pairs(Config.ammo) do
				if k == craftingammoitem then
					for l, m in pairs(v) do
						if l == craftingammoitem2 then
							if Config.General.craftingcost then
								if WarMenu.Button(Config.Language.craftcost .. "" .. m.craftcost .. "$") then end
							end
							for x, y in pairs(m.materials) do
								if WarMenu.Button(y.name .. " / " .. Config.Language.count .. y.amount) then end
							end
						end
					end
				end
			end
		elseif WarMenu.IsMenuOpened('ammocraft2') then
			local playerjob
			if not GetJob then
				GetJob       = true
				local result = Core.Callback.TriggerAwait("vorp_weapons:getjob")
				playerjob    = result[1]
			end
			for k, v in pairs(Config.ammo) do
				if k == craftingammoitem then
					for l, m in pairs(v) do
						if m.letcraft then
							if m.jobonly then
								for p, q in pairs(m.jobs) do
									if playerjob == q then
										if WarMenu.MenuButton("" .. l .. "", "ammocraft3") then
											craftingammoitem2 = l
											materialtosend = m.materials
											itemtosend = m.item
											craftcost = m.craftcost
										end
									end
								end
							else
								if WarMenu.MenuButton("" .. l .. "", "ammocraft3") then
									craftingammoitem2 = l
									materialtosend = m.materials
									itemtosend = m.item
									craftcost = m.craftcost
								end
							end
						end
					end
				end
			end
		elseif WarMenu.IsMenuOpened('confirmexit2') then
			if WarMenu.Button(Config.Language.yes) then
				crafting = false
				craftingammoitem = nil
				craftingammoitem2 = nil
				itemtosend = nil
				materialtosend = nil
				craftcost = nil
				FreezeEntityPosition(PlayerPedId(), false)
				WarMenu.CloseMenu()
				GetJob = false
			end
			if WarMenu.MenuButton(Config.Language.no, "crafting") then end
		elseif WarMenu.IsMenuOpened('confirmbuy') then
			if WarMenu.Button(Config.Language.yes) then
				TriggerServerEvent("vorp_weapons:checkmoney", sum)
				pricing = {}
				sum = 0
				cal = false
				WarMenu.CloseMenu()
				GetJob = false
				Citizen.Wait(500)
			end
			if WarMenu.MenuButton(Config.Language.no, "wepcomp") then end
		elseif WarMenu.IsMenuOpened('confirmexit') then
			if WarMenu.Button(Config.Language.yes) then
				added = {}
				pricing = {}
				compss = {}
				sum = 0
				cal = false
				weaponid = nil
				wephash = nil
				globalhash = nil
				createdobject = false
				DeleteEntity(wepobject)
				FreezeEntityPosition(PlayerPedId(), false)
				WarMenu.CloseMenu()
				GetJob = false
			end
			if WarMenu.MenuButton(Config.Language.no, "wepcomp") then end
		elseif WarMenu.IsMenuOpened('confirmed') then
			if contains(compss, "variant", nil) then
				if WarMenu.MenuButton(Config.Language.variant, "variant") then end
			end
			if WarMenu.MenuButton(Config.Language.comps, "comp") then end
			if contains(compss, "barrel", nil) then
				if WarMenu.MenuButton(Config.Language.barrel, "barrel") then end
			end
			if contains(compss, "trigger", nil) then
				if WarMenu.MenuButton(Config.Language.trigger, "trigger") then end
			end
			if contains(compss, "frame", nil) then
				if WarMenu.MenuButton(Config.Language.frame, "frame") then end
			end
			if contains(compss, "frontsight", nil) then
				if WarMenu.MenuButton(Config.Language.frontsight, "frontsight") then end
			end
			if contains(compss, "cylinder", nil) then
				if WarMenu.MenuButton(Config.Language.cylinder, "cylinder") then end
			end
			if contains(compss, "gripbody", nil) then
				if WarMenu.MenuButton(Config.Language.gripbody, "gripbody") then end
			end
			if contains(compss, "grip", nil) then
				if WarMenu.MenuButton(Config.Language.grip, "grip") then end
			end
			if contains2(compss, "decal") then
				if WarMenu.MenuButton(Config.Language.decal, "decal") then end
			end
			if contains2(compss, "decalcolor") and contains2(added, "decal") then
				if WarMenu.MenuButton(Config.Language.decalcolor, "decalcolor") then end
			end
			if WarMenu.MenuButton(Config.Language.scopecolor, "scopecolor") then end
			if contains(added, "comp", "wrap") then
				if WarMenu.MenuButton(Config.Language.wrapcolor, "wrapcolor") then end
			end
		elseif WarMenu.IsMenuOpened('decal') then
			if contains(compss, "decal", "cylinder") then
				if WarMenu.MenuButton(Config.Language.decalcylinder, "decalcylinder") then end
			end
			if contains(compss, "decal", "frame") then
				if WarMenu.MenuButton(Config.Language.decalframe, "decalframe") then end
			end
			if contains(compss, "decal", "barrel") then
				if WarMenu.MenuButton(Config.Language.decalbarrel, "decalbarrel") then end
			end
		elseif WarMenu.IsMenuOpened('decalcolor') then
			if contains(compss, "decalcolor", "cylinder") and contains(added, "decal", "cylinder") then
				if WarMenu.MenuButton(Config.Language.cylinder2, "cylinder2") then end
			end
			if contains(compss, "decalcolor", "frame") and contains(added, "decal", "frame") then
				if WarMenu.MenuButton(Config.Language.frame2, "frame2") then end
			end
			if contains(compss, "decalcolor", "barrel") and contains(added, "decal", "barrel") then
				if WarMenu.MenuButton(Config.Language.barrel2, "barrel2") then end -- findme
			end
		elseif WarMenu.IsMenuOpened('comp') then
			if contains(compss, "comp", "scope") then
				if WarMenu.MenuButton(Config.Language.sights, "scope") then end
			end
			if contains(compss, "comp", "rifling") then
				if WarMenu.MenuButton(Config.Language.rifling, "rifling") then end
			end
			if contains(compss, "comp", "other") then
				if WarMenu.MenuButton(Config.Language.other, "other") then end
			end
			if contains(compss, "comp", "wrap") then
				if WarMenu.MenuButton(Config.Language.wrap, "wrap") then end
			end
		elseif WarMenu.IsMenuOpened('other') then
			if WarMenu.Button(Config.Language.remove) then
				cal = true
				for k, v in pairs(added) do
					if v.comp == "comp" and v.type == "other" then
						table.remove(added, k)
						RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
					end
				end
				for k, v in pairs(pricing) do
					if v.comp == "comp" and v.type == "other" then
						table.remove(pricing, k)
					end
				end
			end
			for i = 1, #compss do
				if compss[i].confirmed == 1 then
					if compss[i].comp == "comp" then
						if compss[i].type == "other" then
							if WarMenu.MenuButton(Config.Language.label ..
									compss[i].label .. Config.Language.price .. compss[i].price .. Config.Language.dollar, "comp") then
								if next(pricing) ~= nil then
									for k, v in pairs(pricing) do
										if v.name == compss[i].name or
											(v.name ~= compss[i].name and v.comp == compss[i].comp and v.type == compss[i].type) then
											table.remove(pricing, k)
										end
									end
									table.insert(pricing, {
										price = compss[i].price,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								else
									table.insert(pricing, {
										price = compss[i].price,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								end
								if next(added) ~= nil then
									for k, v in pairs(added) do
										if v.name == compss[i].name or
											(v.name ~= compss[i].name and v.comp == compss[i].comp and v.type == compss[i].type) then
											table.remove(added, k)
										end
									end
									table.insert(added, {
										label = compss[i].label,
										model = compss[i].model,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								else
									table.insert(added, {
										label = compss[i].label,
										model = compss[i].model,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								end
								for k, v in pairs(compss) do
									if v.comp == compss[i].comp and v.type == compss[i].type then
										RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
									end
								end
								cal = true
								if compss[i].model ~= 0 then
									LoadModel(compss[i].model)
									modelz = true
								end

								GiveWeaponComponentToEntity(wepobject, compss[i].name, -1, true)


								if modelz then
									SetModelAsNoLongerNeeded(compss[i].model)
									modelz = false
								end
							end
						end
					end
				end
			end
		elseif WarMenu.IsMenuOpened('wrap') then
			if WarMenu.Button(Config.Language.remove) then
				cal = true
				for k, v in pairs(added) do
					if v.comp == "comp" and v.type == "wrap" then
						table.remove(added, k)
						RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
					end
				end
				for k, v in pairs(pricing) do
					if v.comp == "comp" and v.type == "wrap" then
						table.remove(pricing, k)
					end
				end
			end
			for i = 1, #compss do
				if compss[i].confirmed == 1 then
					if compss[i].comp == "comp" then
						if compss[i].type == "wrap" then
							if WarMenu.MenuButton(Config.Language.label ..
									compss[i].label .. Config.Language.price .. compss[i].price .. Config.Language.dollar, "comp") then
								if next(pricing) ~= nil then
									for k, v in pairs(pricing) do
										if v.name == compss[i].name or
											(v.name ~= compss[i].name and v.comp == compss[i].comp and v.type == compss[i].type) then
											table.remove(pricing, k)
										end
									end
									table.insert(pricing, {
										price = compss[i].price,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								else
									table.insert(pricing, {
										price = compss[i].price,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								end
								if next(added) ~= nil then
									for k, v in pairs(added) do
										if v.name == compss[i].name or
											(v.name ~= compss[i].name and v.comp == compss[i].comp and v.type == compss[i].type) then
											table.remove(added, k)
										end
									end
									table.insert(added, {
										label = compss[i].label,
										model = compss[i].model,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								else
									table.insert(added, {
										label = compss[i].label,
										model = compss[i].model,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								end
								for k, v in pairs(compss) do
									if v.comp == compss[i].comp and v.type == compss[i].type then
										RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
									end
								end
								cal = true
								if compss[i].model ~= 0 then
									LoadModel(compss[i].model)
									modelz = true
								end

								GiveWeaponComponentToEntity(wepobject, compss[i].name, -1, true)


								if modelz then
									SetModelAsNoLongerNeeded(compss[i].model)
									modelz = false
								end
							end
						end
					end
				end
			end
		elseif WarMenu.IsMenuOpened('scope') then
			if WarMenu.Button(Config.Language.remove) then
				cal = true
				for k, v in pairs(added) do
					if v.comp == "comp" and v.type == "scope" then
						table.remove(added, k)
						RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
					end
				end
				for k, v in pairs(pricing) do
					if v.comp == "comp" and v.type == "scope" then
						table.remove(pricing, k)
					end
				end
			end
			for i = 1, #compss do
				if compss[i].confirmed == 1 then
					if compss[i].comp == "comp" then
						if compss[i].type == "scope" then
							if WarMenu.MenuButton(Config.Language.label ..
									compss[i].label .. Config.Language.price .. compss[i].price .. Config.Language.dollar, "comp") then
								if next(pricing) ~= nil then
									for k, v in pairs(pricing) do
										if v.name == compss[i].name or
											(v.name ~= compss[i].name and v.comp == compss[i].comp and v.type == compss[i].type) then
											table.remove(pricing, k)
										end
									end
									table.insert(pricing, {
										price = compss[i].price,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								else
									table.insert(pricing, {
										price = compss[i].price,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								end
								if next(added) ~= nil then
									for k, v in pairs(added) do
										if v.name == compss[i].name or
											(v.name ~= compss[i].name and v.comp == compss[i].comp and v.type == compss[i].type) then
											table.remove(added, k)
										end
									end
									table.insert(added, {
										label = compss[i].label,
										model = compss[i].model,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								else
									table.insert(added, {
										label = compss[i].label,
										model = compss[i].model,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								end
								for k, v in pairs(compss) do
									if v.comp == compss[i].comp and v.type == compss[i].type then
										RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
									end
								end
								cal = true
								if compss[i].model ~= 0 then
									LoadModel(compss[i].model)
									modelz = true
								end

								GiveWeaponComponentToEntity(wepobject, compss[i].name, -1, true)


								if modelz then
									SetModelAsNoLongerNeeded(compss[i].model)
									modelz = false
								end
							end
						end
					end
				end
			end
		elseif WarMenu.IsMenuOpened('rifling') then
			if WarMenu.Button(Config.Language.remove) then
				cal = true
				for k, v in pairs(added) do
					if v.comp == "comp" and v.type == "rifling" then
						table.remove(added, k)
						RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
					end
				end
				for k, v in pairs(pricing) do
					if v.comp == "comp" and v.type == "rifling" then
						table.remove(pricing, k)
					end
				end
			end
			for i = 1, #compss do
				if compss[i].confirmed == 1 then
					if compss[i].comp == "comp" then
						if compss[i].type == "rifling" then
							if WarMenu.MenuButton(Config.Language.label ..
									compss[i].label .. Config.Language.price .. compss[i].price .. Config.Language.dollar, "comp") then
								if next(pricing) ~= nil then
									for k, v in pairs(pricing) do
										if v.name == compss[i].name or
											(v.name ~= compss[i].name and v.comp == compss[i].comp and v.type == compss[i].type) then
											table.remove(pricing, k)
										end
									end
									table.insert(pricing, {
										price = compss[i].price,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								else
									table.insert(pricing, {
										price = compss[i].price,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								end
								if next(added) ~= nil then
									for k, v in pairs(added) do
										if v.name == compss[i].name or
											(v.name ~= compss[i].name and v.comp == compss[i].comp and v.type == compss[i].type) then
											table.remove(added, k)
										end
									end
									table.insert(added, {
										label = compss[i].label,
										model = compss[i].model,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								else
									table.insert(added, {
										label = compss[i].label,
										model = compss[i].model,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								end
								for k, v in pairs(compss) do
									if v.comp == compss[i].comp and v.type == compss[i].type then
										RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
									end
								end
								cal = true
								if compss[i].model ~= 0 then
									LoadModel(compss[i].model)
									modelz = true
								end

								GiveWeaponComponentToEntity(wepobject, compss[i].name, -1, true)


								if modelz then
									SetModelAsNoLongerNeeded(compss[i].model)
									modelz = false
								end
							end
						end
					end
				end
			end
		elseif WarMenu.IsMenuOpened('barrel2') then
			if WarMenu.Button(Config.Language.remove) then
				cal = true -- findme
				for k, v in pairs(added) do
					if v.comp == "decalcolor" and v.type == "barrel" then
						table.remove(added, k)
						RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
					end
				end
				for k, v in pairs(pricing) do
					if v.comp == "decalcolor" and v.type == "barrel" then
						table.remove(pricing, k)
					end
				end
			end
			for i = 1, #compss do
				if compss[i].confirmed == 1 then
					if compss[i].comp == "decalcolor" then
						if compss[i].type == "barrel" then
							if WarMenu.Button(Config.Language.label ..
									compss[i].label .. Config.Language.price .. compss[i].price .. Config.Language.dollar) then
								if next(pricing) ~= nil then
									for k, v in pairs(pricing) do
										if v.name == compss[i].name or
											(v.name ~= compss[i].name and v.comp == compss[i].comp and v.type == compss[i].type) then
											table.remove(pricing, k)
										end
									end
									table.insert(pricing, {
										price = compss[i].price,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								else
									table.insert(pricing, {
										price = compss[i].price,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								end
								if next(added) ~= nil then
									for k, v in pairs(added) do
										if v.name == compss[i].name or
											(v.name ~= compss[i].name and v.comp == compss[i].comp and v.type == compss[i].type) then
											table.remove(added, k)
										end
									end
									table.insert(added, {
										label = compss[i].label,
										model = compss[i].model,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								else
									table.insert(added, {
										label = compss[i].label,
										model = compss[i].model,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								end
								for k, v in pairs(compss) do
									if v.comp ~= "comp" then
										if v.comp == compss[i].comp and v.type == compss[i].type then
											RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
										end
									end
								end
								cal = true
								if compss[i].model ~= 0 then
									LoadModel(compss[i].model)
									modelz = true
								end

								GiveWeaponComponentToEntity(wepobject, compss[i].name, -1, true)


								if modelz then
									SetModelAsNoLongerNeeded(compss[i].model)
									modelz = false
								end
							end
						end
					end
				end
			end
		elseif WarMenu.IsMenuOpened('frame2') then
			if WarMenu.Button(Config.Language.remove) then
				cal = true
				for k, v in pairs(added) do
					if v.comp == "decalcolor" and v.type == "frame" then
						table.remove(added, k)

						RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
					end
				end
				for k, v in pairs(pricing) do
					if v.comp == "decalcolor" and v.type == "frame" then
						table.remove(pricing, k)
					end
				end
			end
			for i = 1, #compss do
				if compss[i].confirmed == 1 then
					if compss[i].comp == "decalcolor" then
						if compss[i].type == "frame" then
							if WarMenu.Button(Config.Language.label ..
									compss[i].label .. Config.Language.price .. compss[i].price .. Config.Language.dollar) then
								if next(pricing) ~= nil then
									for k, v in pairs(pricing) do
										if v.name == compss[i].name or
											(v.name ~= compss[i].name and v.comp == compss[i].comp and v.type == compss[i].type) then
											table.remove(pricing, k)
										end
									end
									table.insert(pricing, {
										price = compss[i].price,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								else
									table.insert(pricing, {
										price = compss[i].price,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								end
								if next(added) ~= nil then
									for k, v in pairs(added) do
										if v.name == compss[i].name or
											(v.name ~= compss[i].name and v.comp == compss[i].comp and v.type == compss[i].type) then
											table.remove(added, k)
										end
									end
									table.insert(added, {
										label = compss[i].label,
										model = compss[i].model,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								else
									table.insert(added, {
										label = compss[i].label,
										model = compss[i].model,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								end
								for k, v in pairs(compss) do
									if v.comp ~= "comp" then
										if v.comp == compss[i].comp and v.type == compss[i].type then
											RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
										end
									end
								end
								cal = true
								if compss[i].model ~= 0 then
									LoadModel(compss[i].model)
									modelz = true
								end

								GiveWeaponComponentToEntity(wepobject, compss[i].name, -1, true)


								if modelz then
									SetModelAsNoLongerNeeded(compss[i].model)
									modelz = false
								end
							end
						end
					end
				end
			end
		elseif WarMenu.IsMenuOpened('cylinder2') then
			if WarMenu.Button(Config.Language.remove) then
				cal = true
				for k, v in pairs(added) do
					if v.comp == "decalcolor" and v.type == "cylinder" then
						table.remove(added, k)

						RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
					end
					for k, v in pairs(pricing) do
						if v.comp == "decalcolor" and v.type == "cylinder" then
							table.remove(pricing, k)
						end
					end
				end
			end
			for i = 1, #compss do
				if compss[i].confirmed == 1 then
					if compss[i].comp == "decalcolor" then
						if compss[i].type == "cylinder" then
							if WarMenu.Button(Config.Language.label ..
									compss[i].label .. Config.Language.price .. compss[i].price .. Config.Language.dollar) then
								if next(pricing) ~= nil then
									for k, v in pairs(pricing) do
										if v.name == compss[i].name or
											(v.name ~= compss[i].name and v.comp == compss[i].comp and v.type == compss[i].type) then
											table.remove(pricing, k)
										end
									end
									table.insert(pricing, {
										price = compss[i].price,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								else
									table.insert(pricing, {
										price = compss[i].price,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								end
								if next(added) ~= nil then
									for k, v in pairs(added) do
										if v.name == compss[i].name or
											(v.name ~= compss[i].name and v.comp == compss[i].comp and v.type == compss[i].type) then
											table.remove(added, k)
										end
									end
									table.insert(added, {
										label = compss[i].label,
										model = compss[i].model,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								else
									table.insert(added, {
										label = compss[i].label,
										model = compss[i].model,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								end
								for k, v in pairs(compss) do
									if v.comp ~= "comp" then
										if v.comp == compss[i].comp and v.type == compss[i].type then
											RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
										end
									end
								end
								if compss[i].model ~= 0 then
									LoadModel(compss[i].model)
									modelz = true
								end
								cal = true
								GiveWeaponComponentToEntity(wepobject, compss[i].name, -1, true)


								if modelz then
									SetModelAsNoLongerNeeded(compss[i].model)
									modelz = false
								end
							end
						end
					end
				end
			end
		elseif WarMenu.IsMenuOpened('decalbarrel') then
			if WarMenu.Button(Config.Language.remove) then
				cal = true
				for k, v in pairs(added) do
					if v.comp == "decal" and v.type == "barrel" then
						table.remove(added, k)

						RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
					end
				end
				for k, v in pairs(pricing) do
					if v.comp == "decal" and v.type == "barrel" then
						table.remove(pricing, k)
					end
				end
			end
			for i = 1, #compss do
				if compss[i].confirmed == 1 then
					if compss[i].comp == "decal" then
						if compss[i].type == "barrel" then
							if WarMenu.Button(Config.Language.label ..
									compss[i].label .. Config.Language.price .. compss[i].price .. Config.Language.dollar) then
								if next(pricing) ~= nil then
									for k, v in pairs(pricing) do
										if v.name == compss[i].name or
											(v.name ~= compss[i].name and v.comp == compss[i].comp and v.type == compss[i].type) then
											table.remove(pricing, k)
										end
									end
									table.insert(pricing, {
										price = compss[i].price,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								else
									table.insert(pricing, {
										price = compss[i].price,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								end
								if next(added) ~= nil then
									for k, v in pairs(added) do
										if v.name == compss[i].name or
											(v.name ~= compss[i].name and v.comp == compss[i].comp and v.type == compss[i].type) then
											table.remove(added, k)
										end
									end
									table.insert(added, {
										label = compss[i].label,
										model = compss[i].model,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								else
									table.insert(added, {
										label = compss[i].label,
										model = compss[i].model,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								end
								for k, v in pairs(compss) do
									if v.comp ~= "comp" then
										if v.comp == compss[i].comp and v.type == compss[i].type then
											RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
										end
									end
								end
								if compss[i].model ~= 0 then
									LoadModel(compss[i].model)
									modelz = true
								end

								GiveWeaponComponentToEntity(wepobject, compss[i].name, -1, true)
								cal = true

								if modelz then
									SetModelAsNoLongerNeeded(compss[i].model)
									modelz = false
								end
							end
						end
					end
				end
			end
		elseif WarMenu.IsMenuOpened('decalframe') then
			if WarMenu.Button(Config.Language.remove) then
				cal = true
				for k, v in pairs(added) do
					if v.comp == "decal" and v.type == "frame" then
						table.remove(added, k)

						RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
					end
				end
				for k, v in pairs(pricing) do
					if v.comp == "decal" and v.type == "frame" then
						table.remove(pricing, k)
					end
				end
			end
			for i = 1, #compss do
				if compss[i].confirmed == 1 then
					if compss[i].comp == "decal" then
						if compss[i].type == "frame" then
							if WarMenu.Button(Config.Language.label ..
									compss[i].label .. Config.Language.price .. compss[i].price .. Config.Language.dollar) then
								if next(pricing) ~= nil then
									for k, v in pairs(pricing) do
										if v.name == compss[i].name or
											(v.name ~= compss[i].name and v.comp == compss[i].comp and v.type == compss[i].type) then
											table.remove(pricing, k)
										end
									end
									table.insert(pricing, {
										price = compss[i].price,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								else
									table.insert(pricing, {
										price = compss[i].price,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								end
								if next(added) ~= nil then
									for k, v in pairs(added) do
										if v.name == compss[i].name or
											(v.name ~= compss[i].name and v.comp == compss[i].comp and v.type == compss[i].type) then
											table.remove(added, k)
										end
									end
									table.insert(added, {
										label = compss[i].label,
										model = compss[i].model,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								else
									table.insert(added, {
										label = compss[i].label,
										model = compss[i].model,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								end
								for k, v in pairs(compss) do
									if v.comp ~= "comp" then
										if v.comp == compss[i].comp and v.type == compss[i].type then
											RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
										end
									end
								end
								if compss[i].model ~= 0 then
									LoadModel(compss[i].model)
									modelz = true
								end
								cal = true
								GiveWeaponComponentToEntity(wepobject, compss[i].name, -1, true)


								if modelz then
									SetModelAsNoLongerNeeded(compss[i].model)
									modelz = false
								end
							end
						end
					end
				end
			end
		elseif WarMenu.IsMenuOpened('decalcylinder') then
			if WarMenu.Button(Config.Language.remove) then
				cal = true
				for k, v in pairs(added) do
					if v.comp == "decal" and v.type == "cylinder" then
						table.remove(added, k)
						RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
					end
				end
				for k, v in pairs(pricing) do
					if v.comp == "decal" and v.type == "cylinder" then
						table.remove(pricing, k)
					end
				end
			end
			for i = 1, #compss do
				if compss[i].confirmed == 1 then
					if compss[i].comp == "decal" then
						if compss[i].type == "cylinder" then
							if WarMenu.Button(Config.Language.label ..
									compss[i].label .. Config.Language.price .. compss[i].price .. Config.Language.dollar) then
								if next(pricing) ~= nil then
									for k, v in pairs(pricing) do
										if v.name == compss[i].name or
											(v.name ~= compss[i].name and v.comp == compss[i].comp and v.type == compss[i].type) then
											table.remove(pricing, k)
										end
									end
									table.insert(pricing, {
										price = compss[i].price,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								else
									table.insert(pricing, {
										price = compss[i].price,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								end
								if next(added) ~= nil then
									for k, v in pairs(added) do
										if v.name == compss[i].name or
											(v.name ~= compss[i].name and v.comp == compss[i].comp and v.type == compss[i].type) then
											table.remove(added, k)
										end
									end
									table.insert(added, {
										label = compss[i].label,
										model = compss[i].model,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								else
									table.insert(added, {
										label = compss[i].label,
										model = compss[i].model,
										comp = compss[i].comp,
										type = compss[i].type,
										name = compss[i].name
									})
								end
								for k, v in pairs(compss) do
									if v.comp ~= "comp" then
										if v.comp == compss[i].comp and v.type == compss[i].type then
											RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
										end
									end
								end
								if compss[i].model ~= 0 then
									LoadModel(compss[i].model)
									modelz = true
								end
								cal = true
								GiveWeaponComponentToEntity(wepobject, compss[i].name, -1, true)


								if modelz then
									SetModelAsNoLongerNeeded(compss[i].model)
									modelz = false
								end
							end
						end
					end
				end
			end
		elseif WarMenu.IsMenuOpened('grip') then
			if WarMenu.Button(Config.Language.remove) then
				cal = true
				for k, v in pairs(added) do
					if v.comp == "grip" then
						table.remove(added, k)

						RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
					end
				end
				for k, v in pairs(pricing) do
					if v.comp == "grip" then
						table.remove(pricing, k)
					end
				end
			end
			for i = 1, #compss do
				if compss[i].confirmed == 1 then
					if compss[i].comp == "grip" then
						if WarMenu.Button(Config.Language.label ..
								compss[i].label .. Config.Language.price .. compss[i].price .. Config.Language.dollar) then
							if next(pricing) ~= nil then
								for k, v in pairs(pricing) do
									if v.name ~= compss[i].name and v.comp == compss[i].comp then
										table.remove(pricing, k)
									end
								end
								table.insert(pricing, {
									price = compss[i].price,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							else
								table.insert(pricing, {
									price = compss[i].price,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							end
							if next(added) ~= nil then
								for k, v in pairs(added) do
									if v.name ~= compss[i].name and v.comp == compss[i].comp then
										table.remove(added, k)
									end
								end
								table.insert(added, {
									label = compss[i].label,
									model = compss[i].model,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							else
								table.insert(added, {
									label = compss[i].label,
									model = compss[i].model,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							end
							for k, v in pairs(compss) do
								if v.comp ~= "comp" then
									if v.comp == compss[i].comp then
										RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
									end
								end
							end
							if compss[i].model ~= 0 then
								LoadModel(compss[i].model)
								modelz = true
							end

							GiveWeaponComponentToEntity(wepobject, compss[i].name, -1, true)
							cal = true

							if modelz then
								SetModelAsNoLongerNeeded(compss[i].model)
								modelz = false
							end
						end
					end
				end
			end
		elseif WarMenu.IsMenuOpened('scopecolor') then
			if WarMenu.Button(Config.Language.remove) then
				cal = true
				for k, v in pairs(added) do
					if v.comp == "scope" then
						table.remove(added, k)
						RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
					end
				end
				for k, v in pairs(pricing) do
					if v.comp == "scope" then
						table.remove(pricing, k)
					end
				end
			end
			for i = 1, #compss do
				if compss[i].confirmed == 1 then
					if compss[i].comp == "scope" then
						if WarMenu.Button(Config.Language.label ..
								compss[i].label .. Config.Language.price .. compss[i].price .. Config.Language.dollar) then
							if next(pricing) ~= nil then
								for k, v in pairs(pricing) do
									if v.name ~= compss[i].name and v.comp == compss[i].comp then
										table.remove(pricing, k)
									end
								end
								table.insert(pricing, {
									price = compss[i].price,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							else
								table.insert(pricing, {
									price = compss[i].price,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							end
							if next(added) ~= nil then
								for k, v in pairs(added) do
									if v.name ~= compss[i].name and v.comp == compss[i].comp then
										table.remove(added, k)
									end
								end
								table.insert(added, {
									label = compss[i].label,
									model = compss[i].model,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							else
								table.insert(added, {
									label = compss[i].label,
									model = compss[i].model,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							end
							for k, v in pairs(compss) do
								if v.comp ~= "comp" then
									if v.comp == compss[i].comp then
										RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
									end
								end
							end
							if compss[i].model ~= 0 then
								LoadModel(compss[i].model)
								modelz = true
							end
							cal = true
							GiveWeaponComponentToEntity(wepobject, compss[i].name, -1, true)


							if modelz then
								SetModelAsNoLongerNeeded(compss[i].model)
								modelz = false
							end
						end
					end
				end
			end
		elseif WarMenu.IsMenuOpened('wrapcolor') then
			if WarMenu.Button(Config.Language.remove) then
				cal = true
				for k, v in pairs(added) do
					if v.comp == "wrapcolor" then
						table.remove(added, k)
						RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
					end
				end
				for k, v in pairs(pricing) do
					if v.comp == "wrapcolor" then
						table.remove(pricing, k)
					end
				end
			end
			for i = 1, #compss do
				if compss[i].confirmed == 1 then
					if compss[i].comp == "wrapcolor" then
						if WarMenu.Button(Config.Language.label ..
								compss[i].label .. Config.Language.price .. compss[i].price .. Config.Language.dollar) then
							if next(pricing) ~= nil then
								for k, v in pairs(pricing) do
									if v.name ~= compss[i].name and v.comp == compss[i].comp then
										table.remove(pricing, k)
									end
								end
								table.insert(pricing, {
									price = compss[i].price,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							else
								table.insert(pricing, {
									price = compss[i].price,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							end
							if next(added) ~= nil then
								for k, v in pairs(added) do
									if v.name ~= compss[i].name and v.comp == compss[i].comp then
										table.remove(added, k)
									end
								end
								table.insert(added, {
									label = compss[i].label,
									model = compss[i].model,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							else
								table.insert(added, {
									label = compss[i].label,
									model = compss[i].model,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							end
							for k, v in pairs(compss) do
								if v.comp ~= "comp" then
									if v.comp == compss[i].comp then
										RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
									end
								end
							end
							if compss[i].model ~= 0 then
								LoadModel(compss[i].model)
								modelz = true
							end

							GiveWeaponComponentToEntity(wepobject, compss[i].name, -1, true)
							cal = true

							if modelz then
								SetModelAsNoLongerNeeded(compss[i].model)
								modelz = false
							end
						end
					end
				end
			end
		elseif WarMenu.IsMenuOpened('gripbody') then
			for i = 1, #compss do
				if compss[i].confirmed == 1 then
					if compss[i].comp == "gripbody" then
						if WarMenu.Button(Config.Language.label ..
								compss[i].label .. Config.Language.price .. compss[i].price .. Config.Language.dollar) then
							if next(pricing) ~= nil then
								for k, v in pairs(pricing) do
									if v.name ~= compss[i].name and v.comp == compss[i].comp then
										table.remove(pricing, k)
									end
								end
								table.insert(pricing, {
									price = compss[i].price,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							else
								table.insert(pricing, {
									price = compss[i].price,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							end
							if next(added) ~= nil then
								for k, v in pairs(added) do
									if v.name ~= compss[i].name and v.comp == compss[i].comp then
										table.remove(added, k)
									end
								end
								table.insert(added, {
									label = compss[i].label,
									model = compss[i].model,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							else
								table.insert(added, {
									label = compss[i].label,
									model = compss[i].model,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							end
							for k, v in pairs(compss) do
								if v.comp ~= "comp" then
									if v.comp == compss[i].comp then
										RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
									end
								end
							end
							if compss[i].model ~= 0 then
								LoadModel(compss[i].model)
								modelz = true
							end
							cal = true
							GiveWeaponComponentToEntity(wepobject, compss[i].name, -1, true)


							if modelz then
								SetModelAsNoLongerNeeded(compss[i].model)
								modelz = false
							end
						end
					end
				end
			end
		elseif WarMenu.IsMenuOpened('cylinder') then
			if WarMenu.Button(Config.Language.remove) then
				cal = true
				for k, v in pairs(added) do
					if v.comp == "cylinder" then
						table.remove(added, k)

						RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
					end
				end
				for k, v in pairs(pricing) do
					if v.comp == "cylinder" then
						table.remove(pricing, k)
					end
				end
			end
			for i = 1, #compss do
				if compss[i].confirmed == 1 then
					if compss[i].comp == "cylinder" then
						if WarMenu.Button(Config.Language.label ..
								compss[i].label .. Config.Language.price .. compss[i].price .. Config.Language.dollar) then
							if next(pricing) ~= nil then
								for k, v in pairs(pricing) do
									if v.name ~= compss[i].name and v.comp == compss[i].comp then
										table.remove(pricing, k)
									end
								end
								table.insert(pricing, {
									price = compss[i].price,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							else
								table.insert(pricing, {
									price = compss[i].price,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							end
							if next(added) ~= nil then
								for k, v in pairs(added) do
									if v.name ~= compss[i].name and v.comp == compss[i].comp then
										table.remove(added, k)
									end
								end
								table.insert(added, {
									label = compss[i].label,
									model = compss[i].model,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							else
								table.insert(added, {
									label = compss[i].label,
									model = compss[i].model,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							end
							for k, v in pairs(compss) do
								if v.comp ~= "comp" then
									if v.comp == compss[i].comp then
										RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
									end
								end
							end
							if compss[i].model ~= 0 then
								LoadModel(compss[i].model)
								modelz = true
							end
							cal = true
							GiveWeaponComponentToEntity(wepobject, compss[i].name, -1, true)


							if modelz then
								SetModelAsNoLongerNeeded(compss[i].model)
								modelz = false
							end
						end
					end
				end
			end
		elseif WarMenu.IsMenuOpened('frontsight') then
			if WarMenu.Button(Config.Language.remove) then
				cal = true
				for k, v in pairs(added) do
					if v.comp == "frontsight" then
						table.remove(added, k)

						RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
					end
				end
				for k, v in pairs(pricing) do
					if v.comp == "frontsight" then
						table.remove(pricing, k)
					end
				end
			end
			for i = 1, #compss do
				if compss[i].confirmed == 1 then
					if compss[i].comp == "frontsight" then
						if WarMenu.Button(Config.Language.label ..
								compss[i].label .. Config.Language.price .. compss[i].price .. Config.Language.dollar) then
							if next(pricing) ~= nil then
								for k, v in pairs(pricing) do
									if v.name ~= compss[i].name and v.comp == compss[i].comp then
										table.remove(pricing, k)
									end
								end
								table.insert(pricing, {
									price = compss[i].price,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							else
								table.insert(pricing, {
									price = compss[i].price,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							end
							if next(added) ~= nil then
								for k, v in pairs(added) do
									if v.name ~= compss[i].name and v.comp == compss[i].comp then
										table.remove(added, k)
									end
								end
								table.insert(added, {
									label = compss[i].label,
									model = compss[i].model,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							else
								table.insert(added, {
									label = compss[i].label,
									model = compss[i].model,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							end
							for k, v in pairs(compss) do
								if v.comp ~= "comp" then
									if v.comp == compss[i].comp then
										RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
									end
								end
							end
							if compss[i].model ~= 0 then
								LoadModel(compss[i].model)
								modelz = true
							end
							cal = true
							GiveWeaponComponentToEntity(wepobject, compss[i].name, -1, true)


							if modelz then
								SetModelAsNoLongerNeeded(compss[i].model)
								modelz = false
							end
						end
					end
				end
			end
		elseif WarMenu.IsMenuOpened('frame') then
			if WarMenu.Button(Config.Language.remove) then
				cal = true
				for k, v in pairs(added) do
					if v.comp == "frame" then
						table.remove(added, k)

						RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
					end
				end
				for k, v in pairs(pricing) do
					if v.comp == "frame" then
						table.remove(pricing, k)
					end
				end
			end
			for i = 1, #compss do
				if compss[i].confirmed == 1 then
					if compss[i].comp == "frame" then
						if WarMenu.Button(Config.Language.label ..
								compss[i].label .. Config.Language.price .. compss[i].price .. Config.Language.dollar) then
							if next(pricing) ~= nil then
								for k, v in pairs(pricing) do
									if v.name ~= compss[i].name and v.comp == compss[i].comp then
										table.remove(pricing, k)
									end
								end
								table.insert(pricing, {
									price = compss[i].price,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							else
								table.insert(pricing, {
									price = compss[i].price,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							end
							if next(added) ~= nil then
								for k, v in pairs(added) do
									if v.name ~= compss[i].name and v.comp == compss[i].comp then
										table.remove(added, k)
									end
								end
								table.insert(added, {
									label = compss[i].label,
									model = compss[i].model,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							else
								table.insert(added, {
									label = compss[i].label,
									model = compss[i].model,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							end
							for k, v in pairs(compss) do
								if v.comp ~= "comp" then
									if v.comp == compss[i].comp then
										RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
									end
								end
							end
							if compss[i].model ~= 0 then
								LoadModel(compss[i].model)
								modelz = true
							end

							GiveWeaponComponentToEntity(wepobject, compss[i].name, -1, true)
							cal = true

							if modelz then
								SetModelAsNoLongerNeeded(compss[i].model)
								modelz = false
							end
						end
					end
				end
			end
		elseif WarMenu.IsMenuOpened('trigger') then
			if WarMenu.Button(Config.Language.remove) then
				cal = true
				for k, v in pairs(added) do
					if v.comp == "trigger" then
						table.remove(added, k)
						RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
					end
				end
				for k, v in pairs(pricing) do
					if v.comp == "trigger" then
						table.remove(pricing, k)
					end
				end
			end
			for i = 1, #compss do
				if compss[i].confirmed == 1 then
					if compss[i].comp == "trigger" then
						if WarMenu.Button(Config.Language.label ..
								compss[i].label .. Config.Language.price .. compss[i].price .. Config.Language.dollar) then
							if next(pricing) ~= nil then
								for k, v in pairs(pricing) do
									if v.name ~= compss[i].name and v.comp == compss[i].comp then
										table.remove(pricing, k)
									end
								end
								table.insert(pricing, {
									price = compss[i].price,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							else
								table.insert(pricing, {
									price = compss[i].price,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							end
							if next(added) ~= nil then
								for k, v in pairs(added) do
									if v.name ~= compss[i].name and v.comp == compss[i].comp then
										table.remove(added, k)
									end
								end
								table.insert(added, {
									label = compss[i].label,
									model = compss[i].model,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							else
								table.insert(added, {
									label = compss[i].label,
									model = compss[i].model,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							end
							for k, v in pairs(compss) do
								if v.comp ~= "comp" then
									if v.comp == compss[i].comp then
										RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
									end
								end
							end
							if compss[i].model ~= 0 then
								LoadModel(compss[i].model)
								modelz = true
							end
							cal = true
							GiveWeaponComponentToEntity(wepobject, compss[i].name, -1, true)


							if modelz then
								SetModelAsNoLongerNeeded(compss[i].model)
								modelz = false
							end
						end
					end
				end
			end
		elseif WarMenu.IsMenuOpened('variant') then
			if WarMenu.Button(Config.Language.remove) then
				cal = true
				for k, v in pairs(added) do
					if v.comp == "variant" then
						table.remove(added, k)

						RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
					end
				end
				for k, v in pairs(pricing) do
					if v.comp == "variant" then
						table.remove(pricing, k)
					end
				end
			end
			for i = 1, #compss do
				if compss[i].confirmed == 1 then
					if compss[i].comp == "variant" then
						if WarMenu.Button(Config.Language.label ..
								compss[i].label .. Config.Language.price .. compss[i].price .. Config.Language.dollar) then
							if next(pricing) ~= nil then
								for k, v in pairs(pricing) do
									if v.name ~= compss[i].name and v.comp == compss[i].comp then
										table.remove(pricing, k)
									end
								end
								table.insert(pricing, {
									price = compss[i].price,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							else
								table.insert(pricing, {
									price = compss[i].price,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							end
							if next(added) ~= nil then
								for k, v in pairs(added) do
									if v.name ~= compss[i].name and v.comp == compss[i].comp then
										table.remove(added, k)
									end
								end
								table.insert(added, {
									label = compss[i].label,
									model = compss[i].model,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							else
								table.insert(added, {
									label = compss[i].label,
									model = compss[i].model,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							end
							for k, v in pairs(compss) do
								if v.comp ~= "comp" then
									if v.comp == compss[i].comp then
										RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
									end
								end
							end
							if compss[i].model ~= 0 then
								LoadModel(compss[i].model)
								modelz = true
							end
							cal = true
							GiveWeaponComponentToEntity(wepobject, compss[i].name, -1, true)


							if modelz then
								SetModelAsNoLongerNeeded(compss[i].model)
								modelz = false
							end
						end
					end
				end
			end
		elseif WarMenu.IsMenuOpened('barrel') then
			if WarMenu.Button(Config.Language.remove) then
				cal = true
				for k, v in pairs(added) do
					if v.comp == "barrel" then
						table.remove(added, k)
						RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
					end
				end
				for k, v in pairs(pricing) do
					if v.comp == "barrel" then
						table.remove(pricing, k)
					end
				end
			end
			for i = 1, #compss do
				if compss[i].confirmed == 1 then
					if compss[i].comp == "barrel" then
						if WarMenu.Button(Config.Language.label ..
								compss[i].label .. Config.Language.price .. compss[i].price .. Config.Language.dollar) then
							if next(pricing) ~= nil then
								for k, v in pairs(pricing) do
									if v.name ~= compss[i].name and v.comp == compss[i].comp then
										table.remove(pricing, k)
									end
								end
								table.insert(pricing, {
									price = compss[i].price,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							else
								table.insert(pricing, {
									price = compss[i].price,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							end
							if next(added) ~= nil then
								for k, v in pairs(added) do
									if v.name ~= compss[i].name and v.comp == compss[i].comp then
										table.remove(added, k)
									end
								end
								table.insert(added, {
									label = compss[i].label,
									model = compss[i].model,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							else
								table.insert(added, {
									label = compss[i].label,
									model = compss[i].model,
									comp = compss[i].comp,
									type = compss[i].type,
									name = compss[i].name
								})
							end
							for k, v in pairs(compss) do
								if v.comp ~= "comp" then
									if v.comp == compss[i].comp then
										RemoveWeaponComponentFromWeaponObject(wepobject, v.name)
									end
								end
							end
							if compss[i].model ~= 0 then
								LoadModel(compss[i].model)
								modelz = true
							end
							cal = true
							GiveWeaponComponentToEntity(wepobject, compss[i].name, -1, true)


							if modelz then
								SetModelAsNoLongerNeeded(compss[i].model)
								modelz = false
							end
						end
					end
				end
			end
		end
		WarMenu.Display()
		Wait(0)
	end
end)

RegisterNetEvent("vorp_weapons:givecomp", function(components, id, hash)
	globalhash = hash
	weaponid = id
	added = components
	local ped = PlayerPedId()
	wep = GetCurrentPedWeaponEntityIndex(ped, 0)
	_, wepHash = GetCurrentPedWeapon(ped, true, 0, true)
	TriggerEvent("vorp_weapons:wepcomp")
	for k, v in pairs(compss) do
		RemoveWeaponComponentFromPed(PlayerPedId(), v.name, globalhash)
	end
	Wait(500)
	for i = 1, #components do
		if components[i].model ~= 0 then
			LoadModel(components[i].model)
		end
		GiveWeaponComponentToEntity(PlayerPedId(), components[i].name, globalhash, true)
		if components[i].model ~= 0 then
			SetModelAsNoLongerNeeded(components[i].model)
		end
	end
end)

RegisterNetEvent("coi_gunsmith:client:syncPreviewStart", function(ownerId, hash, coords, h, roll, components)
	if ownerId == GetPlayerServerId(PlayerId()) then return end
	activePreviewsData[ownerId] = {
		hash = hash,
		coords = coords,
		h = h,
		roll = roll,
		components = components
	}
end)

RegisterNetEvent("coi_gunsmith:client:syncPreviewUpdate", function(ownerId, h, roll, components)
	if ownerId == GetPlayerServerId(PlayerId()) then return end
	if activePreviewsData[ownerId] then
		local oldComponents = activePreviewsData[ownerId].components
		activePreviewsData[ownerId].h = h
		activePreviewsData[ownerId].roll = roll
		activePreviewsData[ownerId].components = components

		local preview = nearbyPreviews[ownerId]
		if preview and DoesEntityExist(preview.entity) then
			SetEntityRotation(preview.entity, roll % 360, 0, h % 360, 1, true)
			if not table_equal(oldComponents, components) then
				for i = 1, #preview.appliedComponents do
					RemoveWeaponComponentFromWeaponObject(preview.entity, preview.appliedComponents[i])
				end
				local applied = {}
				for i = 1, #components do
					if components[i].model ~= 0 then
						LoadModel(components[i].model)
					end
					GiveWeaponComponentToEntity(preview.entity, components[i].name, -1, true)
					table.insert(applied, components[i].name)
					if components[i].model ~= 0 then
						SetModelAsNoLongerNeeded(components[i].model)
					end
				end
				preview.appliedComponents = applied
			end
		end
	end
end)

RegisterNetEvent("coi_gunsmith:client:syncPreviewStop", function(ownerId)
	if ownerId == GetPlayerServerId(PlayerId()) then return end
	activePreviewsData[ownerId] = nil
	local preview = nearbyPreviews[ownerId]
	if preview then
		if DoesEntityExist(preview.entity) then
			DeleteEntity(preview.entity)
		end
		nearbyPreviews[ownerId] = nil
	end
end)

RegisterNetEvent("coi_gunsmith:client:receiveActivePreviews", function(previews)
	for ownerId, data in pairs(previews) do
		if ownerId ~= GetPlayerServerId(PlayerId()) then
			activePreviewsData[ownerId] = data
		end
	end
end)

Citizen.CreateThread(function()
	while true do
		local ped = PlayerPedId()
		local playerCoords = GetEntityCoords(ped)
		for ownerId, data in pairs(activePreviewsData) do
			local dist = #(playerCoords - vector3(data.coords.x, data.coords.y, data.coords.z))
			if dist <= 20.0 then
				if not nearbyPreviews[ownerId] then
					local entity = Citizen.InvokeNative(0x9888652B8BA77F73, data.hash, 0, data.coords.x, data.coords.y, data.coords.z, true, 1.0)
					SetEntityRotation(entity, data.roll % 360, 0, data.h % 360, 1, true)
					FreezeEntityPosition(entity, true)
					local applied = {}
					for i = 1, #data.components do
						if data.components[i].model ~= 0 then
							LoadModel(data.components[i].model)
						end
						GiveWeaponComponentToEntity(entity, data.components[i].name, -1, true)
						table.insert(applied, data.components[i].name)
						if data.components[i].model ~= 0 then
							SetModelAsNoLongerNeeded(data.components[i].model)
						end
					end
					nearbyPreviews[ownerId] = {
						entity = entity,
						appliedComponents = applied
					}
				end
			else
				if nearbyPreviews[ownerId] then
					if DoesEntityExist(nearbyPreviews[ownerId].entity) then
						DeleteEntity(nearbyPreviews[ownerId].entity)
					end
					nearbyPreviews[ownerId] = nil
				end
			end
		end
		Wait(1000)
	end
end)

Citizen.CreateThread(function()
	repeat Wait(1000) until LocalPlayer.state.IsInSession
	TriggerServerEvent("coi_gunsmith:server:requestActivePreviews")
end)
