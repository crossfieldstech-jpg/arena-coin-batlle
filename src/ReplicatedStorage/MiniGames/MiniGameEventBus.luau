--[[
	MiniGameEventBus.luau
	Typed, allocation-efficient In-Process Event Bus for Mini-Game packages.
	Provides isolated or shared lifecycle signals:
	- SessionStarted
	- SessionProgress
	- SessionEnded
	- ClientMounted
	- ClientUnmounted
	Zero external dependencies, cross-context safe.
]]

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Destroy: (self: Signal<T...>) -> (),
	Wait: (self: Signal<T...>) -> T...,
}

local SignalClass = {}
SignalClass.__index = SignalClass

function SignalClass.new<T...>(): Signal<T...>
	local self = setmetatable({}, SignalClass)
	self._listeners = {}
	self._isDestroyed = false
	return (self :: any) :: Signal<T...>
end

function SignalClass:Connect(callback: (...any) -> ()): Connection
	assert(typeof(callback) == "function", "Signal:Connect expects a callback function")
	if self._isDestroyed then
		return {
			Connected = false,
			Disconnect = function() end,
		}
	end

	local connection = {
		Connected = true,
		_signal = self,
		_callback = callback,
	}

	function connection:Disconnect()
		if not self.Connected then
			return
		end
		self.Connected = false
		local signal = self._signal
		if signal and signal._listeners then
			for i, listener in ipairs(signal._listeners) do
				if listener == self then
					table.remove(signal._listeners, i)
					break
				end
			end
		end
	end

	table.insert(self._listeners, connection)
	return connection
end

function SignalClass:Once(callback: (...any) -> ()): Connection
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		callback(...)
	end)
	return connection
end

function SignalClass:Fire(...: any)
	if self._isDestroyed or not self._listeners then
		return
	end

	-- Clone array to allow re-entrant disconnects safely during dispatch
	local listeners = table.clone(self._listeners)
	for _, connection in ipairs(listeners) do
		if connection.Connected and connection._callback then
			task.spawn(connection._callback, ...)
		end
	end
end

function SignalClass:Wait(): ...any
	local thread = coroutine.running()
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function SignalClass:Destroy()
	if self._isDestroyed then
		return
	end
	self._isDestroyed = true

	if self._listeners then
		for _, connection in ipairs(self._listeners) do
			connection.Connected = false
		end
		table.clear(self._listeners)
		self._listeners = nil
	end
end

-- =========================================================================
-- Event Bus Export
-- =========================================================================

local MiniGameEventBus = {}

-- Factory function for modular package custom signals
function MiniGameEventBus.CreateSignal<T...>(): Signal<T...>
	return SignalClass.new()
end

-- Typed Lifecycle Channels
MiniGameEventBus.SessionStarted = SignalClass.new()
MiniGameEventBus.SessionProgress = SignalClass.new()
MiniGameEventBus.SessionEnded = SignalClass.new()
MiniGameEventBus.ClientMounted = SignalClass.new()
MiniGameEventBus.ClientUnmounted = SignalClass.new()

return MiniGameEventBus
