local hook, table, print, ents, timer, IsValid = hook, table, print, ents, timer, IsValid
local tostring = tostring

hook.Add( "InitPostEntity", "APAPostEntity", function()
	timer.Simple(0.001, function() -- Delay so we are the last call.
		APA.PostEntity = true
	end)
end)

function APA.log(tag,...)
	if APA.Settings.Debug:GetInt() <= 0 then return end

	local str = tostring(os.date("%H:%M"))..'| [APA-DEBUG]'..tostring(tag)
	print(str,...)
	if APA.Settings.Debug:GetInt() >= 2 then
		ServerLog(str,...)
	end
end
local log = APA.log

function APA.EntityCheck( entClass )
	local good, bad = false, false

	for _,v in pairs(APA.Settings.L.Black) do
		if( string.find( string.lower(entClass), string.lower(v) ) ) then
			bad = true
			break -- No need to go through the rest of the loop.
		end
	end

	for _,v in pairs(APA.Settings.L.White) do
		if( string.find( string.lower(entClass), string.lower(v) ) ) then
			good = true
			break
		end
	end

	log('[Check] Checking',entClass,'Good:',good,'Bad:',bad)
	return good, bad, entClass
end

function APA.isPlayer(ent)
	if not ent or ent == nil or ent == NULL then return false end
	return IsValid(ent) and (ent.GetClass and ent:GetClass() == "player") or (ent.IsPlayer and ent:IsPlayer()) or false
end
local isPlayer = APA.isPlayer

function APA.FindProp(attacker, inflictor)
	if( attacker:IsPlayer() ) then attacker = inflictor end
	return ( IsValid(attacker) and attacker.GetClass ) and attacker or nil
end

function APA.WeaponCheck(attacker, inflictor)
	for _,ent in next, {attacker, inflictor} do
		if ent and IsValid(ent) and (isPlayer(ent) or (ent.IsWeapon and ent:IsWeapon()) or (ent.IsNPC and ent:IsNPC())) then 
			return true
		end
	end
	return false
end

function APA.physStop(phys)
	if phys == NULL or not IsValid(phys) then return false end

	if type(phys) == "PhysObj" then
		phys:SetVelocityInstantaneous(Vector(0,0,0))
		phys:AddAngleVelocity(phys:GetAngleVelocity()*-1)
		phys:Sleep()
	elseif isPlayer(phys) then
		phys:SetVelocity(phys:GetVelocity()*-1)
	else
		phys = IsValid(phys) and phys:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetVelocityInstantaneous(Vector(0,0,0))
			phys:AddAngleVelocity(phys:GetAngleVelocity()*-1)
			phys:Sleep()
			return phys
		end
	end
end
local physStop = APA.physStop

