--!nonstrict
-- A menu built on RivueRouter: a back button, shop tabs as child routes, and a settings screen
-- that asks before the player leaves with unsaved changes.
--
--   local GameMenu = require(path.to.GameMenu)
--   local app = Rivue.createApp(GameMenu.App)
--   app:styles(GameMenu.styles)
--   app:use(GameMenu.createRouter())
--   app:mountToPlayerGui(Players.LocalPlayer)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("RivueUI"))
local Router = require(ReplicatedStorage:WaitForChild("RivueRouter"))
local h = Rivue.h

-- App styles rather than a component's `styles`: the link buttons are rendered by RouterLink, so
-- a class is looked up in RouterLink's styles and then the app's
local styles = {
	screen = { Size = UDim2.fromOffset(360, 300), BackgroundTransparency = 1 },
	button = { Size = UDim2.fromOffset(160, 36), BackgroundColor3 = Color3.fromRGB(45, 45, 52) },
	tab = { Size = UDim2.fromOffset(100, 32), TextColor3 = Color3.fromRGB(150, 150, 160) },
	["router-link-active"] = { TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Color3.fromRGB(60, 120, 220) },
}

local function list(name: string, items: { string })
	return Rivue.defineComponent({
		name = name,
		render = function()
			return h(Rivue.Column, { gap = 4 }, {
				Rivue.hFor(items, function(item)
					return h("TextLabel", { key = item, Name = item, Text = item, Size = UDim2.fromOffset(200, 24) })
				end),
			})
		end,
	})
end

local Weapons = list("Weapons", { "Sword", "Bow", "Staff" })
local Pets = list("Pets", { "Cat", "Owl" })

local Lobby = Rivue.defineComponent({
	name = "Lobby",
	render = function()
		return h(Rivue.Column, { gap = 8 }, {
			h(Router.RouterLink, { Name = "OpenShop", to = "shop", class = "button", Text = "Shop" }),
			h(Router.RouterLink, { Name = "OpenSettings", to = "settings", class = "button", Text = "Settings" }),
		})
	end,
})

local Shop = Rivue.defineComponent({
	name = "Shop",
	render = function()
		return h(Rivue.Column, { gap = 8 }, {
			h(Rivue.Row, { gap = 8 }, {
				h(Router.RouterLink, { Name = "WeaponsTab", to = "weapons", class = "tab", Text = "Weapons" }),
				h(Router.RouterLink, { Name = "PetsTab", to = "pets", class = "tab", Text = "Pets" }),
			}),
			h(Router.RouterView),
		})
	end,
})

-- The saved setting. A real game would keep it in a store and send it to the server
local musicOn = Rivue.ref(true)

local function dialogButton(text: string, onActivated: () -> ())
	return h("TextButton", { Name = text, Text = text, Size = UDim2.fromOffset(100, 36), onActivated = onActivated })
end

local Settings = Rivue.defineComponent({
	name = "Settings",
	setup = function()
		local draft = Rivue.ref(musicOn.value)
		local asking = Rivue.ref(false)
		local answer = Instance.new("BindableEvent")
		Rivue.onUnmounted(function()
			answer:Destroy()
		end)

		-- However the player tries to leave (Back, B, a link), this waits for their answer
		Router.onBeforeRouteLeave(function()
			if draft.value == musicOn.value then
				return true
			end
			asking.value = true
			local leave = answer.Event:Wait()
			asking.value = false
			if leave then
				draft.value = musicOn.value
			end
			return leave
		end)

		return {
			draft = draft,
			asking = asking,
			toggle = function()
				draft.value = not draft.value
			end,
			save = function()
				musicOn.value = draft.value
			end,
			stay = function()
				answer:Fire(false)
			end,
			leave = function()
				answer:Fire(true)
			end,
		}
	end,
	render = function(ctx)
		return h(Rivue.Column, { gap = 8 }, {
			h("TextButton", {
				Name = "Music",
				class = "button",
				Text = if ctx.draft then "Music: on" else "Music: off",
				onActivated = ctx.toggle,
			}),
			h("TextButton", { Name = "Save", class = "button", Text = "Save", onActivated = ctx.save }),
			h(Rivue.Dialog, { open = ctx.asking, onClose = ctx.stay, transition = Rivue.transitions.pop() }, {
				h(Rivue.Column, { gap = 12 }, {
					h(
						"TextLabel",
						{ Name = "Question", Text = "Leave without saving?", Size = UDim2.fromOffset(240, 30) }
					),
					h(Rivue.Row, { gap = 8 }, {
						dialogButton("Stay", ctx.stay),
						dialogButton("Leave", ctx.leave),
					}),
				}),
			}),
		})
	end,
})

local Header = Rivue.defineComponent({
	name = "Header",
	setup = function()
		local router = Router.useRouter()
		local route = Router.useRoute()
		Rivue.useKeybind({ Enum.KeyCode.Escape, Enum.KeyCode.ButtonB }, function()
			-- The settings guard may wait for the player, so don't hold up the input callback
			task.spawn(router.back)
		end, { enabled = router.canGoBack })
		return {
			canGoBack = router.canGoBack,
			title = Rivue.computed(function()
				return route.meta.title or ""
			end),
			back = function()
				router.back()
			end,
		}
	end,
	render = function(ctx)
		return h(Rivue.Row, { gap = 8 }, {
			h(
				"TextButton",
				{ Name = "Back", class = "button", Text = "Back", Visible = ctx.canGoBack, onActivated = ctx.back }
			),
			h("TextLabel", { Name = "Title", Text = ctx.title, Size = UDim2.fromOffset(160, 36) }),
		})
	end,
})

local App = Rivue.defineComponent({
	name = "GameMenu",
	render = function()
		return h(Rivue.Column, { gap = 12, padding = 16 }, {
			h(Header),
			h(Router.RouterView, nil, {
				default = function(view)
					return h(Rivue.Transition, Rivue.transitions.fade({ duration = 0.15, mode = "out-in" }), {
						view.Component,
					})
				end,
			}),
		})
	end,
})

local function createRouter()
	return Router.createRouter({
		routes = {
			lobby = { component = Lobby, meta = { title = "Menu" } },
			shop = {
				component = Shop,
				redirect = "weapons",
				meta = { title = "Shop" },
				children = { weapons = Weapons, pets = Pets },
			},
			settings = { component = Settings, meta = { title = "Settings" } },
		},
		initial = "lobby",
	})
end

return {
	App = App,
	createRouter = createRouter,
	styles = styles,
	musicOn = musicOn,
}
