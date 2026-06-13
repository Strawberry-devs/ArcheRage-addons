# ArcheRage Addons

These are ArcheAge addons specifically created for the RU version of ArcheAge, found at https://ru.archerage.to/. 

They should be compatible with the NA version. They are not compatible (but usually with some effort can be ported) to Classic or AAFree. Official RU does not support Addons.

All addons should fall under acceptable use of the addon policy.


## Installation

Directly clone the repository into C:\ArcheRage\Documents\Addon or wherever your Addon folder is located. The "globals" folder is needed for all addons.

After that restart your client and enable the addons you need in character select:
![char select](https://i.imgur.com/zYkJFuJ.png)
    
## Contributing

Contributions are welcome, please use pull requests or flag up issues. I am also available on discord at exec_noir.

## Lua linting

Lua linting is set up with `luacheck` in both CI and local git hooks.

Install and run locally:

```powershell
luarocks install luacheck
powershell -ExecutionPolicy Bypass -File .\scripts\install-hooks.ps1
```

This enables `.githooks/pre-commit`, which lints staged `.lua` files before each commit.

## Tests

Unit tests cover the game-independent modules in `globals/` (currently `windowstate.lua`) and run on every push and pull request via the `Lua Tests` workflow.

Tests use [busted](https://lunarmodules.github.io/busted/). Install and run locally:

```powershell
luarocks install busted
busted
```

Specs live in `spec/` and end in `_spec.lua`. Modules that talk to the live ArcheRage UI API (`UIParent`, `X2*`, widgets) cannot be tested headless; keep testable logic free of those globals so it can be covered here.

# Current Addons:

## Autorole  
Sets your role when you join a raid, as well as when you change class (either through the skill guy or skill saver, both are handled).  
Also makes your role disco-dance when you are casting dance of sacrifice.  
![Disco dance](https://i.imgur.com/SHCTnOi.gif)

## Big Cast Bars  
Gives you large cast bars, requires statue buff for now.  
Does not overwrite the regular cast bar. Also adds timer to the cast.  
![Big casts example](https://i.imgur.com/XuCD0Xn.png)

## Buff Cap tracker  
Tracks your number of buffs and checks whether you are hitting the cap.  
Once you have hit the cap, any additional buffs will not be applied (songs, etc) or it will push buffs off when they should be re-applied (flame freerunner).  

## Class tracker  
Tracks the class of your target, printing the name of their skillset with an icon estimating their actual "class" (healer, tank, ...).  
![Buff cap example](https://i.imgur.com/BzZZAuH.png)

## Distance tracker  
Tracks the distance to your target. Turns red at 30m (adjustable).  
![Buff cap example](https://i.imgur.com/A1j8PSb.png)  

## Dress-up  
Allows you to dress your character up with whatever you want.  
Item ID's are found at https://wiki.archerage.to/ru-en/db/items/  
![Dress-up example](https://i.imgur.com/GhVQnOO.png)  

## Gearscore tracker  
Tracks your target's gearscore.  
![Buff cap example](https://i.imgur.com/Nzdjic3.gif)  

## Hidden Debuff Tracker  
The **Hidden Debuff Tracker** is a tool that tracks hidden debuffs of the selected target.  
![Hidden debuffs example](https://i.imgur.com/vBbivx2.png)  

## Lua error printer  
Prints all errors from console (ArcheRage.log) to the in-game chatbox.  
![Error printout](https://i.imgur.com/TW2gjKN.png)  

## Personal Portals setter  
Tracks and sets if you are using all portals, or just your own.  
![Personal Portals picture](https://i.imgur.com/SMW1UUX.png)

## Raidchecker
Checks raid buffs and classes.

## Raidcheckersiege
Check who has which siege equipment.

## Reloadcfg
Reloads system.cfg on world enter, meaning custom items (like nameplate boxes) will remain applies through relogs.

## Residentboard
Prints out current continent's full resident board (blue salt bond) info.

## Scalinglock
Locks your scaling setting to whatever you pick in the code.

## Shinysac  
Puts a bar with timer over whoever in your raid is currently casting sac. Works for entire raid 1 & 2, not enemies or friendlies.  
![Shiny sac](https://i.imgur.com/lwdWph0.gif)

## Target Debuff Tracker
The **Target Debuff Tracker** is a tool that tracks buffs and debuffs of the selected target. It also tracks defiance separately.  
![Buff track example](https://i.imgur.com/mgAFbsp.png)

## Tigerstrike
Unfinished proof of concept to track if tiger strike is up on an enemy.

## Timeuntil
Keeps track of timers (BD, RD, CR, GR, etc)

## Titleswap
Freely swap titles in a neat box.  
![Titleswap example](https://i.imgur.com/OcIq9la.png)

## Translate
In-game Automatic Translation tool  
![Translation example](https://i.imgur.com/0ao0UTs.png)

## uirefresh
Refresh UI on button press; triggers a loading screen.
