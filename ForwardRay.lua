--[[
	[0] = true,		--Deleted units
	[1] = true,		--Environment (static)
	[2] = true,		--Player unit
	[3] = true,		--Team, mask on
	[4] = true,		--
	[5] = true,		--Team, mask off
	[6] = true,		--
	[7] = true,		--First person camera
	[8] = true,		--Shield
	[9] = true,		--
	[10] = true,		--
	[11] = true,		--Environment (dynamic)
	[12] = true,		--Enemy
	[13] = true,		--3rd person weapon / in-flight projectile
	[14] = true, 	--Bag / trip mine? / grenade
	[15] = true,		--
	[16] = true,		--Team AI mask on / joker
	[17] = true,		--Corpse
	[18] = true,		--Dropped helmet
	[19] = true,		--
	[20] = true,		--Linked projectiles
	[21] = true,		--Civilian (free/escort/moved)
	[22] = true,		--Hostage (civilian unmoved, surrendered enemy on host only)
	[23] = true,		--Ammo pickups
	[24] = true,		--Team AI mask off
	[25] = true,		--SWAT Turret / sentry gun
	[26] = true,		--Dead/inactive SWAT turret / sentry gun
	[27] = true,		--
	[28] = true,		--
	[29] = true,		--Environment (decorative)
	[30] = true,		--
	[31] = true,		--
	[32] = true,		--
	[33] = true,		--
	[34] = true,		--
	[35] = true,		--
	[36] = true,		--
	[37] = true,		--
	[38] = true,		--
	[39] = true,		--Vehicles
]]

local init_original = PlayerStandard.init
local update_original = PlayerStandard.update
local inventory_clbk_listener_original = PlayerStandard.inventory_clbk_listener

function PlayerStandard:init(...)
	init_original(self, ...)
	self._fwd_ray_new = ForwardRay:new(self._unit)
end

function PlayerStandard:update(t, dt, ...)
	update_original(self, t, dt, ...)
	self._fwd_ray_new:update(t, dt)
end

function PlayerStandard:inventory_clbk_listener(...)
	inventory_clbk_listener_original(self, ...)
	
	local wbase = alive(self._equipped_unit) and self._equipped_unit:base()
	if wbase then
		self._fwd_ray_new:update_weapon_attributes(
			wbase._can_shoot_through_enemy, 
			wbase._can_shoot_through_shield, 
			wbase._can_shoot_through_wall, 
			wbase._bullet_slotmask)
	end
end

function PlayerStandard:get_forward_ray_new()
	return self._fwd_ray_new
end


ForwardRay = ForwardRay or class()

function ForwardRay:init(unit)
	self._unit = unit
	self._hits = {}
	self._ray_distance = nil
	self._ray_position = nil
	self._ray_range = 20000
	self._ray_direction = Vector3()
	
	self._slotmasks = {
		environment = World:make_slot_mask(1, 11),
		shield = World:make_slot_mask(8),
		person = World:make_slot_mask(3, 5, 12, 16, 17, 21, 22, 24),
			criminal = World:make_slot_mask(3, 5, 16, 24),
				player_criminal = World:make_slot_mask(3, 5),
				ai_criminal = World:make_slot_mask(16, 24),
			enemy = World:make_slot_mask(12),
			civilian = World:make_slot_mask(21),
			hostage = World:make_slot_mask(22),
			corpse = World:make_slot_mask(17),
			joker = World:make_slot_mask(16),
		turret = World:make_slot_mask(25, 26),
			sentry_gun = World:make_slot_mask(25),
			inactive_sentry_gun = World:make_slot_mask(26),
		bag = World:make_slot_mask(14),
		car = World:make_slot_mask(39),
	}
	
	self._slotmasks_subtypes = {
		person = { "criminal", "joker" ,"enemy", "civilian", "hostage", "corpse" },
		turret = { "swat_turret", "sentry_gun", "inactive_swat_turret", "inactive_sentry_gun" },
		--camera = { "security_camera", "titan_camera" }
	}
	
	self._ray_slotmask = World:make_slot_mask(1)
	for type, slots in pairs(self._slotmasks) do
		self._ray_slotmask = self._ray_slotmask + slots
	end
