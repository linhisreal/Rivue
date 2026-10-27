--!nonstrict
-- Loading data from the server with useAsync (loading, error, retry), and buying with a pending state.
-- The server side is two RivueRemote handlers:
--
--   Remote.setupServer()
--   Remote.handle("shop:list", function(player) return ShopService.list(player) end)
--   Remote.handle("shop:buy", function(player, payload) return ShopService.buy(player, payload.id) end)
--
-- `api` can be swapped (tests pass a fake); by default it calls the server through Remote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rivue = require(ReplicatedStorage:WaitForChild("RivueUI"))
local Remote = require(ReplicatedStorage:WaitForChild("RivueRemote"))
local h = Rivue.h

export type Product = { id: string, name: string, price: number }

export type ShopApi = {
	list: () -> ({ Product }?, string?),
	buy: (id: string) -> (boolean, string?),
}

local remoteApi: ShopApi = {
	list = function()
		local data, err = Remote.request("shop:list", nil)
		return data :: { Product }?, err
	end,
	buy = function(id)
		local data, err = Remote.request("shop:buy", { id = id })
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
		-- useAsync turns a thrown error into `error`, so a nil list with a reason becomes one
		local listing = Rivue.useAsync(function()
			local list, err = api.list()
			if not list then
				error(err or "no response", 0)
			end
			return list
		end)
		local buying = Rivue.ref(nil :: string?)
		local buyError = Rivue.ref(nil :: string?)

		local function buy(product: Product)
			if buying.value then
				return
			end
			buying.value = product.id
			buyError.value = nil
			task.spawn(function()
				local ok, err = api.buy(product.id)
				buying.value = nil
				if not ok then
					buyError.value = `Purchase failed ({err})`
				end
			end)
		end

		return {
			products = listing.data,
			loading = listing.loading,
			errorText = Rivue.computed(function()
				if listing.error.value then
					return `Couldn't load the shop ({listing.error.value})`
				end
				return buyError.value
			end),
			retry = listing.refresh,
			buying = buying,
			buy = buy,
		}
	end,

	render = function(ctx)
		return h("Frame", { class = "panel", layout = { gap = 6 } }, {
			Rivue.hIf(
				ctx.errorText ~= nil,
				h("TextButton", { Name = "Error", Text = `{ctx.errorText} - tap to retry`, onClick = ctx.retry })
			),
			Rivue.hIf(ctx.loading, h("TextLabel", { Name = "Loading", Text = "Loading..." })),
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
