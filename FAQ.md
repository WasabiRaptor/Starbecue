<!-- If you want to read this online with proper text formatting, you can do so at https://github.com/WasabiRaptor/Starbecue/blob/master/FAQ.md -->

# FAQ

### Q: It's crashing when I try to start the game!
> Make sure you're using the modified OSB executable provided in the zip, look at the readme for install instructions.
> If you're hosting a server, make sure you downloaded and are using the provided server executable.
> Make sure to remove old versions of the mod if they are present.

### Q: I can't open any of the menus!
> This mod Requires [Stardust Core Lite](https://steamcommunity.com/sharedfiles/filedetails/?id=2512589532) or [Stardust Core](https://steamcommunity.com/sharedfiles/filedetails/?id=764887546)
> Remove [Qickbar Mini](https://steamcommunity.com/sharedfiles/filedetails/?id=1088459034) The above dependencies replace it.

### Q: How do I get to the shop?
> If you can't find the fireplace on a lush planet, you can access it via the outpost teleporter.
> command `/warp instanceworld:sbqHub`

### Q: NPC/Monster/Object won't do X vore action!
### Q: I can't do X vore action!
> Things like Cock Vore and Breast Vore need the relevant body parts to be selected.
> Check the pred's settings, make sure it's enabled, if it is, check the target's settings, they might be disabled or locked.
> Player settings can be opened from the HUD or from the toolbar, NPC/Object/Monster settings can be opened by clicking on them with the Nominomicon. if you can't check their settings they're incompatible.
> Certain species or NPCs may have certain settings locked.
> Admins can configure to disable/lock certain actions on a server wide or per world basis using commands.
> If its Tail Vore, make sure your tail is compatible with it.

### Q: I'm a server admin and I would like to disable certain things.
> use the `/sbq config` command to open a menu, if you're host you'll be allowed to assign overrides globally to the server.

### Q: Why can't I eat more prey even though I have hammerspace?
> You are limited to a certain number of prey slots, determined by how many of SBQ's rock candies you've eaten to upgrade your vore power, it eventually caps at 32 slots.

### Q: If I get transformed and upgrade my ship while a different species will it break?
> Thats a 'bug' in retail from modifying player data, and fixed in OSB by having the ship's species as a seperate value in the player/ship data.

### Q: I got transformed but don't like how I look!
> `/sbq customize` will open a little menu to change your appearance for your current species.

### Q: What species are supported?
> Theres a list of the species supported [here](https://github.com/WasabiRaptor/Starbecue/blob/master/features.md#compatible-species)

### Q: Can X species be supported?
> It might! and I'm gonna need yooooour help! Use this [template](https://github.com/WasabiRaptor/SBQ-Race-Compatibility-Tempate) which will work with most species, and then send me the files afterwards. You can also see all the existing compatibility patches [here](https://github.com/WasabiRaptor/SBQ-compatibility) if you need examples.
> I take requests from patrons for species compat from time to time, it will probably be faster if you do it yourself, its not very hard, and a fan has provided a video tutorial that will cover how to do most custom races.

### Q: What are all these different mods in the zip?
> They are explained in the readme [here](https://github.com/WasabiRaptor/Starbecue/blob/master/README.md#included-mods)


### Futara's Dragon Race
### Futara's Dragon Engine
> Futara's Dragon Engine literally breaks the game. No joke, it's 'optimizations' cause the tick rate of the game to become broken. The only reason this effects OSB and not the retail build of starbound, is that the retail build of starbound has a typo which makes these patches not do as much, meanwhile OSB fixed the typo, which meant these patches started to actually effect the game, and break it. Here's a tutorial on how to remove the files from FDE that cause the game to break, which should still let the rest of the mod function.
> They're also doing something weird with player rendering and they crash their own script on certain species I added because they didn't implement proper error handling for data they expected to be somewhere to not be there. Nothing I can do about that.

Follow this [tutorial](https://steamcommunity.com/sharedfiles/filedetails/?id=745239455) to unpack a starbound workshop mod, and unpack Futara's Dragon Engine, it's steam content ID is 2297133082.

After extracting the mod, you'll want to place it into your mods folder, and then unsubscribe from FDE.

In your unpacked version of FDE, you'll need to delete these files.
- `client.config.patch`
- `rendering.config.patch`
- `universe_server.config.patch`
- `worldserver.config.patch`

This will remove their 'optimization' patches that change how the game's tick rate behaves, while leaving the rest of the mod intact.


### SSVM
> Make sure you're using [this version](https://github.com/Zygahedron/StarboundSimpleVoreMod) As the original version of the mod has been broken for years now.
> Hasn't been a dependency for years
> I didn't ever work on SSVM itself, early versions of SBQ started as an add on, but had any code from SSVM it relied on replaced with my own in version 2.0 and then the mod has since been fully rewritten again for 3.0 and then another big rewrite for 4.0 So this mod is an entirely different beast by this point.
> SBQ is not incompatible with SSVM, however I will make no personal effort for parity, as SSVM is ancient, and unmaintained.

### StarPounds
> Shouldn't be incompatible as far as I know.
> No parity has been added yet.