local function DamageFilter( target, d ) -- d for damage info.
	local attacker, inflictor, damage, type = d:GetAttacker(), d:GetInflictor(), d:GetDamage(), d:GetDamageType()
	local dents = {attacker, inflictor}

	local isvehicle = (attacker:IsVehicle() or inflictor:IsVehicle())
	local isexplosion = d:IsExplosionDamage()

	local targetClass = IsValid(target) and target.GetClass and target:GetClass() or nil
	if string.find(string.lower(targetClass), "prop_") == 1 and APA.Settings.UnbreakableProps:GetBool() then return true end

	for _,v in next, dents do
		local propdmg = (v.GetClass and (string.find(string.lower(v:GetClass()), "prop_") == 1))
		local good, bad, ugly = APA.EntityCheck( (IsValid(v) and v.GetClass) and v:GetClass() or '' )

		bad = APA.Settings.Method:GetBool() and bad or (APA.IsEntBad and APA.IsEntBad(v))

		if APA.hasCPPI and APA.Settings.KillOwnership and propdmg and isPlayer(APA.FindOwner(v)) then
			d:SetAttacker(APA.FindOwner(v))
		end

		if APA.Settings.PropsOnly:GetBool() then
			bad = propdmg and bad or false
			if not bad then good = true end
		end

		if v.APAForceBlock then bad = true end

		log('[Damage]1) Checking Entity',v,'Is Vehicle: '..tostring(isvehicle),'Is Explosion: '..tostring(isexplosion))
		log('[Damage]2) Checking Entity',v,'Is Bad: '..tostring(bad),'Is Prop Damage: '..tostring(propdmg))
		log('[Damage]3) Checking Entity',v,'Is Good: '..tostring(good),'Is Fall: '..tostring(d:IsFallDamage()))
		log('[Damage]4) Checking Entity',v,'Is Flagged:',v:GetNWBool("APABadEntity", false))

		if APA.Settings.OnlyPlayers and not isPlayer(target) and not v.APAForceBlock then return end

		if APA.WeaponCheck(attacker, inflictor) then return end

		if (APA.Settings.BlockVehicleDamage:GetBool() and isvehicle) or (APA.Settings.BlockExplosionDamage:GetBool() and isexplosion) then
			d:SetDamage(0) d:ScaleDamage(0) d:SetDamageForce(Vector())
			return true 
		end

		if (bad or (APA.Settings.BlockPropDamage:GetBool() and propdmg)) and not (good or d:IsFallDamage()) then
			if APA.Settings.BlockWorldDamage:GetBool() and inflictor == 'worldspawn' then return true end
			if APA.Settings.AntiPK:GetBool() and not isvehicle and not isexplosion then 
				d:SetDamage(0) d:ScaleDamage(0) d:SetDamageForce(Vector())

				if APA.Settings.FreezeOnHit:GetBool() or v.APAForceFreeze then
					if damage >= 10 then
						local phys = IsValid(v) and v:GetPhysicsObject()
						if IsValid(phys) then
							if isPlayer(target) then 
								physStop(target)
							end
							physStop(phys)
							phys:Sleep()
							if not v:IsPlayer() then
								phys:EnableMotion(false)
							else
								phys:Wake()
							end
							timer.Simple(0.01, function() 
								if isPlayer(target) then
									physStop(target)
								end 
							end)

							if (v.APAForceFreeze and v.APAForceFreeze >= 2) and not APA.Settings.FreezeOnHit:GetBool() then 
								phys:EnableMotion(true)
								phys:Sleep()
							end
						end
					end
				end

				return true
			end
		end
	end
end
hook.Add( "EntityTakeDamage", "APAntiPk", DamageFilter )

hook.Add( "PlayerSpawnedProp", "APAntiExplode", function( _, _, prop )
	if( IsValid(prop) and APA.Settings.BlockExplosionDamage:GetInt() >= 1 ) then
		if not string.find( string.lower(prop:GetClass()), "wire" ) then -- Wiremod causes problems.
			log('[Block]','Removed explosion from',prop)
			prop:SetKeyValue("ExplodeDamage", "0") 
			prop:SetKeyValue("ExplodeRadius", "0")
		end
	end
end)

hook.Add("StartCommand", "APAStartCmd", function(ply, mv)
	if isPlayer(ply) and ply:GetEyeTrace().Entity.APANoPhysgun and ply:GetEyeTrace().Entity.APANoPhysgun > CurTime() then
		local ent = ply:GetEyeTrace().Entity
		if mv:GetMouseWheel() != 0 and (ent.APANoPhysgun-0.55) <= CurTime() then  
			ent.APANoPhysgun = CurTime()+0.7
		end
		mv:SetButtons(bit.band(mv:GetButtons(),bit.bnot(IN_ATTACK)))
	end
end)

if not APA.hasCPPI then error('[APA] CPPI not found, APAnti will be heavily limited.') return end


function APA.FindOwner( ent )
	local owner, _ = ent:CPPIGetOwner()
	return owner or ent.FPPOwner or nil -- Fallback to FPP variable if CPPI fails.
end

function APA.ModelNameFix( model )
	return tostring(string.gsub(model, "[\\/ %;]+", "/"):gsub("%.%..", "")) or nil
