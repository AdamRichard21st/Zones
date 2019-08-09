# Description
Define and limit map zones dinamically by the amount of players in-game.

# Features
* Set map zones and define the minimum amount of players which zone will wait before getting unlocked.
* Set all-time locked map zones.
* Set object models as part of zone.

# Settings
This project is release in a dual manner.
You should not use both plugins at same time, so, do as follow:

* Enables `zone_editor.amxx` plugin when setting up map zones
* Enables `zone_core.amxx` plugin when map zones are setted

Note that you can also install `zone_core.amxx` plugin only, but, you'll need to generate `zones.ini` file with each map zone settings in order to let `zone_core.amxx` handle it. Useful for sharing settings through your servers without installing both plugins.

# Defining custom zone models
Inside `zones.ini` settings file, you can define custom model to be used as zone blockers, such as solid objects inside map:
```
"My custom model name" "models/my_model_file.mdl"
```

Setting an object which has body-groups inside it:
```
"My custom body A" "models/my_bodygroup.mdl" "0"
"My custom body B" "models/my_bodygroup.mdl" "1"
"My custom body C" "models/my_bodygroup.mdl" "2"
```

Setting an object which has texture-groups `only`:
```
"My custom texture A" "models/my_texturegroup.mdl" "" "0"
"My custom texture B" "models/my_texturegroup.mdl" "" "1"
```

Setting an object which has body-groups `and` texture-groups:
```
"My custom object A" "models/my_bodygroup.mdl" "0" "0"
"My custom object B" "models/my_bodygroup.mdl" "1" "1"
"My custom object C" "models/my_bodygroup.mdl" "0" "2"
"My custom object D" "models/my_bodygroup.mdl" "1" "3"
```

Setting an object which has animation `only`:
```
"My animated object A" "models/my_animated.mdl" "" "" "0"
```

Setting an object which has body-groups `and` animations:
```
"My animated object A" "models/my_animated.mdl" "0" "" "0"
"My animated object B" "models/my_animated.mdl" "1" "" "1"
"My animated object C" "models/my_animated.mdl" "2" "" "1"
```

# Commands
Commands are part of `zone_editor.amxx` only:

command     | description
------------|------------
zone_menu   | Opens zone editor menu. Make sure to have `ADMIN_RCON` access when settings up zones.

# Installation
First and foremost, your server must to have [amxmodx](https://wiki.alliedmods.net/Category:Documentation_(AMX_Mod_X)#Installation) installed & running.

* Copy `zones.ini` settings file to `$addons/amxmodx/configs` folder in your server.
* Copy `zones.json` data file to `$addons/amxmodx/configs` folder in your server.
* Copy `zones.txt` dictionary file to `$addons/amxmodx/data/lang` folder in your server.
* Copy `zone_core.amxx` to `$addons/amxmodx/plugins` folder in your server.
* Copy `zone_editor.amxx` to `$addons/amxmodx/plugins` folder in your server.
* Add `zone_core.amxx` line to your `plugins.ini` file located at `addons/amxmodx/configs` folder.
* Add `zone_editor.amxx` line to your `plugins.ini` file located at `addons/amxmodx/configs` folder.

[read more](https://wiki.alliedmods.net/Configuring_AMX_Mod_X#Plugins)

Optionally, if you are using plain settings on `zones.ini` file, copy `models` folder from `resources/models` project directory to your `cstrike/models` folder.

# Want to help?
Feel free to suggest changes or create [pull requests](https://help.github.com/en/articles/about-pull-requests) to this repository, including source changes or dictionary translations improvements/additions.
