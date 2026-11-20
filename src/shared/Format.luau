--!strict
-- Format: money and rate strings for the HUD. $83.2M, $1.32K/s, $6.39M/s.

local Format = {}

function Format.money(n: number): string
	local sign = ""
	if n < 0 then
		sign = "-"
		n = -n
	end
	if n >= 1_000_000_000 then
		return sign .. "$" .. string.format("%.2fB", n / 1_000_000_000)
	elseif n >= 1_000_000 then
		return sign .. "$" .. string.format("%.2fM", n / 1_000_000)
	elseif n >= 10_000 then
		return sign .. "$" .. string.format("%.1fK", n / 1_000)
	elseif n >= 1_000 then
		return sign .. "$" .. string.format("%.2fK", n / 1_000)
	else
		return sign .. "$" .. string.format("%d", math.floor(n + 0.5))
	end
end

function Format.rate(n: number): string
	return Format.money(n) .. "/s"
end

function Format.plain(n: number): string
	return string.format("%d", math.floor(n + 0.5))
end

return Format