end

local function ModelFilter(mdl) -- Return true to block model.
	local mdl = APA.ModelNameFix(tostring(mdl)) or nil
	if not mdl then return true end
	-- Model Blocking Code Here --
end

function APA.IsWorld( ent )
	if not IsValid(ent) then return true end
	local iw = ent.IsWorld and ent:IsWorld()

	if iw then return true end
	if (ent.GetPersistent and ent:GetPersistent()) then return true end
	if (not ent.GetClass) then return true end
	
	if not ent.APAMem and not APA.FindOwner(ent) then return true end
	if not APA.FindOwner(ent) then return true end

	if ent.PhysgunDisabled or ent.NoDeleting or ent.jailWall then return true end
	if ent.CreatedByMap and ent:CreatedByMap() then return true end
	if isPlayer(ent) or (ent.IsNPC and ent:IsNPC()) then return true end
	-- Instant break points for faster usage.

	local blacklist = {"func_", "env_", "info_", "predicted_", "chatindicator", "prop_door_"}
	local ec = string.lower(ent:GetClass())
	for _,v in next, blacklist do
		if string.find( ec, string.lower(v) ) then
			return true
		end
	end

	return false
end


local function SpawnFilter(ply, model)
	local ent = not ply:IsPlayer() and ply or nil
	local model = model and APA.ModelNameFix( model )

	if ent then 
		ent.__APAPhysgunHeld = ent.__APAPhysgunHeld or {}
	end

	timer.Simple(0.001, function()
		if IsValid(ent) and ent:IsVehicle() then
			if APA.Settings.NoCollideVehicles:GetBool() then 
				ent:SetCollisionGroup(COLLISION_GROUP_WEAPON)
			end
			if APA.Settings.BlockVehicleDamage:GetBool() and not ent.APAVehicleCollision then
				ent.APAVehicleCollision = function(ent, c)
					if not APA.Settings.BlockVehicleDamage:GetBool() then return end
					c.PhysObject:EnableCollisions(false)
					timer.Simple(0, function()
						if not IsValid(c.PhysObject) then return end
						c.PhysObject:EnableCollisions(true)
					end)
				end
				ent:AddCallback( "PhysicsCollide", ent.APAVehicleCollision )
			end
		end
	end)
end
hook.Add( "OnEntityCreated", "APAntiSpawns", SpawnFilter)

local function PlayerSpawnFilter(ply, model, ent)
	local ent = isentity(model) and model or ent
	hook.Run("APA.PlayerSpawnedObject", ply, ent) -- A nice hook for others. So they don't have to spam hook.Add like I did.

	ent.APAMem = ent.APAMem or {}

	local settings_maxmass = APA.Settings.MaxMass:GetInt() >= 1
	local settings_propsnocollide = APA.Settings.PropsNoCollide:GetInt() >= 1

	if settings_propsnocollide or settings_maxmass then
		local phys = IsValid(ent) and ent:GetPhysicsObject()
		if IsValid(phys) then
			ent.APAMem.Collision = COLLISION_GROUP_NONE -- Predicted.
			if not ent:IsVehicle() then 
				if settings_maxmass and phys:GetMass() > APA.Settings.MaxMass:GetInt() then phys:SetMass(APA.Settings.MaxMass:GetInt()) end
				if settings_propsnocollide then ent:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE_DEBRIS) end
			end
		end
	end
end

local hookall = {
	"PlayerSpawnedEffect", 	"PlayerSpawnedNPC",
	"PlayerSpawnedProp", 	"PlayerSpawnedRagdoll",
	"PlayerSpawnedSENT", 	"PlayerSpawnedSWEP",
	"PlayerSpawnedVehicle", -- The hooks we want to bind.
}
for _,v in next, hookall do hook.Add(v, "APAntiSpawned", PlayerSpawnFilter) end