end

function ForwardRay:update_weapon_attributes(penetrate_enemy, penetrate_shield, penetrate_wall, slotmask)
	self._penetrate_enemy = penetrate_enemy
	self._penetrate_shield = penetrate_shield
	self._penetrate_wall = penetrate_wall
	self._weapon_slotmask = slotmask
end

local from = Vector3()
local to = Vector3()
function ForwardRay:update(t, dt)
	self._hits = {}
	self._ray_distance = nil
	self._ray_position = nil
	
	mvector3.set(self._ray_direction, self._unit:camera():forward())
	mvector3.set(from, self._unit:camera():position())
	mvector3.set(to, self._ray_direction)
	mvector3.multiply(to, self._ray_range)
	mvector3.add(to, from)
	
	self:_update_ray(from, to, self._ray_direction)
end

function ForwardRay:get_distance()
	return self._ray_distance
end

function ForwardRay:get_position()
	return self._ray_position
end

function ForwardRay:get_targets(vision, hit)
	return self:get_targets_by_slotmask(nil, vision, hit)
end

function ForwardRay:get_targets_by_type(target_type, vision, hit)
	local valid_types = {}
	
	if type(target_type) == "table" then
		for _, t in ipairs(target_type) do
			valid_types[t] = true
			for _, st in ipairs(self._slotmasks_subtypes[t] or {}) do
				valid_types[st] = true
			end
		end
	else
		valid_types[target_type] = true
	end
	
	local hits = {}
	
	for i, data in ipairs(self._hits) do
		if alive(data.unit) and valid_types[data.type] then
			if (not vision or data.in_view) and (not hit or data.can_hit) then
				table.insert(hits, data)
			else
				break
			end
		end
	end

	return hits
end

function ForwardRay:get_targets_by_slotmask(slotmask, vision, hit)
	local hits = {}
	
	for i, data in ipairs(self._hits) do
		if alive(data.unit) and (not slotmask or data.unit:in_slot(slotmask)) then
			if (not vision or data.in_view) and (not hit or data.can_hit) then
				table.insert(hits, data)
			else
				break
			end
		end
	end

	return hits
end

