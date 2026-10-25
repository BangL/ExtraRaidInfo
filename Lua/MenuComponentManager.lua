-- options menu

ExtraRaidInfoMenu = ExtraRaidInfoMenu or class(BLTMenu)

function ExtraRaidInfoMenu:Init(root)
	self._something_changed = false

	self:Title({
		text = "extraraidinfo_title",
	})
	self:Label({
		text = nil,
		localize = false,
		h = 8,
	})

	self:EnableScrolling() -- header stays fixed, everything below scrolls

	self:AutoBindNamedControlsBegin()

	self:SubTitle({ text = "extraraidinfo_cat_general", localize = true, y_offset = 16 })
	self:_Toggle("enabled")
	self:_Toggle("show_delays")
	self:_Slider("min_delay", 5, 120, 0)
	self:_Toggle("show_timers")
	self:_Toggle("show_hud_timers")
	self:_Toggle("show_counters")
	self:_Toggle("show_loot")
	self:_Toggle("show_waypoints")

	self:SubTitle({ text = "extraraidinfo_cat_layout", localize = true, y_offset = 16 })
	self:MultiChoice({
		name = "extraraidinfo_align",
		text = "extraraidinfo_align",
		desc = "extraraidinfo_align_desc",
		value = ExtraRaidInfo:GetOption("align"),
		callback = callback(self, self, "OnOptionChanged", "align"),
		items = {
			{ text_id = "extraraidinfo_align_left", value = 1 },
			{ text_id = "extraraidinfo_align_center", value = 2 },
			{ text_id = "extraraidinfo_align_right", value = 3 },
		},
		auto_select_on_hover = true,
	})
	self:_Slider("y_pos", 0, 1, 2)
	self:_Slider("scale", 0.5, 2, 2)
	self:_Slider("background_alpha", 0, 1, 2)

	self._reset_btn = self:LongRoundedButton2({
		name = "extraraidinfo_reset",
		text = "extraraidinfo_reset",
		localize = true,
		callback = callback(self, self, "Reset"),
		ignore_align = true,
		y = 832,
		x = 1472,
		auto_select_on_hover = true,
	})
	self:AutoBindNamedControlsEnd()
end

function ExtraRaidInfoMenu:_additional_active_controls()
	return {
		self._reset_btn,
	}
end

function ExtraRaidInfoMenu:_Toggle(option)
	local id = "extraraidinfo_" .. option

	self:Toggle({
		name = id,
		text = managers.localization:text(id),
		localize = false,
		localized = false,
		desc = managers.localization:text(id .. "_desc"),
		localize_desc = false,
		localized_desc = false,
		value = ExtraRaidInfo:GetOption(option),
		callback = callback(self, self, "OnOptionChanged", option),
		auto_select_on_hover = true,
	})
end

function ExtraRaidInfoMenu:_Slider(option, min, max, decimals)
	local id = "extraraidinfo_" .. option

	self:Slider({
		name = id,
		text = id,
		desc = id .. "_desc",
		value = ExtraRaidInfo:GetOption(option),
		callback = callback(self, self, "OnOptionChanged", option),
		min = min,
		max = max,
		value_format = "%." .. (decimals or 0) .. "f",
		auto_select_on_hover = true,
	})
end

function ExtraRaidInfoMenu:OnOptionChanged(option, value)
	if ExtraRaidInfo:SetOption(option, (type(value) == "table") and value.value or value) then
		self._something_changed = true
	end
end

function ExtraRaidInfoMenu:Reset()
	QuickMenu:new(
		managers.localization:text("extraraidinfo_reset"),
		managers.localization:text("extraraidinfo_reset_confirm"),
		{
			{
				text = managers.localization:text("dialog_yes"),
				callback = function()
					ExtraRaidInfo._config = clone(ExtraRaidInfo._defaults)
					ExtraRaidInfo:SaveConfig()
					ExtraRaidInfo.Trackers:Recreate()
					self._something_changed = false
					self:ReloadMenu()
				end,
			},
			{
				text = managers.localization:text("dialog_no"),
				is_cancel_button = true,
			},
		},
		true
	)
end

function ExtraRaidInfoMenu:Close()
	if self._something_changed then
		ExtraRaidInfo:SaveConfig()
	end
end

Hooks:Add("MenuComponentManagerInitialize", "ExtraRaidInfo_MenuComponentManagerInitialize", function(self)
	RaidMenuHelper:CreateMenu({
		name = "extraraidinfo_options",
		name_id = "extraraidinfo_title",
		inject_list = "blt_options",
		icon = "waypoint_special_loot",
		class = ExtraRaidInfoMenu,
	})
end)
