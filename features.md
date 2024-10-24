
# Getting Started
On creation of a new character, a popup menu will open up to allow one to quickly assign vore preferences, as well as an agreement to enable yourself to use the mod's content. To change those settings and access further settings, then open the toolbar and select **Starbecue Settings** to open the settings menu.

To get started with the mod, all you need to do is open your crafting interface, and craft the **SBQ Controller** this is the main item used to perform actions, and can be re-assigned via it's action wheel.

Available actions are determined by your current species, what sort of state you're in, and most importantly, what settings you have enabled. Actions you cannot perform with your current settings will not be displayed to you, so if you think you're missing some actions, go check your settings. And if the requisite settings aren't being displayed, then it's just not something the current species can do.

More content can be found via discovering **Auri's Shop** which you can get to via some mysterious fireplaces you might find on lush planets, you can also reach the outpost and warp to it from its teleporter.

## Settings Overview
The settings are accessed via the toolbar and selecting **Starbecue Settings**.

The **Main** tab is mostly focused with predator based settings, changing what effects your body has and etc. Some settings are specific to your current species, though most are global. Some settings are also reliant on other preferences to be displayed.
> Eg: Cock Vore related settings will not be shown if one has not selected that they are a Cock Vore Pred.

The **Prefs** tab controls consent based settings on what actions you can perform and what can be performed on you, as well as modifiers on how much they might be able to effect you.

The **Help** tab contains general information about the mod, it probably contains some of the same information in this readme!

Depending on your species, you may also find an additional tab with a manual to explain that species' specific capabilities!

You can also use the **Nominomicon** to open the settings page for any SBQ Compatible NPC, Monster, or Object to edit their settings and read their manual in the same manner as you would for yourself, however OC NPCs may have certain settings locked to a specific value by their owner.

---

# Features
An exhaustive list of features in the mod in no particular order

## Consent system
The mod features a consent system which requires players to explicitly opt-in to having all the various types of actions and fetishes apply to their character or not. This also applies to NPCs which are configureable, certain OC NPCs may have certain settings locked by their owner. Other mods might sometimes interfere with the script setting the values on non SBQ NPCs to enable actions on them, I cannot avoid this whether those other mods intended to do this or not. Certain NPCs from vanilla, such as merchants and other special NPCs, intentionally have fetishes disabled on them.

---

## Vore NPC Overview
SBQ features multi-purpose vore NPCs which can be summoned with special deeds added by SBQ or when an NPC of a compatible race and type spawns, they have a 1/8 chance of replacing basic villager, guard, or bandit NPCs when they first spawn in. These NPCs have **Hunger**, **Lust**, and **Rest** resources which may impact their behavior depending on how they are configured, and will either try to hunt down the player or other NPCs to eat them, or get eaten by them, with whatever vore preferences the NPC rolled when they first spawned in.

Most randomly generated NPCs will always roll every prey action as valid, and will have a 50% chance for each pred action to be enabled on them, as well as various other rolls for what their favorite type is, what effects their belly and other locations have active, etc.

Vore NPCs upon generation will be treated as if they have eaten the basic **Rock Candy** up to their tier, they can be fed further upgrades in their misc tab.

### Quests
Vore NPCs depending on their settings may generate some vore related quests depending on their behavior setting.
- Belly Fetch: The NPC has eaten something they can't digest, you have to go in and fetch it!
- Vore Escort: You have to find and retrieve an NPC, but the target just stands around... you'll have to bring them back some other way...
- Transform: The NPC wants to try out being a different species, you'll have to transform them somehow...

### Dialogue
Vore NPCs, depending on their behavior settings may have different contextual dialogue relating to the actions a player is taking with them, ranging from reactions to struggling and different status effects. OC NPCs tend to have unique dialogue for cases their Owner favored and wrote unique dialogue for. If dialogue is disabled, interacting with an NPC will simply bring up a radial menu for their available actions. NPCs will only list what actions they can do that are available, ones that are greyed out are ones they can technically perform, but are either too full, missing something they need to do it, or some other condition is preventing them from doing so, attempting to pick it should have them inform you why they can't.

