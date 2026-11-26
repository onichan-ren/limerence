local packages = {
	React = require("@pkg/React"),
	ReactRoblox = require("@pkg/ReactRoblox"),
	ReactRipple = require("@pkg/ReactRipple"),
	ReactCharm = require("@pkg/ReactCharm"),
	Charm = require("@pkg/Charm"),
	Sift = require("@pkg/Sift"),
	Janitor = require("@pkg/Janitor"),
	Promise = require("@pkg/Promise"),
	Signal = require("@pkg/Signal"),
	Ripple = require("@pkg/Ripple"),
}

if getgenv then
	(getgenv() :: any).__limerence_pkgs = packages
else
	(_G :: any).__limerence_pkgs = packages
end

return packages
