

<!-- If you want to read this online with proper text formatting, you can do so at https://github.com/WasabiRaptor/Starbecue/blob/master/README.md -->


# Support Us!
This is my primary income, and with the current political climate in the USA a person such as myself is going to need all the savings she can get incase shit hits the fan.
https://www.patreon.com/LokiVulpix

# Starbecue

Starbecue is an 18+ fetish mod created for starbound that focuses mainly on Vore, Macro/Micro, and Transformation fetish content as well as many adjacent kinks.

The mod has a opt-in based consent system for deciding what sort of actions you are subject to, as well as perform on other characters whether they be player or NPCs. While there is no way to prevent one from viewing other characters performing actions one may not have opted in to, those actions cannot be performed on you by anyone, and NPCs will ignore you when seeking out those actions. NPCs can also be configured ingame in much the same way players can configure themselves, however, certain OCs may have certain settings locked to a specific value by their owner, please respect their wishes.

Check out the [features](https://github.com/WasabiRaptor/Starbecue/blob/master/features.md) for a comprehensive list and explaination of features in the mod, this is also where you'll find the list of compatible modded races in this version.

[FAQ](https://github.com/WasabiRaptor/Starbecue/blob/master/FAQ.md) has a number of frequently asked questions, make sure to check it to see if theres an answer for you before poking any of the developers about it.

# Install

Latest versions are available on [patreon](https://www.patreon.com/LokiVulpix) or from [github](https://github.com/WasabiRaptor/Starbecue/releases)

This mod Requires [Stardust Core Lite](https://steamcommunity.com/sharedfiles/filedetails/?id=2512589532) or [Stardust Core](https://steamcommunity.com/sharedfiles/filedetails/?id=764887546)

After that, everything required to run the mod is included in the zip on the [releases](https://github.com/WasabiRaptor/Starbecue/releases) page!

Starbecue as of version 4.0 uses [OpenSB-SBQ](https://github.com/WasabiRaptor/OpenStarbound/tree/SBQ) which is a specialized version of [OpenSB](https://github.com/OpenStarbound/OpenStarbound) and should be compatible with any mods that require it. In the future base OpenSB may be all that is required if my features get merged, as I am contributing to it's development. The zip you have been provided with already contains a build of OpenSB-SBQ.

### Included Mods
Before reading the installation instructions below, it would be good to know what each .pak provided with the zip is for! As well as links to where it's source is
- [Starbecue.pak](https://github.com/WasabiRaptor/Starbecue) - The core mod! This contains the code and assets required for vore and kink stuff to work!
- [SBQ-compatibility.pak](https://github.com/WasabiRaptor/SBQ-compatibility) - Contains all the compatibility patches for races to support SBQ, if you want to contribute, there's templates for race compatibility [here](https://github.com/WasabiRaptor/SBQ-Race-Compatibility-Tempate), It's also, a pretty good idea not to remove this but it won't crash or anything, things just won't work.
- [SBQ-LokiVulpix.pak](https://github.com/WasabiRaptor/SBQ-LokiVulpix) - My content addon to SBQ, This is optional if you don't want to have my NPCs or ones people commissioned me for.
- [SBQ-fockoff.pak](https://github.com/FockoffPollo/SBQ-fockoff) - Fockoff's content addon for SBQ, this is also optional.
- [Lexi-lib.pak](https://github.com/WasabiRaptor/Lexi-Starbound-Lib) - A library mod that contains code used by all mods I make! It's required for SBQ to function so don't remove it!
- [Lexi-Pokemon.pak](https://github.com/WasabiRaptor/Lexis-Pokemon-Races) - This is my pokemon races pack! It can be used without SBQ even! one day when it's more complete it will also be on the workshop.
- [Lexi-Races.pak](https://github.com/WasabiRaptor/Lexis-Races) - This is my pack for my other races I've made for starbound, It can also be used without SBQ!
- [Lexi-MetroidDoors.pak](https://github.com/WasabiRaptor/SB_MetroidDoors) - My mod that add's metroid doors, some of it's code is used for a fleshy door, and they're used on the shop map in an underground structure, not *really* required.
- [ShutUpAboutRaceEffects.pak](https://github.com/WasabiRaptor/Fuck-Your-Race-Effects) - FU pollutes the error log constantly with their own incompetence in how they implemented race effects, this makes it shut up.

Anyway if you're interested in no longer playing with FU, take a look at this [document](https://docs.google.com/document/d/1SFQFL2FFTUc0P4JLLECTmWLFsZXvEocT/edit) because it has links to all the mods that FU stole and some alternatives! I personally, would rather enjoy not having to sift through all the errors that FU is constantly throwing out for various things when people bring me error logs.


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