NPCs have a few different personality types to choose between
- default
- flirty
- shy
- meanbean (bandit)

Default NPCs will have unique dialogue depending on
- Struggles/Struggling
 - Body location
 - Status effects
 - Being infused
 - Prey escaping/Trying to escape
 - Letting prey out/Being let out
- Requesting Actions with/without consent
- Performing Actions with/without consent
- Per location climax (When lust bar fills from struggling)

### Hunting
Vore NPCs can have their favorite vore types configured for pred and prey seperately, whether they reserve hunting for each type for friendly or hostile NPCs, and if they only hunt for a specific type when a resource is within a certain threshold.
> Eg: An NPC can be configured to only go hunting OV on hostile characters when hungry, and to seek getting UBed by friendly characters when they're tired.

NPCs will periodically go hunting, roll whether they're hunting as a pred, or seeking to be prey, and then roll for which type based on what types they have enabled, and which of those is configured to be more favorite. After which they will then seek out valid targets in their area for their chosen action, choosing the closest target first. If they're hunting as pred, there is a chance they will continue their hunting streak after successfully getting their target, and move on to the next valid target. NPCs will move onto the next valid target if they were unsuccessful with their current target until there are no targets left. If an NPC asked a player and got no response and moved on, or the player accidentally dismissed the prompt, the NPC will remember their prompt for a few minutes if the player interacts with them again.

NPCs can be forced to begin hunting with a simple command while your cursor is hovering over them `/entityeval sbq_hunting.start()` which rolls everything as normal. `/entityeval sbq_hunting.dom()` or `/entityeval sbq_hunting.sub()` would cause them to specifically go for pred or prey respectively. In any case, one can input a string to make them seek a specific action such as `/entityeval sbq_hunting.sub("oralVore")`

NPCs which willingly request to be eaten or gave consent to be eaten will be treated as if they are holding **Shift** for 5 minutes while struggling, therefore they will not be attempting to escape during that time period. However this also means that they will not struggle into other locations in the body during that period.

### Vore Bandits : sbqVoreBandit
Vore Bandits will **always** spawn with Oral Vore Pred enabled, and will **always** spawn with the main effect of their body locations set to Fatal Digest, and they will not hunt 'friendly' characters (other enemies on the same team as themselves). So watch out, they'll see you as a meal the moment they set their sights on you.

### Vore Tenants
Vore tenants are summoned via the vore colony deed purchaseable in Auri's shop.
- Tenant : sbqVoreTenant
- Guard : sbqVoreFriendlyGuardTenant

### Vore Crew
Randomly generated NPC Tenants can graduate to being a crew member if applicable! The Nominomicon can also be used to convert vanilla crew variants into a vore capable version of themselves! Only the owner of the crewmember can access their menu with the nominomicon to configure settings/convert them.

Do note that many mods that edit how crew loads or spawns in may not be friendly to the scripts I inserted that are required for the crew's settings and conversion to save properly, I tried my best to implement it in a way thats friendly to other modifications in parrallel, however other mods may not have done so.

Only the crew member variants that exist in vanilla that join your party are available.
- Soldier : sbqVoreCrewmember
- Chemist Blue : sbqVoreCrewmemberChemistBlue
- Chemist Green : sbqVoreCrewmemberChemistGreen
- Chemist Orange : sbqVoreCrewmemberChemistOrange
- Chemist Yellow : sbqVoreCrewmemberChemistYellow
- Engineer : sbqVoreCrewmemberEngineer
- Janitor : sbqVoreCrewmemberJanitor
- Mechanic : sbqVoreCrewmemberMechanic
- Medic : sbqVoreCrewmemberMedic
- Outlaw : sbqVoreCrewmemberOutlaw