hook.Add( "PlayerSpawnObject", "APAntiSpawns", function(ply,mdl) if mdl and ModelFilter(mdl) then return false end end)
hook.Add( "AllowPlayerPickup", "APAntiPickup", function(ply,ent) 
	local good, bad, ugly = ent.GetClass and APA.EntityCheck(ent:GetClass())
	if bad or not good then return false end
end)

hook.Add( "PhysgunPickup", "APAIndex", function(ply,ent)
	if ent and ent.APANoPhysgun and ent.APANoPhysgun > CurTime() then return false end
	ent.APANoPhysgun = nil

	if (IsValid(ply) and IsValid(ent)) and ent.CPPICanPhysgun and ent:CPPICanPhysgun(ply) then
		local puid = tostring(ply:UniqueID())
		
		ent.__APAPhysgunHeld = ent.__APAPhysgunHeld or {}
		ent.__APAPhysgunHeld[puid] = true

		if APA.Settings.PropsNoCollide:GetInt() >= 1 and ent.APAMem then
			local collision = ent:GetCollisionGroup()
			ent.APAMem.Collision = (collision == COLLISION_GROUP_INTERACTIVE_DEBRIS) and COLLISION_GROUP_NONE or collision
			if collision == COLLISION_GROUP_NONE then 
				ent:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE_DEBRIS) 
			end
		end
	end
end)

hook.Add( "PhysgunDrop", "APANoThrow", function(ply,ent)
	if APA.Settings.NoThrow:GetBool() and IsValid(ent) then
		for _,v in next, constraint.GetAllConstrainedEntities(ent) do
			if IsValid(v) then
				local phys = v.GetPhysicsObject and v:GetPhysicsObject() or nil
				APA.physStop(phys)
			end
		end
	end
	if APA.Settings.FreezeOnDrop:GetBool() and IsValid(ent) and ent.GetClass and table.HasValue(APA.Settings.L.Freeze, string.lower(ent:GetClass())) then
		local phys = ent.GetPhysicsObject and ent:GetPhysicsObject() or nil 
		if IsValid(phys) then phys:EnableMotion(false) end
	end
	if (IsValid(ply) and IsValid(ent)) and ent.CPPICanPhysgun and ent:CPPICanPhysgun(ply) and ent.__APAPhysgunHeld then
		ent.__APAPhysgunHeld[tostring(ply:UniqueID())] = nil
	end
end)

hook.Add("OnPhysgunFreeze", "APAPhysgunFreeze", function(_, phys, ent, ply)
	if (IsValid(ply) and IsValid(ent)) and ent.APAMem and ent.APAMem.Collision then
		ent:SetCollisionGroup(ent.APAMem.Collision)
	end
end)


function APA.NoLag()
	local k = 0
	for _,v in next, ents.GetAll() do
		if IsValid(v) and v.GetClass and table.HasValue(APA.Settings.L.Freeze, string.lower(v:GetClass())) then
			if next(v.__APAPhysgunHeld or {}) == nil then
				timer.Simple(k/100,function() -- Prevent possible crashes or lag on freeze sweep.
					local v = v:GetPhysicsObject()
					if IsValid(v) then v:EnableMotion(false) end
				end)
				k = k + 1
			end
		end
	end
end

timer.Create("APAFreezePassive", 2.1, 0, function()
	if APA.Settings.FreezePassive:GetBool() then
		APA.NoLag()
	end
end)

hook.Add( "OnPhysgunReload", "APAMassUnfreeze", function(gun,ply)
	if APA.Settings.StopMassUnfreeze:GetBool() then
		local returnfalse = false
		if gun.APAunfreezetimeout and gun.APAunfreezetimeout > CurTime() then returnfalse = true end
		gun.APAunfreezetimeout = CurTime()+0.5
		if returnfalse then return false end
	else
		gun.APAunfreezetimeout = nil
	end
	if APA.Settings.StopRUnfreeze:GetBool() then
		APA.Notify(ply, "Cannot Unfreeze Using Reload!", NOTIFY_ERROR, 1, 0)
		return false 
	end
end)