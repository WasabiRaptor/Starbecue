--[[
	here we have SSVM's monster primary message handlers, these are here only for compatibilty to not break the mod when we install alongside it
	we should *not* be using any of these messages ourselves in any of our scripts

	SSVM can be found here
	https://github.com/Sheights/StarboundSimpleVoreMod/releases
]]

local oldinit = init
function init()
	oldinit()

	message.setHandler("vsoForceApply", function( _, _, x, y, xmode, ymode )
		if xmode > 0 then
			if xmode == 1 then
				mcontroller.setXVelocity( mcontroller.xVelocity() + x )
			elseif xmode == 2 then
				mcontroller.setXVelocity( x)
			elseif xmode == 3 then
				mcontroller.force( { x,0 } )
			elseif xmode == 4 then
				--mcontroller.approachXVelocity( x, float maxControlForce)
			elseif xmode == 5 then
				--mcontroller.addMomentum
			end
		end
		if ymode > 0 then
			if ymode == 1 then
				mcontroller.setYVelocity( mcontroller.yVelocity() + y )
			elseif ymode == 2 then
				mcontroller.setYVelocity( y )
			elseif ymode == 3 then
				mcontroller.force( { 0,y } )
			elseif ymode == 4 then
				--mcontroller.approachXVelocity( x, float maxControlForce)
			elseif ymode == 5 then
				--mcontroller.addMomentum
			end
		end
	end )

	--message.setHandler( "vsoChangeDamageTeam", function( _, _, value )
	--	--Hm...
	--	--return monster.setDamageTeam( value )
	--end )

	message.setHandler( "vsoStatusPropertySet", function( _, _, prop, value )
		return status.setStatusProperty( prop, value )
	end )

	message.setHandler( "vsoStatusPropertyGet", function( _, _, prop, defaultvalue )
		return status.statusProperty( prop, defaultvalue )
	end )

	message.setHandler( "vsoResourceGetSummary", function( _, _ )
		local R = {}
		for i,k in pairs( status.resourceNames() ) do
			R[k] = {
				status.resource(k)	--isResource
				,status.resourceMax(k)
				,status.resourcePercentage(k)
				,status.resourcePositive(k)
				,status.resourceLocked(k)
			}
		end
		return R;
	end )

	message.setHandler( "vsoResourceAddPercent", function( _, _, resname, deltapercent, resthresh )

		if resthresh ~= nil then
			local epsilon = 1;
			local retval = true;
			local resthreshreal = resthresh*status.resourceMax( resname );
			local currval = status.resource( resname );
			local deltaval = deltapercent*status.resourceMax( resname );
			local nextval = currval + deltaval
			if deltapercent < 0 then
				if nextval <= resthreshreal+epsilon then
					status.setResource( resname, resthreshreal+epsilon )
					retval = false;
				else
					status.modifyResource( resname, deltaval )
				end
			elseif deltapercent > 0 then
				if nextval >= resthreshreal-epsilon then
					status.setResource( resname, resthreshreal-epsilon )
					retval = false;
				else
					status.modifyResource( resname, deltaval )
				end
			end
			return retval;
		else

			if deltapercent < 0 then
				status.overConsumeResource( resname, -deltapercent*status.resourceMax( resname ) )
			else
				status.modifyResourcePercentage( resname, deltapercent );
			end
			return status.resource( resname ) > 0;
		end
	end )
end
