# FAQ

### Q: It's crashing when I try to start the game!
> A: Manually verify each file is installed correctly, the script puts things in the expected default location, your computer may have installed starbound somewhere else.
> A: If you're hosting a server, make sure you downloaded and are using the provided server executable.
> A: Make sure to remove old versions.

### Q: How do I get to the shop?
> A: If you can't find the fireplace on a lush planet, you can access it via the outpost teleporter.

### Q: I can't do X vore action!
> A: Check your pred settings, make sure it's enabled, if it is, check the target's settings using the Nominomicon, they might be disabled or locked, if you can't check their settings they're incompatible.
> A: If its Tail Vore, make sure your tail is compatible with it.

### Q: NPC/Monster/Object won't do X vore action!
> A: Check your prey settings, if they're enabled, then check the NPC's settings, they might be disabled or locked.

### Q: I can't click the teleport button for some reason?
> A: Due to how starbound handles UI, the pred HUD has an invisible area above it that it extends into when it expands for the prey slots, this area is tecnically always part of the UI and therefore can 'cover' the teleport button if your screen size is too small, Starbound has no GUI scale option that could alleviate this and that's outside the scope of my engine modifications.

### Q: Why can't I eat more prey even though I have hammerspace?
> Lounge positions in starbound must be pre-defined in the entity data, therefore they cannot be added to on the fly, I decided that 16 slots is a reasonable amount to be the limit.

### Q: If I get transformed and upgrade my ship while a different species will it break?
> A: Thats a bug in retail and fixed in SBQ-Engine, It should stay as the original ship species

### Q: Can X species be supported?
> A: It might! and I'm gonna need yooooour help! Use this [template](https://github.com/WasabiRaptor/SBQ-Race-Compatibility-Tempate) which will work with most species, and then send me the files afterwards.
> A: I take requests from patrons for species compat from time to time, it will probably be faster if you do it yourself, its not very hard.

### SSVM
> Hasn't been a dependency for years
> I didn't ever work on SSVM itself, early versions of SBQ started as an add on, but had any code from SSVM it relied on replaced with my own in version 2.0 and then the mod has since been fully rewritten again for 3.0. So this mod is an entirely different beast.
> SBQ is not incompatible with SSVM, however I will make no personal effort for parity, as SSVM is ancient, and unmaintained.

### StarPounds
> Shouldn't be incompatible as far as I know.
> No parity has been added yet.
