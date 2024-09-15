--!nonstrict
-- Loading data from the server with loading/error states, and buying with a pending state.
-- The server side is two Remote handlers:
--
--   Rivue.Remote.setupServer()
--   Rivue.Remote.handle("shop:list", function(player) return ShopService.list(player) end)
--   Rivue.Remote.handle("shop:buy", function(player, payload) return ShopService.buy(player, payload.id) end)
--
-- `api` can be swapped (tests pass a fake); by default it calls the server through Remote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("Rivue"))
local h = Rivue.h

export type Product = { id: string, name: string, price: number }

export type ShopApi = {
	list: () -> ({ Product }?, string?),
	buy: (id: string) -> (boolean, string?),
}

local remoteApi: ShopApi = {
	list = function()
		local data, err = Rivue.Remote.request("shop:list", nil)
		return data :: { Product }?, err
	end,
	buy = function(id)
		local data, err = Rivue.Remote.request("shop:buy", { id = id })
		return data == true, err
	end,
}

return Rivue.defineComponent({
	name = "Shop",
	props = {
		api = { type = "table" },
	},
	styles = {
		panel = { Size = UDim2.fromOffset(320, 400), padding = 8 },
		product = { Size = UDim2.new(1, 0, 0, 40) },
	},

	setup = function(props)
		local api = (props.api or remoteApi) :: ShopApi
		local products = Rivue.shallowRef(nil :: { Product }?)
		local errorText = Rivue.ref(nil :: string?)
		local buying = Rivue.ref(nil :: string?)

		local function load()
			errorText.value = nil
			-- Remote.request yields, so run it off the render path
			task.spawn(function()
				local list, err = api.list()
				if list then
					products.value = list
				else
					errorText.value = `Couldn't load the shop ({err})`
				end
			end)
		end

		local function buy(product: Product)
			if buying.value then
				return
			end
			buying.value = product.id
			task.spawn(function()
				local ok, err = api.buy(product.id)
				buying.value = nil
				if not ok then
					errorText.value = `Purchase failed ({err})`
				end
			end)
		end

		Rivue.onMounted(load)

		return { products = products, errorText = errorText, buying = buying, load = load, buy = buy }
	end,

	render = function(ctx)
		local loading = ctx.products == nil and ctx.errorText == nil
		return h("Frame", { class = "panel", layout = { gap = 6 } }, {
			Rivue.hIf(
				ctx.errorText ~= nil,
				h("TextButton", { Name = "Error", Text = `{ctx.errorText} - tap to retry`, onClick = ctx.load })
			),
			Rivue.hIf(loading, h("TextLabel", { Name = "Loading", Text = "Loading..." })),
			Rivue.hFor(ctx.products or {}, function(product)
				local pending = ctx.buying == product.id
				return h("TextButton", {
					key = product.id,
					Name = product.id,
					class = "product",
					Text = if pending then "Buying..." else `{product.name} - {product.price}`,
					AutoButtonColor = not pending,
					onClick = function()
						ctx.buy(product)
					end,
				})
			end),
		})
	end,
})