### Vore Villagers
Basic vanilla villagers have 1/8 chance to turn into a vore version when they are initially generated
- Villager : sbqVoreVillager
- Village Guard : sbqVoreVillageGuard
- Village Guard Captain : sbqVoreVillageGuardCaptain
- Friendly Guard : sbqVoreFriendlyGuard

Spawning NPCs manually can be done with a simple command `/spawnnpc human sbqVoreVillager`
I have listed the IDs alongside their type, IDs for compatible species are listed as well down below.

### OC NPCs
Most of these characters cannot be played as, however can be spawned in via the **SBQ Colony Deed** which can be purchased in Auri's shop.
- Loki Deerfox (Pred/Prey) LokiVulpix
- Auri Drimyr (Pred/Prey) LokiVulpix
- Socks Flareon (Pred/Prey) LokiVulpix
- Clover Meowscarada (Pred/Prey) LokiVulpix
- Zevi Goocat (Pred/Prey) Zygahedron
- Helena Hellhound (Pred/Prey) FFWizard
- Sandy Floatporeon (Pred/Prey) Fevix
- Batty (Pred/Prey) Xeronious
- Blue the Synth (Pred/Prey) Blueninja (requires [Synth](https://steamcommunity.com/sharedfiles/filedetails/?id=2207290706))
- Akari Kaen (Pred/Prey)
- Ferri Catfox (Pred/Prey) Ferrilata_
- Xeronious (Pred)

---

## Vore System
Using the **SBQ Controller**, a player can asign it to perform a specific action to used when they click on a target within range, only if that target has allowed that action of course. If you hold shift when clicking, this is treated as asking for consent, it sends a simple Yes/No prompt to the targeted player, NPCs will just automatically respond. Certain Settings require this consent prompt to be used to perform the action on the character. If an action fails, it will notify the player of why it failed by a message at the bottom of the screen.

### Pred
After eating another character, you will then have the pred HUD in the bottom right, this can be used to select additional actions which may be unique to the location the occupant is inside, these actions can also be accessed via selecting an occupant in the controller's radial menus.

Vore Actions available on default NPCs/Players
- Oral Vore
- Absorb Vore
- Navel Vore
- Anal Vore
- Unbirth
- Breast Vore
- Cock Vore

Some species may have additional types if available!
- Tail Vore

#### Lockdown
The big red "Lock Down" button in the HUD will put you into "Lock Down" mode, which nullifies your base passive energy regen, but will prevent any prey from triggering struggle actions until you run out of energy. If you're in this mode you'll have it indicated with your status effects. NPCs will often enable this from time to time based on their behavior settings.

#### Body Locations
Eating Prey will apply status effects to them, cause the relevant body part to expand in size, some locations have multiple states of expansion depending on how large the prey inside are. Prey will be able to struggle, and potentially cause animations or other actions to occur, such as moving to another location in the body or escaping.

Main status effects are mutually exclusive due to how they impact HP therefore only one can be chosen per location.
- None
- Heal
- Soft Digest (brings prey to 1 HP and then treats them as "digested")
- Fatal Digest

Secondary Status effects can all be toggled individually and have no impact on eachother aside from some applying in sequence, or not being available in certain locations.
- Energy Drain: Slows prey's energy regen and speeds up pred's
- Transform: Transform's prey into pred's species, or species infused in that location.
- Infuse: Passively infuse the character into the relevant type
- Eggify: Trap the prey within an egg

Some Effects are only available post digestion.
- Reformation: After soft digest, start slowly restoring HP until the character is reformed.

Other settings.
- Compression: Causes prey to get smaller over time, or by the percentage of their health depending on which is selected
- Hammerspace: Treats the location as if it has no upper limit to the amount of prey that can fit inside, there is no visual expansion past the set expansion limit.
- Fill modifiers: Numbers inputs to configure how prey contributes to that locations fill level.

#### Digestion
Prey can adjust resistance and immunity to fatal for each digestion type, just as preds can adust their digest power for each type. At 100% Resistance prey become immune to that digest type entirely, if fatal immunity is enabled then fatal digest is treated the same as soft digest.

Digest types and the locations they usually apply to
- Acid: Belly
- Milk: Breasts
- Femcum: Womb
- Cum: Cock, Balls

When prey are digested or infused, if they had any prey within themselves, then their own prey is dumped into the location in the pred they were digested. If there are no available slots they'll simply be released.

Upon being digested, if both pred and prey have item drops for that digest type enabled, then a relevant item will be dropped which contains data pretaining to that character, which can then be used in the infuse slot, or inserted into a deed to re-summon that NPC if applicable.

Digested prey may be able to be shifted to other locations to infuse them there or reform them there, for example, digesting someone in belly, and then say, shifting them to the womb to reform and transform them.

#### Upgrades
The power of status effects are configured per the relevant fluid for the location, your maximum overall power can be increased by eating the **Rock Candy** for each tier.

### Prey
When you've been eaten a prey HUD will open up in the bottom right, indicating the directions one can press to cause a struggle animation. The color of the indicator arrow hints at what struggling in that direction might do for you.

Pressing **Interact** from within can bring up an NPC pred's dialogue, or a simple radial menu. From these menus you will have actions you can request from the pred listed. As of current, an NPC will always attempt to fulfill a request. Players you'll simply have to ask them in chat.

Holding **Shift** will prevent any actions from occuring from your struggles, only playing the animations, useful to not unintentionally escape.

- Red: You might be able to escape the pred.
- Blue: Might make the pred change state.
- Green: Might make the pred change state, or let you move to another location in the predator's body, regardless it'll be easier for you to escape.
- Cyan: Might let you move to another location within the predator's body.
- Yellow: Might get the pred to perform some sort of action on you.
- Locked: Pred is in "Lock Down" mode, you won't be able to escape until they've exhausted too much energy suppressing your struggling.

### Emergency Escape
If you ever find yourself in a situation that's over your head, and you want to immediately get out of it, there is an Instant Escape Combo. To perform it, hold **Shift**+**Down** then press **Jump**.

---

## Infuse System
Either by doing it directly, or after vore. Characters can be 'Infused' into other characters, this is the umbrella term I am using to describe things such as Sentient Fat, Cock TF, etc. This can add size to the host's relevant parts, apply the character's colors.

You can find sliders per location determining the level of fade for the colors of the infusee, and the percentage of their size they contribute.

NPCs will have special dialogue for both being infused and infusing someone else.

Infuse Actions available on default NPCs/Players
- Belly TF
- Breast TF
- Pussy TF
- Cock TF

---

## Scaling System
Players, NPCs, and Monsters can be scaled!

A characters' scale multiplies their base power and protection stats by the square root of their scale.

Players will have the camera zoom in and out automatically as they shrink and grow, the zoom out level is capped by the maximum zoom out starbound's graphics settings allow.

Players will also have their mining tool's break power and size multiplied by their scale as well!

Your maximum allowed scale can be increased by eating the **Rock Candy** for each tier. However, your scale is capped at 10x For the sake of your computer not melting.

---

## Transformation System
Characters can be transformed by various means within SBQ, this is actual real engine approved transformation as far as the game is concerned. Certain races may not play with this well because they were not designed with it in mind and sometimes their scripts do not remove persistent status effects that were applied.

The duration of TF effects can be configured per character.
- Indefiniete TF makes TF last until a reversion potion is used.
- Perma TF causes your 'original' species to be overwritten with each TF, so don't choose it lightly!

After a player as transformed into a total of 7 different species they will unlock the **Shapeshifter** tech, which will allow them to freely TF into any species they have been before as well as customize their appearance as each species. TF via the tech is always treated as indefinite.

In any case where your name is changed while in active gameplay, while it is saved in character data, one cannot change the client connection name on a server without disconnecting and re-connecting, so instead we simply have it pretend you used the `/nick` command to change your server nickname.

---

## Miscellaneous
Using the Nominomicon, one can give NPCs certain clothes to wear in the misc tab.

Players also have the **Lust**, and **Rest** resources, despite them serving no true gameplay purpose for players.

### Stripping
On the misc tab, NPCs and Players can be configured to have each piece of clothing be auto hidden upon reaching a certain level of Lust, this is simply cosmetic in nature. Players by default will never strip. NPCs by default strip everything aside from their hat at 50% lust.

---

## Compatible Species
Species which are supported are listed down below, unsupported races will still be able to use the controllers for the default available actions, but will not have any special animations when performing most of them.

Most species will only need a simple patch to be made compatible, as well as added to the valid tenant list, a template can be found [here](https://github.com/WasabiRaptor/SBQ-Race-Compatibility-Tempate)

One can also create their own OC for the mod using this template [here](https://github.com/WasabiRaptor/SBQ-NPC-Template)

### SBQ Special Species
These species are special species and may possess more abilities or play differently than one's standard state
- Giant Vaporeon : sbq/vaporeonGiant
- Slime : sbq/Slime
- Ziellek Dragon : sbq/LakotaAmitola/ziellekDragon

### SBQ Species
Races included within SBQ by default
- Vaporeon (Feral) : sbq/vaporeon
- Flareon (Feral) : sbq/flareon
- Meowscarada : sbq/meowscarada
- Hellhound : sbq/FFWizard/hellhound

### External Compatible Species
This mod includes patches for the species below to add compatibility, it does not include any of their respective assets.
- Human : human
- Hylotl : hylotl
- Floran : floran
- Avian : avian
- Apex : apex
- Glitch : glitch
- Novakid : novakid
- Fenerox : fenerox
- [Avali](https://steamcommunity.com/sharedfiles/filedetails/?id=729558042) : avali
- [Novali](https://steamcommunity.com/sharedfiles/filedetails/?id=1386730092) : novali
- [Lucario](https://steamcommunity.com/sharedfiles/filedetails/?id=1356955138) : lucario
- [Lycanroc](https://steamcommunity.com/sharedfiles/filedetails/?id=1800401078) : lycanroc
- [Eevee](https://steamcommunity.com/sharedfiles/filedetails/?id=1405822108) (GalaxyFoxes) : eevee
- [Eevee](https://steamcommunity.com/sharedfiles/filedetails/?id=3194891396) (GalaxyFoxesEX) : eevee
- [Eevee](https://steamcommunity.com/sharedfiles/filedetails/?id=1266991719) (Remade) : eeveetwo
- [Jolteon](https://steamcommunity.com/sharedfiles/filedetails/?id=2075613227) : jolte
- [Espeon](https://steamcommunity.com/sharedfiles/filedetails/?id=1144430324) : espeon
- [Umbreon](https://steamcommunity.com/sharedfiles/filedetails/?id=730345787) : Umbreon
- [Glaceon](https://steamcommunity.com/sharedfiles/filedetails/?id=2012704863) : glaceonfox
- [Sylveonoid](https://steamcommunity.com/sharedfiles/filedetails/?id=2843385916) : sylveonoid
- [Braixen](https://steamcommunity.com/sharedfiles/filedetails/?id=2260578148) : braixen
- [Delphox](https://steamcommunity.com/sharedfiles/filedetails/?id=2260578148) : delphox
- [Zoroark](https://steamcommunity.com/sharedfiles/filedetails/?id=2811625141) : zoroark
- [Hisui Zoroark](https://steamcommunity.com/workshop/filedetails/?id=2813977483) : hisuzor
- [Crylan](https://steamcommunity.com/sharedfiles/filedetails/?id=1197335162) : crylan
- [Rodent](https://github.com/Zygahedron/StarboundSimpleVoreMod) (Sheights' version of SSVM is broken, this is a fixed fork) : rodent
- [Lyceen](https://steamcommunity.com/sharedfiles/filedetails/?id=1360547769) : lyceen
- [Latex](https://steamcommunity.com/sharedfiles/filedetails/?id=1818502101) : myfirsttest
- [Elysian](https://steamcommunity.com/sharedfiles/filedetails/?id=1405822108) (GalaxyFoxes) : elysian
- [Elysian](https://steamcommunity.com/sharedfiles/filedetails/?id=3194891396) (GalaxyFoxesEX) : elysian
- [Fennix](https://steamcommunity.com/sharedfiles/filedetails/?id=1405822108) (GalaxyFoxes) : fennix
- [Fennix](https://steamcommunity.com/sharedfiles/filedetails/?id=3194891396) (GalaxyFoxesEX) : fennix
- [Felin](https://steamcommunity.com/sharedfiles/filedetails/?id=729429063) : felin
- [Draconis](https://steamcommunity.com/workshop/filedetails/?id=868165595) : dragon
- [Draconis](https://steamcommunity.com/sharedfiles/filedetails/?id=1226150792) (Full Dragon Reskin) : dragon
- [Gnolls](https://steamcommunity.com/sharedfiles/filedetails/?id=1655860448) : gnolls
- [Argonians](https://steamcommunity.com/sharedfiles/filedetails/?id=740694177) : argonian
- [Sergals](https://steamcommunity.com/sharedfiles/filedetails/?id=1420856270) : sergal
- [Familiars](https://steamcommunity.com/sharedfiles/filedetails/?id=729597107) : familiar
- [Vulpes](https://steamcommunity.com/sharedfiles/filedetails/?id=1307942879) : vulpes
- [Kazdra](https://steamcommunity.com/sharedfiles/filedetails/?id=767787220) : kazdra
- [Elduukhar](https://steamcommunity.com/sharedfiles/filedetails/?id=729480149) : elduukhar
- [Attarran](https://steamcommunity.com/sharedfiles/filedetails/?id=797166006) : Attarran
- [Neki](https://steamcommunity.com/sharedfiles/filedetails/?id=2611501999) : neki
- [Mechineki](https://steamcommunity.com/sharedfiles/filedetails/?id=2740063170) : mechineki
- [Lastree](https://steamcommunity.com/sharedfiles/filedetails/?id=1380941596) : lastree
- [Synth](https://steamcommunity.com/sharedfiles/filedetails/?id=2207290706) : synth
- [Bunnykin](https://steamcommunity.com/sharedfiles/filedetails/?id=732452461) : bunnykin
- [Yharian](https://www.furaffinity.net/view/47517002/) : yharian
- [Spacekidds](https://steamcommunity.com/sharedfiles/filedetails/?id=2790390697) : spacekidds
- [Viera](https://steamcommunity.com/sharedfiles/filedetails/?id=732276079) : viera
- [Everis](https://steamcommunity.com/sharedfiles/filedetails/?id=1117006719) : everis
- [Bossmonster](https://steamcommunity.com/sharedfiles/filedetails/?id=1563090801) : dreemurrers
- [Twilit Wolves](https://steamcommunity.com/sharedfiles/filedetails/?id=1818480557) : twilitwolves
- [Mons](https://steamcommunity.com/sharedfiles/filedetails/?id=2310314462) : mons
- [Spirit Tree](https://steamcommunity.com/sharedfiles/filedetails/?id=2191906942) : spirittree
- [Squamaeft](https://steamcommunity.com/sharedfiles/filedetails/?id=2462459956) : squamaeft

---

## Techs

### Shapeshifter : sbqTransform
The tech is used to freely transform into and customize your appearance as each individual species, you can even change which name you use as that species! This is quite useful for RP purposes to 'change character' without having to have a seperate character save to play as. TF via this tech is always treated as indefinite, regardless of other settings.

To get it immediately just do `/enabletech sbqTransform` (you will still have to equip it)

---

## Items

### Nominomicon : sbqNominomicon
Used to access the settings of any SBQ compatible NPC, this includes vanilla NPCs as long as other mods have not interfered with SBQ scripts loading on them.

NPCs can be converted To/From Vanilla and Vore versions if applicable by a convert button in the misc tab. If the button does not show, then the NPC does not have an equivalent type.

This item is not intended as a debug or godmode item, it is intended for use to configure your NPCs as desired as many might not roll their settings in a way you like initally.

### SBQ Controller : sbqController
Used to do any of SBQ's special actions, ranging from simply grabbing other characters to eating them. It can be crafted at any time for a single pixel.

There is nothing preventing you from grabbing a player who has already grabbed someone else.

### Potions
Used for transforming into different species, different ones can be made for slightly different behavior!
- Mysterious Potion: Random TF into any species installed that hasn't been marked incompatible : sbqMysteriousPotion
- Species Potion: Used to make a potion for your current species : sbqSpeciesPotion
- Genderswap Potion: Switches your gender : sbqGenderSwapPotion
- Clone Potion: Used to make a potion to TF someone into your species and look exactly like you, nickname and all : sbqDuplicatePotion
- Reversion Potion: Reverts you to your original species (keep in mind if you have perma TF on, every TF becomes your new 'original') : sbqReversionPotion

Example command to spawn in a potion preloaded with the parameters to TF someone into a specific species
`/spawnitem sbqMysteriousPotion 1 {"identity":{"species":"human"}}`

### Potion Dart Gun : sbqPotionDartGun
A 'weapon' used to apply potion effects to other targets, it will consume potions held in the other hand when it is fired to shoot a dart, if you miss the dart might drop the potion on the ground to be reused.

### Size Ray : sbqSizeRay
Chage up shots to shrink or grow the target it hits!

### Rock Candy : sbqCandy
Eat these to increase your maximum potential digest power, as well as your maximum scale. Theres one of these for each tier craftable at the anvil, however finding them as loot has potential to give even even better results, if you find one that's glowing, thats the best you can find for the tier. Check your Misc tab to see which ones you've eaten.

Example command to spawn in a tiered candy, crafted candies will never have a bonus higher than 1, loot candies' bonus will never go higher than its level
`/spawnitem sbqCandy 1 {"level":1, "bonus":1}`

### Plastic Egg : sbqPlasticEgg
A silly re-usable plastic egg, behaves exactly like the egg status except it drops an item and can be re-used.

### Egg Wand : sbqEggWand
A silly magic wand that traps people in eggs.

---

## Objects

### Vore Colony Deed : sbqVoreColonyDeed
Spawns SBQ's special vore NPCs, has a menu to select which NPC you want to summon, as well as inform you what colony tags they desire, often lets you order furniture with the relevant colony tags. NPCs can be inserted and removed from deeds as cards, Deeds will also accept items containing NPC data, such as the items NPCs might drop when digested.

Can be locked so no other players (other than admins) can edit the NPCs it contains, as well a toggle to be nearly invisible.

### Mini Vore Deed : sbqMiniVoreDeed
Same as the Vore Colony Deed except it only occupies one tile.

### Vore Campsite : sbqVoreCamp
Similar to the Mini Vore Deed except it requires no background anchor, and doesn't require an enclosed space, however will only get tags from objects in a 15 block radius. Empty tiles along its region's border will contribute `door` and `open_air` tags.

### Digestion Drops
Objects which get dropped when players/NPCs are digested, requires a setting enabled on both the pred and the prey per digest type to drop. Some of these may apply the colors of the digested prey if they were of a compatible species.
- Remains: Acid Digest
- Condom: Cum Digest, Femcum Digest (needs something better for fem in future probably)
- Milk Carton: Milk Digest

---

# Support Us!

https://www.patreon.com/LokiVulpix