function ForwardRay:_update_ray(from, to, direction, data)
	local function add_unit(unit_type, unit, body, ray_data)
		table.insert(self._hits, {
			type = unit_type,
			unit = unit,
			body = body,
			slot = unit:slot(),
			distance = ray_data.total_distance,
			in_view = not ray_data.vision_blocked,
			in_direct_view = not ray_data.direct_vision_blocked,
			can_hit = not ray_data.shot_blocked,
		})
	end

	local slotmask = data and data.slotmask or self._ray_slotmask
	local ignore_units = data and data.ignore_units or {}
	local ray_from_unit = data and alive(data.ray_from_unit) and data.ray_from_unit
	
	local ray = (ray_from_unit or World):raycast("ray", from, to, "slot_mask", slotmask, "ignore_unit", ignore_units)

	if not ray then return end
	--[[
	--TODO: Find a common factor in breakable, shoot-through units as opposed to units with body damage (e.g. shatterable windows vs damagable windshields)
	--This particular code is likely there to separate things that break between initial and delayed penetration raycast
	if data and data.has_hit_wall and not data.shot_blocked then
		local tmp = Vector3()
		mvector3.set(tmp, ray.ray)
		mvector3.multiply(tmp, -5)
		mvector3.add(tmp, ray.position)
		if World:raycast( "ray", tmp, from, "slot_mask", self._weapon_slotmask, "report" ) then
			data.shot_blocked = true
		end
	end
	]]
	if ray.unit then
		local unit = ray.unit
		local body = ray.body
		local is_wall
		local is_solid = true
	
		data = data or {
			total_distance = 0,
			ignore_units = ignore_units,
		}
		
		data.total_distance = data.total_distance + ray.distance
	
		if unit:in_slot(self._slotmasks.environment) then --World geometry
			if not body:has_ray_type(Idstring("ai_vision")) --[[and unit:damage() and body:extension() and body:extension().damage]]  then --Transparent, shoot-through material
				table.insert(data.ignore_units, unit)
				is_solid = false
			else --Solid, non-shoot-through w/o penetration
				is_wall = true
				
				if unit:base() and unit:base().security_camera then	--Camera special case
					add_unit("camera", unit, body, data)
				elseif unit:carry_data() and unit:carry_data():carry_id() and unit:interaction():active() then --Loot pickup special case
					add_unit("bag", unit, body, data)
				end
				
				data.shot_blocked = data.shot_blocked or (data.has_hit_wall or not self._penetrate_wall) --Non-titan cams are technically shoot-through
				data.vision_blocked = true
				data.has_hit_wall = true
			end
		else --Dynamic entity
			if unit:in_slot(self._slotmasks.shield) then --Shield
				if unit:in_slot(self._weapon_slotmask) then
					data.shot_blocked = data.shot_blocked or not (self._penetrate_shield and alive(unit:parent())) --Shots are inexplicably blocked by orphaned shields..
				end
			else
				if unit:in_slot(self._slotmasks.person) then --Person
					local unit_type
					if unit:in_slot(self._slotmasks.criminal) then --AI Criminal / joker
						if managers.groupai:state():all_AI_criminals()[unit:key()] then
							unit_type = "criminal"
						elseif unit:in_slot(16) then
							unit_type = "joker"
						end
					elseif unit:in_slot(self._slotmasks.enemy) then --Enemy
						unit_type = "enemy"
					elseif unit:in_slot(self._slotmasks.civilian) then --Civilian
						unit_type = "civilian"
					elseif unit:in_slot(self._slotmasks.hostage) then --Civilian/enemy hostage
						--unit_type = managers.enemy:is_civilian(unit) and "civilian" or "enemy"
						unit_type = "hostage"
					elseif unit:in_slot(self._slotmasks.corpse) then --Corpse
						unit_type = "corpse"
					end
					
					add_unit(unit_type, unit, body, data)
					if unit:in_slot(self._weapon_slotmask) then
						data.shot_blocked = data.shot_blocked or not self._penetrate_enemy
					end
				elseif unit:in_slot(self._slotmasks.turret) then --Turret
					local enemy_turret_ids = {
						swat_van_turret_module = true, 
						ceiling_turret_module = true,
					}
					local unit_type
					if unit:in_slot(self._slotmasks.sentry_gun) then
						unit_type = tostring(unit:base():get_type())
						--unit_type = enemy_turret_ids[unit:base()._tweak_table_id] and "swat_turret" or "sentry_gun"
					elseif unit:in_slot(self._slotmasks.inactive_sentry_gun) then
						unit_type = "inactive_" .. tostring(unit:base():get_type())
						--unit_type = enemy_turret_ids[unit:base()._tweak_table_id] and "inactive_swat_turret" or "inactive_sentry_gun"
					end
					
					add_unit(unit_type, unit, body, data)
					data.vision_blocked = true
					if unit:in_slot(self._weapon_slotmask) then
						data.shot_blocked = true
					end
				elseif unit:in_slot(self._slotmasks.bag) then --Bag/deployable
					is_solid = false
					
					if unit:carry_data() then
						add_unit("bag", unit, body, data)
					end
				elseif unit:in_slot(self._slotmasks.car) then --Drivable car
					data.vision_blocked = true
					if unit:in_slot(self._weapon_slotmask) then
						data.shot_blocked = data.shot_blocked
					end
				end
			end
			
			table.insert(data.ignore_units, unit)
		end
		
		--data.ray_from_unit = unit
		if data.shot_blocked and data.has_hit_wall and not data.slotmask then
			data.slotmask = slotmask - self._slotmasks.environment
		end
		
		if is_solid then
			data.direct_vision_blocked = true
			self._ray_distance = self._ray_distance or data.total_distance
			self._ray_position = self._ray_position or ray.position
		end
		
		if is_wall then
			local offset = 40
			mvector3.set(from, direction)
			mvector3.multiply(from, offset)
			mvector3.add(from, ray.position)
			data.total_distance = data.total_distance + offset
		else
			mvector3.set(from, ray.position)
		end
		
		self:_update_ray(from, to, direction, data)
	end	
end
