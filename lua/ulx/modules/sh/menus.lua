local CATEGORY_NAME = "Menus"

if ULib.fileExists( "lua/ulx/modules/cl/motdmenu.lua" ) or ulx.motdmenu_exists then
	CreateConVar( "motdfile", "ulx_motd.txt" ) -- Garry likes to add and remove this cvar a lot, so it's here just in case he removes it again.
	CreateConVar( "motdurl", "ulyssesmod.net" ) -- Garry likes to add and remove this cvar a lot, so it's here just in case he removes it again.
	local function sendMotd( ply, showMotd )
		if showMotd == "1" then -- Assume it's a file
			if ply.ulxHasMotd then return end -- This player already has the motd
			if not ULib.fileExists( GetConVarString( "motdfile" ) ) then return end -- Invalid
			local f = ULib.fileRead( GetConVarString( "motdfile" ) )

			ULib.clientRPC( ply, "ulx.rcvMotd", showMotd, f )

			ply.ulxHasMotd = true

		elseif showMotd == "2" then
			ULib.clientRPC( ply, "ulx.rcvMotd", showMotd, ulx.motdSettings )

		else -- Assume URL
			ULib.clientRPC( ply, "ulx.rcvMotd", showMotd, GetConVarString( "motdurl" ) )
		end
	end

	local function showMotd( ply )
		local showMotd = GetConVarString( "ulx_showMotd" )
		if showMotd == "0" then return end
		if not ply:IsValid() then return end -- They left, doh!

		sendMotd( ply, showMotd )
		ULib.clientRPC( ply, "ulx.showMotdMenu", ply:SteamID() ) -- Passing it because they may get it before LocalPlayer() is valid
	end
	hook.Add( "PlayerInitialSpawn", "showMotd", showMotd )

	function ulx.motd( calling_ply )
		if not calling_ply:IsValid() then
			Msg( "You can't see the motd from the console.\n" )
			return
		end

		if GetConVarString( "ulx_showMotd" ) == "0" then
			ULib.tsay( calling_ply, "The MOTD has been disabled on this server." )
			return
		end

		if GetConVarString( "ulx_showMotd" ) == "1" and not ULib.fileExists( GetConVarString( "motdfile" ) ) then
			ULib.tsay( calling_ply, "The MOTD file could not be found." )
			return
		end

		showMotd( calling_ply )
	end
	local motdmenu = ulx.command( CATEGORY_NAME, "ulx motd", ulx.motd, "!motd" )
	motdmenu:defaultAccess( ULib.ACCESS_ALL )
	motdmenu:help( "Show the message of the day." )
	if SERVER then ulx.convar( "showMotd", "2", " <0/1/2/3> - MOTD mode. 0 is off.", ULib.ACCESS_ADMIN ) end

	if SERVER then
		function ulx.populateMotdData()
			if ulx.motdSettings == nil then return end

			ulx.motdSettings.admins = {}
			ulx.motdSettings.addons = nil

			local getAddonInfo = false

			-- Gather addon/admin information to display
			for i=1, #ulx.motdSettings.info do
				local sectionInfo = ulx.motdSettings.info[i]
				if sectionInfo.type == "mods" then
					getAddonInfo = true
				elseif sectionInfo.type == "admins" then
					for a=1, #sectionInfo.contents do
						ulx.motdSettings.admins[sectionInfo.contents[a]] = true
					end
				end
			end

			if getAddonInfo then
				ulx.motdSettings.addons = {}
				local addons = engine.GetAddons()
				for i=1, #addons do
					local addon = addons[i]
					if addon.mounted then
						table.insert( ulx.motdSettings.addons, { title=addon.title, workshop_id=addon.file:gsub("%D", "") } )
					end
				end

				local _, possibleaddons = file.Find( "addons/*", "GAME" )
				for _, addon in ipairs( possibleaddons ) do
					if ULib.fileExists( "addons/" .. addon .. "/addon.txt" ) then
						local t = util.KeyValuesToTable( ULib.fileRead( "addons/" .. addon .. "/addon.txt" ) )
						table.insert( ulx.motdSettings.addons, { title=addon, author=t.author_name } )
					end
				end

				table.sort( ulx.motdSettings.addons, function(a,b) return string.lower(a.title) < string.lower(b.title) end )
			end

			for group, _ in pairs( ulx.motdSettings.admins ) do
				ulx.motdSettings.admins[group] = {}
				for steamID, data in pairs( ULib.ucl.users ) do
					if data.group == group and data.name then
						table.insert( ulx.motdSettings.admins[group], data.name )
					end
				end
			end
		end
		hook.Add( ULib.HOOK_UCLCHANGED, "ulx.updateMotd.adminsChanged", ulx.populateMotdData )
	end

end
