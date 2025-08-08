# FAQ

### Q: It's crashing when I try to start the game!
> Make sure to have retrieved the base game `assets.pak`, look at the readme for instructions
> If you're hosting a server, make sure you downloaded and are using the provided server executable.
> Make sure to remove old versions.

### Q: How do I get to the shop?
> If you can't find the fireplace on a lush planet, you can access it via the outpost teleporter.
> command `/warp instanceworld:sbqHub`

### Q: NPC/Monster/Object won't do X vore action!
### Q: I can't do X vore action!
> Check the pred's settings, make sure it's enabled, if it is, check the target's settings, they might be disabled or locked.
> Player settings can be opened from the HUD or from the toolbar, NPC/Object/Monster settings can be opened by clicking on them with the Nominomicon. if you can't check their settings they're incompatible.
> Certain species or NPCs may have certain settings locked.
> Admins can configure to disable/lock certain actions on a server wide or per world basis using a special object.
> If its Tail Vore, make sure your tail is compatible with it.

### Q: I'm a server admin and I would like to disable certain things.
> Read about the Locked Settings Enforcer in `features.md`

### Q: I can't click the teleport button for some reason?
> Due to how starbound handles UI, the pred HUD has an invisible area above it that it extends into when it expands for the prey slots, this area is tecnically always part of the UI and therefore can 'cover' the teleport button if your screen size is too small, Starbound has no GUI scale option that could alleviate this and that's outside the scope of my engine modifications.

### Q: Why can't I eat more prey even though I have hammerspace?
> As of current, you are limited to 8 slots, I am currently working on a feature to be able to decide how many slots you get, but it isn't ready yet.

### Q: If I get transformed and upgrade my ship while a different species will it break?
> Thats a 'bug' in retail from modifying player data, and fixed in SBQ-Engine by having the ship's species as a seperate value in the player/ship data.

### Q: What species are supported?
> Theres a list of the species supported in `features.md`

### Q: Can X species be supported?
> It might! and I'm gonna need yooooour help! Use this [template](https://github.com/WasabiRaptor/SBQ-Race-Compatibility-Tempate) which will work with most species, and then send me the files afterwards.
> I take requests from patrons for species compat from time to time, it will probably be faster if you do it yourself, its not very hard, and a fan has provided a video tutorial that will cover how to do most custom races.

### SSVM
> Hasn't been a dependency for years
> I didn't ever work on SSVM itself, early versions of SBQ started as an add on, but had any code from SSVM it relied on replaced with my own in version 2.0 and then the mod has since been fully rewritten again for 3.0. So this mod is an entirely different beast.
> SBQ is not incompatible with SSVM, however I will make no personal effort for parity, as SSVM is ancient, and unmaintained.

### StarPounds
> Shouldn't be incompatible as far as I know.
> No parity has been added yet.
