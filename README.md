# Support Us!
This is my primary income, and with the current political climate in the USA a person such as myself is going to need all the savings she can get incase shit hits the fan.
https://www.patreon.com/LokiVulpix

# Starbecue

Starbecue is an 18+ fetish mod created for starbound that focuses mainly on Vore, Macro/Micro, and Transformation fetish content as well as many adjacent kinks.

The mod has a opt-in based consent system for deciding what sort of actions you are subject to, as well as perform on other characters whether they be player or NPCs. While there is no way to prevent one from viewing other characters performing actions one may not have opted in to, those actions cannot be performed on you by anyone, and NPCs will ignore you when seeking out those actions. NPCs can also be configured ingame in much the same way players can configure themselves, however, certain OCs may have certain settings locked to a specific value by their owner, please respect their wishes.

Check out `features.md` for a comprehensive list and explaination of every feature in the mod, this is also where you'll find the list of compatible modded races in this version.

`FAQ.md` has a number of frequently asked questions, make sure to check it to see if theres an answer for you before poking any of the developers about it.

# Install

Latest versions are available on [patreon](https://www.patreon.com/LokiVulpix) or from [github](https://github.com/WasabiRaptor/Starbecue/releases)

This mod Requires [Stardust Core Lite](https://steamcommunity.com/sharedfiles/filedetails/?id=2512589532) or [Stardust Core](https://steamcommunity.com/sharedfiles/filedetails/?id=764887546)

Starbecue as of version 4.0 uses [OpenSB-SBQ](https://github.com/WasabiRaptor/OpenStarbound/tree/SBQ) which is a specialized version of [OpenSB](https://github.com/OpenStarbound/OpenStarbound) and should be compatible with any mods that require it. In the future base OpenSB may be all that is required if my features get merged, as I am contributing to it's development. The zip you have been provided with already contains a build of OpenSB-SBQ.


## Steam Install

I have included some convenient setup scripts for each OS!

### Windows
Simply use the `install.bat` (which just is a convenient way to execute the `install.ps1`) which should try to find your starbound installation and then install the files to it!

### Linux
`cd` into the folder and do
```
chmod -x install.sh
./install.sh
```
It will attempt to find your starbound installation to copy the files to it.

### Macos
Open the terminal and type `cd ` and then drag the unzipped folder into the terminal to copy the path, and then press enter. This will open the folder in the terminal.

Now enter `sh install.sh` to run the install script.

It will attempt to find your starbound installation to copy the files to it.

## Portable Install

You will have downloaded a zip containing a portable installation of OpenSB-SBQ for your relevant OS, extract it and place it anywhere you want, but for the game to function you will need to retrieve `packed.pak` from your purchased copy of Starbound.

On Steam, click on Starbound -> Properties -> Installed Files -> Browse. Then open the `assets` folder within that directory, you will find a `packed.pak` file, copy it into the `assets` folder of the OpenSB install. If you want to move your saves, copy the `storage` folder too.

On Linux and Macos Silicon there is an additional step which is further below.

After that you're done! You can simply open the game executable which will be within the folder named after your relevant OS.

Unlike SBQ-Engine, OpenSB has no issues connecting to retail SB servers, just some of the expanded features will not function while doing so.

`starbecue.pak` is already placed within the mods folder of this portable install, it is also safe to remove it if one doesn't want to play with it.

### Linux
You just have to mark the executable as execuatble. `cd` into the linux folder and to `chmod -x starbound` and you're done.

### Macos Silicon

If you attempted the open the game on macos after doing the above, you might have seen a message saying something like this:
`starbound.app is damaged and can’t be opened. You should move it to the trash.`

That is apple lying to you. The equivalent error on a windows system would be that the app is made by an unidentified developer, and you would be given the option to run it anyway. It is fine to protect users from potential malware when a program doesn't have proper id certification, but lying to them about why the program won't open is rather infantilizing don't you agree?

There is a simple fix until apple decides they won't allow it anymore. Copy `xattr -c ` into the terminal, and then drag the `starbound.app` in the `osx` folder into it to copy its path, and then hit enter.

This should remove the quarentine flags and allow the application to run.


# Support Us!

https://www.patreon.com/LokiVulpix

Vote on what should be the next feature worked on!

## Main Credits

### LokiVulpix / Wasabi_Raptor

Artist, Lua scripting and debugging.

> I take commissions! contact me if I am open!
>
> https://itaku.ee/profile/lokivulpix
> https://twitter.com/LokiVulpix

### Zygan (Zygahedron)

Artist, Lua scripting and debugging.
