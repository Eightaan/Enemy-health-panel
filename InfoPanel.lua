if string.lower(RequiredScript) == "lib/managers/hudmanagerpd2" then

	local function tostring_trimmed(number, max_decimals)
		return string.format("%." .. (max_decimals or 10) .. "f", number):gsub("%.?0+$", "")
	end


	local _setup_player_info_hud_pd2_original = HUDManager._setup_player_info_hud_pd2
	
	function HUDManager:_setup_player_info_hud_pd2(...)
		_setup_player_info_hud_pd2_original(self, ...)
		self:_setup_ray_info_panel()
	end
	
	function HUDManager:_setup_ray_info_panel()
		local hud = managers.hud:script(PlayerBase.PLAYER_INFO_HUD_PD2)
		local panel = hud.panel
		
		self._hud_info_panel = HUDInfoPanel:new(panel)
	end
	
	function HUDManager:update_info_panel(fwd_ray)
		self._hud_info_panel:update(fwd_ray)
	end
	
	
	HUDColoredBar = HUDColorBar or class()

	function HUDColoredBar:init(parent, args)
		self._reverse_growth = args.reverse_growth
		self._rotate = args.w > args.h
		self._max_value = args.max_value or 100

		self._panel = parent:panel({
			name = args.name,
			w = args.w,
			h = args.h,
			x = args.x,
			y = args.y,
			alpha = args.alpha or 1,
			visible = args.visible,
			layer = args.layer or 0,
		})
		
		local bar_outline = self._panel:bitmap({
			name = "bar_outline",
			texture = "guis/textures/hud_icons",
			texture_rect = { 252, 240, 12, 48 },
			color = Color.white,
			w = self._rotate and self._panel:h() or self._panel:w(),
			h = self._rotate and self._panel:w() or self._panel:h(),
			rotation = self._rotate and 90 or 0,
			layer = args.layer or 0,
			y = self._rotate and ((self._panel:h() - self._panel:w()) / 2) or 0,
			x = self._rotate and ((self._panel:w() - self._panel:h()) / 2) or 0,
		})
		
		local bar = self._panel:rect({
			name = "bar",
			blend_mode = "normal",
			color = args.color or Color.white,
			alpha = 0.75,
			w = self._panel:w() * (self._rotate and 0.98 or 0.95),
			h = self._panel:h() * (self._rotate and 0.95 or 0.98),
			layer = (args.layer or 0) - 5,
		})
		bar:set_center(self._panel:w() / 2, self._panel:h() / 2)
		self._bar_max_w = bar:w()
		self._bar_max_h = bar:h()
		
		if args.bg then
			self._panel:rect({
				name = "bar_bg",
				blend_mode = "normal",
				color = args.bg.color or Color.black,
				alpha = args.bg.alpha or 0.5,
				w = self._panel:w(),
				h = self._panel:h(),
				layer = (args.layer or 0) - 10,
			})
		end
		
		if args.text then
			local text = self._panel:text({
				name = "text",
				text = args.text.text or "",
				color = args.text.color or Color.black,
				blend_mode = "normal",
				layer = (args.layer or 0) + 5,
				alpha = args.text.alpha or 1,
				w = self._panel:w(),
				h = self._panel:h(),
				vertical = "center",
				align = "center",
				font_size = (self._rotate and self._panel:h() or self._panel:w()) * 0.65,
				font = "fonts/font_small_noshadow_mf",
				rotation = self._rotate and 0 or 90,
			})
			self._text_format = args.text.format or "%.0f"
		end
	end

	function HUDColoredBar:panel()
		return self._panel
	end

	function HUDColoredBar:size()
		return self._panel:w(), self._panel:h()
	end
	
	function HUDColoredBar:visible()
		return self._panel:visible()
	end
	
	function HUDColoredBar:set_bar_color(color)
		self._panel:child("bar"):set_color(color)
	end

	function HUDColoredBar:set_text_color(color)
		if self._panel:child("text") then
			self._panel:child("text"):set_color(color)
		end
	end

	function HUDColoredBar:set_visible(visible)
		self._panel:set_visible(visible)
	end

	function HUDColoredBar:set_ratio(ratio, text_override)
		local bar = self._panel:child("bar")
		local text = self._panel:child("text")
		local ratio = math.clamp(ratio, 0, 1)
		
		if self._rotate then
			bar:set_w(self._bar_max_w * ratio)
		else
			bar:set_h(self._bar_max_h * ratio)
		end
		
		if self._reverse_growth then
			if self._rotate then
				bar:set_right(self._panel:w() + (self._bar_max_w - self._panel:w()) / 2)
			else
				bar:set_bottom(self._panel:h() + (self._bar_max_h - self._panel:h()) / 2)
			end
		else
			if self._rotate then
				bar:set_left((self._panel:w() - self._bar_max_w) / 2)
			else
				bar:set_top((self._panel:h() - self._bar_max_h) / 2)
			end
		end
		
		if text then
			if text_override then
				text:set_text(text_override)
			else
				text:set_text(string.format(self._text_format, self._max_value * ratio))
			end
		end
	end

	function HUDColoredBar:set_max_value(value)
		self._max_value = value
	end

	function HUDColoredBar:set_y(y)
		self._panel:set_y(y)
	end
	
	HUDInfoPanel = HUDInfoPanel or class()
	
	HUDInfoPanel.TANK_IDS = {
		tank = true,
		tank_medic = true,
		tank_mini = true,
	}
	
	function HUDInfoPanel:init(parent)
		self._parent = parent
		
		self._person_panel = HUDInfoPanelPerson:new(self._parent)
		self._tank_panel = HUDInfoPanelTank:new(self._parent)
		self._turret_panel = HUDInfoPanelTurret:new(self._parent)
		self._loot_panel = HUDInfoPanelLoot:new(self._parent)
	end
	
	function HUDInfoPanel:update(fwd_ray)
		local targets = fwd_ray:get_targets_by_type({ "person", "swat_turret", "bag" })
		
		for _, data in ipairs(targets) do
			if data.in_view or data.type == "bag" then
				local target_panel
				
				if data.type == "enemy" --[[or data.type == "joker"]] then
					if HUDInfoPanel.TANK_IDS[data.unit:base()._tweak_table] then
						target_panel = self._tank_panel
					else
						target_panel = self._person_panel
					end
			--	elseif data.type == "criminal" and data.unit:in_slot(World:make_slot_mask(16, 24)) then
			--		target_panel = self._person_panel
				elseif data.type == "civilian" or data.type == "hostage" then
					target_panel = self._person_panel
				elseif data.type == "swat_turret" then
					target_panel = self._turret_panel
				elseif data.type == "bag" then
					target_panel = self._loot_panel
				end
				
				if target_panel then
					if target_panel ~= self._current_panel then
						if self._current_panel then
							self._current_panel:set_visible(false)
						end
						target_panel:set_visible(true)
						self._current_panel = target_panel
					end
					if data.unit ~= self._current_panel:unit() or data.unit:slot() ~= self._current_panel:unit_slot() then
						self._current_panel:set_unit(data.unit)
					end
					self._current_panel:refresh()
				end
				
				break
			end
		end
	end
	
	
	HUDInfoPanelBase = HUDInfoPanelBase or class()	--Abstract base class, do not instantiate
	
	HUDInfoPanelBase.FADE_TIME = 2
	HUDInfoPanelBase.DEAD_UNIT_FADE_FACTOR = 4
	
	function HUDInfoPanelBase:init(parent)
		self._components = {}
	
		self._panel = parent:panel({ 
			alpha = 0,
			visible = false,
			w = parent:panel():w(),
		})
		self._panel:set_top(50)
		
		self._bg = self._panel:rect({
			name = "bg",
			color = Color.black,
			alpha = 0,
			valign = "grow",
			layer = -1,
		})
		
		self._title_text = self._panel:text({
			name = "title",
			color = Color.white,
			layer = self._bg:layer() + 1,
			vertical = "center",
			align = "center",
			h = tweak_data.menu.pd2_small_font_size,
			w = self._panel:w(),
			font_size = tweak_data.menu.pd2_small_font_size,
			font = tweak_data.hud.small_font,
		})
		
		self._components = {
			self._title_text,
		}
	end
	
	function HUDInfoPanelBase:unit()
		return self._unit
	end
	
	function HUDInfoPanelBase:unit_slot()
		return self._unit_slot
	end
	
	function HUDInfoPanelBase:set_unit(unit)
		self._unit = unit
		self._unit_slot = unit:slot()
	end
	
	function HUDInfoPanelBase:set_visible(status)
		self._panel:stop()
		self._panel:set_visible(status)
	end
	
	function HUDInfoPanelBase:refresh()
		self._panel:stop()
		self._panel:animate(callback(self, self, "_animate_fade"))
	end
	
	function HUDInfoPanelBase:_update()
		return true
	end
	
	function HUDInfoPanelBase:_update_layout()
		local th = 0
		local mw = 0
		
		for i, component in ipairs(self._components) do
			if component:visible() then
				local w, h
				
				if component.text_rect then
					_, _, w, h = component:text_rect()
				else
					w, h = component:size()
				end
				
				component:set_y(th)
				th = th + h
				mw = math.max(mw, w)
			end
		end
		
		self._panel:set_h(th)
		self._bg:set_w(mw * 1.25)
		self._bg:set_center_x(self._panel:w()/2)
	end
	
	function HUDInfoPanelBase:_animate_fade(panel)
		local T_MAX = self.FADE_TIME
		local t = 0
		local living = true
		
		while t < T_MAX and alive(self._unit) do
			local alpha = 1 - (t/T_MAX)^4
			panel:set_alpha(alpha)
			
			if living then
				if not self:_update() then
					living = false
				end
			end

			t = t + coroutine.yield() * (living and 1 or self.DEAD_UNIT_FADE_FACTOR)
		end
		
		panel:set_alpha(0)
	end
	
	
	HUDInfoPanelUnit = HUDInfoPanelUnit or class(HUDInfoPanelBase)
	
	HUDInfoPanelUnit._UNIT_ID_TO_NAME = {
		bolivian = "susa thug",
		bolivian_indoors = "susa security",
		security = "security guard",
		security_undominatable = "security guard",
		gensec = "gensec guard",
		cop = "cop",
		cop_scared = "cop",
		cop_female = "cop",
		fbi = "fbi",
		swat = {
			default = "swat",
			["9909f112cf60d6ca"] = "zeal swat",
		},
		heavy_swat = {
			default = "heavy swat",
			["c59df88e5d1b14ee"] = "zeal heavy swat",
		},
		fbi_swat = "fbi swat",
		fbi_heavy_swat = "fbi heavy swat",
		city_swat = {
			default = "gensec elite",
			["dce5cb64c6544d4f"] = "murkywater",
			["7c2d921fc071a265"] = "murkywater",
			["ce7380909a88d432"] = "murkywater",
		},
		sniper = "sniper",
		gangster = "ganster",
		biker = "biker",
		biker_escape = "biker",
		mobster = "mobster",
		mobster_boss = "commisar",
		hector_boss = "hector",
		hector_boss_no_armor = "hector",
		biker_boss = "biker boss",
		tank = "bulldozer",
		tank_hw = "headless bulldozer",
		spooc = "cloaker",
		shield = "shield",
		taser = "taser",
		civilian = "civilian",
		civilian_female = "civilian",
		bank_manager = "bank manager",
		drunk_pilot = "pilot",
		escort = "escort",
		old_hoxton_mission = "hoxton",
		inside_man = "inside man",
		boris = "boris",
		escort_undercover = "taxman",
		phalanx_vip = "cpt. winters",
		phalanx_minion = "phalanx",
		
		old_hoxton = "hoxton",
		dragan = "dragan",
		female_1 = "clover",
		bonnie = "bonnie",
		jacket = "jacket",
		american = "houston",
		german = "wolf",
		spanish = "chains",
		russian = "dallas",
		jowi = "wick",
	}
	
	function HUDInfoPanelUnit:init(parent)
		HUDInfoPanelUnit.super.init(self, parent)
		
		self._health_bar = HUDColoredBar:new(self._panel, {
			name = "health_bar",
			h = tweak_data.menu.pd2_small_font_size,
			w = 150,
			color = Color.red,
			bg = {},
			text = { color = Color.white },
		})
		self._health_bar:panel():set_center_x(self._panel:w() / 2)
	end
	
	function HUDInfoPanelUnit:_update()
		local dmg = alive(self._unit) and self._unit:character_damage()
		if dmg then
			self._health_bar:set_ratio(dmg._health / dmg._HEALTH_INIT, string.format("%.0f / %.0f", dmg._health * 10, dmg._HEALTH_INIT * 10))
			return not dmg:dead()
		end
	end
	
	
	HUDInfoPanelPerson = HUDInfoPanelPerson or class(HUDInfoPanelUnit)
	
	function HUDInfoPanelPerson:init(parent)
		HUDInfoPanelPerson.super.init(self, parent)
		
		
		self._components = {
			self._title_text,
			self._health_bar,
		}
	end
	
	function HUDInfoPanelPerson:set_unit(...)
		HUDInfoPanelPerson.super.set_unit(self, ...)
		
		self._health_bar:set_max_value(self._unit:character_damage()._HEALTH_INIT * 10)
		self:_update()
		
		self:_update_title()
		self:_update_layout()
	end
	
	function HUDInfoPanelPerson:_update_title()
		local unit_id = self._unit:base()._tweak_table
		
		if unit_id then
			title = self._UNIT_ID_TO_NAME[unit_id] or unit_id
			
			if type(title) == "table" then
				local unkey = tostring(self._unit:name():key())
				
				--if not title[unkey] then
				--	printf("Missing info panel unit key: %s %s", unit_id, unkey)
				--end
				
				title = title[unkey] or title.default
			end
			
			self._title_text:set_text(utf8.to_upper(title))
			self._title_text:set_visible(true)
			self._title_text:set_color(self._unit:in_slot(16) and Color.green or Color.white)
		else
			self._title_text:set_visible(false)
		end
	end
	
	
	HUDInfoPanelTank = HUDInfoPanelTank or class(HUDInfoPanelPerson)
	
	HUDInfoPanelTank._ARMOR = {
		visor = {
			[4] = 15,	--PLATE VISOR (15)
			[5] = 16,	--GLASS VISOR (16)
		},
		armor = {
			[6] = 8,		--PLATE CHEST (8)
			[7] = 8,		--PLATE STOMACH (8)
			[8] = 8,		--PLATE BACK (8)
			[9] = 8,		--NECK FRONT (8)
			[10] = 8,	--NECK BACK (8)
		}
		
		--[[
		[4] = { "visor", 15 },	--PLATE VISOR (15)
		[5] = { "visor", 16 },	--GLASS VISOR (16)
		[6] = { "armor", 8 },	--PLATE CHEST (8)
		[7] = { "armor", 8 },	--PLATE STOMACH (8)
		[8] = { "armor", 8 },	--PLATE BACK (8)
		[9] = { "armor", 8 },	--NECK FRONT (8)
		[10] = { "armor", 8 },	--NECK BACK (8)
		]]
	}
	
	function HUDInfoPanelTank:init(parent)
		HUDInfoPanelTank.super.init(self, parent)
		
		self._visor_bar = HUDColoredBar:new(self._panel, {
			name = "visor_bar",
			h = tweak_data.menu.pd2_small_font_size,
			w = 150,
			color = Color(0.6, 0.6, 0.6),
			bg = {},
			text = { color = Color.white },
		})
		self._visor_bar:panel():set_center_x(self._panel:w() / 2)	
		
		self._armor_bar = HUDColoredBar:new(self._panel, {
			name = "armor_bar",
			h = tweak_data.menu.pd2_small_font_size,
			w = 150,
			color = Color(0.6, 0.6, 0.6),
			bg = {},
			text = { color = Color.white },
		})
		self._armor_bar:panel():set_center_x(self._panel:w() / 2)
		
		self._visor_destroyed = false
		self._armor_destroyed = false
		self._armor_max = 0
		self._visor_max = 0
		
		for i, value in pairs(HUDInfoPanelTank._ARMOR.visor) do
			self._visor_max = self._visor_max + value
		end
		for i, value in pairs(HUDInfoPanelTank._ARMOR.armor) do
			self._armor_max = self._armor_max + value
		end
		self._visor_bar:set_max_value(self._visor_max * 10)
		self._armor_bar:set_max_value(self._armor_max * 10)
		
		self._components = {
			self._title_text,
			self._health_bar,
			self._visor_bar,
			self._armor_bar,
		}
	end
	
	function HUDInfoPanelTank:_update()
		local function sum_parts(part_table)
			local count = 0
			local health = 0
			
			for i, value in pairs(part_table) do
				local damage = self._unit:body(i) and self._unit:body(i):extension() and self._unit:body(i):extension().damage and self._unit:body(i):extension().damage._damage and self._unit:body(i):extension().damage._damage.damage
				
				if damage and damage < value then
					count = count + 1
					health = health + value - damage
				end
			end
			
			return count, health
		end
		
		
		if HUDInfoPanelTank.super._update(self) then
			local rearrange_needed = false
			
			if not self._visor_destroyed then
				local count, health = sum_parts(HUDInfoPanelTank._ARMOR.visor)
				
				if count > 0 then
					self._visor_bar:set_ratio(health / self._visor_max, string.format("Visor: %.0f (x%d)", health * 10, count))
				else
					rearrange_needed = true
					self._visor_destroyed = true
					self._visor_bar:set_visible(false)
				end
			end
			
			if not self._armor_destroyed then
				local count, health = sum_parts(HUDInfoPanelTank._ARMOR.armor)
				
				if count > 0 then
					self._armor_bar:set_ratio(health / self._visor_max, string.format("Armor: %.0f (x%d)", health * 10, count))
				else
					rearrange_needed = true
					self._armor_destroyed = true
					self._armor_bar:set_visible(false)
				end
			end
			
			if rearrange_needed then
				self:_update_layout()
			end
			
			return true
		end
	end

	function HUDInfoPanelTank:set_unit(...)
		self._visor_destroyed = false
		self._armor_destroyed = false
		self._visor_bar:set_visible(true)
		self._armor_bar:set_visible(true)
		
		HUDInfoPanelTank.super.set_unit(self, ...)
	end
	

	HUDInfoPanelTurret = HUDInfoPanelTurret or class(HUDInfoPanelUnit)
	
	function HUDInfoPanelTurret:init(parent)
		HUDInfoPanelTurret.super.init(self, parent)
		
		self._shield_bar = HUDColoredBar:new(self._panel, {
			name = "shield_bar",
			h = tweak_data.menu.pd2_small_font_size,
			w = 150,
			color = Color(0.6, 0.6, 0.6),
			bg = {},
			text = { color = Color.white },
		})
		self._shield_bar:panel():set_center_x(self._panel:w() / 2)

		self._shield_destroyed = false
		self._title_text:set_text(utf8.to_upper("swat turret"))
		
		self._components = {
			self._title_text,
			self._health_bar,
			self._shield_bar,
		}
	end
	
	function HUDInfoPanelTurret:_update()
		if HUDInfoPanelTurret.super._update(self) then
			local dmg = self._unit:character_damage()
			local rearrange_needed = false
		
			if self._shield_destroyed then
				if dmg._shield_health > 0 then
					rearrange_needed = true
					self._shield_destroyed = false
					self._shield_bar:set_visible(true)
				end
			end
		
			if not self._shield_destroyed then
				local dmg = self._unit:character_damage()
				if dmg._shield_health > 0 then
					self._shield_bar:set_ratio(dmg._shield_health / dmg._SHIELD_HEALTH_INIT, string.format("Shield: %.0f / %.0f", dmg._shield_health * 10, dmg._SHIELD_HEALTH_INIT * 10))
				else
					rearrange_needed = true
					self._shield_destroyed = true
					self._shield_bar:set_visible(false)
				end
			
				if rearrange_needed then
					self:_update_layout()
				end
			end
			
			return true
		end
	end
	
	function HUDInfoPanelTurret:set_unit(...)
		self._shield_destroyed = false
		self._shield_bar:set_visible(true)
		
		HUDInfoPanelTurret.super.set_unit(self, ...)
		
		self._shield_bar:set_max_value(self._unit:character_damage()._SHIELD_HEALTH_INIT * 10)
		self:_update()
		self:_update_layout()
	end
	
	
	HUDInfoPanelLoot = HUDInfoPanelLoot or class(HUDInfoPanelBase)
	
	function HUDInfoPanelLoot:set_unit(...)
		HUDInfoPanelLoot.super.set_unit(self, ...)
		
		local carry_id = self._unit:carry_data() and self._unit:carry_data():carry_id()
		if carry_id then
			local tweak = carry_id and tweak_data.carry[carry_id]
			local text = tweak and tweak.name_id and managers.localization:text(tweak.name_id) or "unknown loot"
			
			self._title_text:set_text(utf8.to_upper(text))
			self._title_text:set_visible(true)
		else
			self._title_text:set_visible(false)
		end
		
		self:_update_layout()
	end
	
	
elseif string.lower(RequiredScript) == "lib/units/beings/player/states/playerstandard" then

	local update_original = PlayerStandard.update
	
	function PlayerStandard:update(...)
		update_original(self, ...)
		
		if self._fwd_ray_new then
			managers.hud:update_info_panel(self._fwd_ray_new)
		end
	end
	
end