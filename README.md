# robot-recall-fixed

_n.b._: This mod was forked from [343N's robot-recall](https://mods.factorio.com/mod/robot-recall), to fix an issue with the module not loading due to a missing icon.item_size.

This mod adds two items:

__Robot Recall Station__
A logistic container which lets you recall robots to it. Bots will 'teleport' there, in the same amount of time that it would take them to travel from their location. (You can't command robots to move places in world with mods, at least, not easily). This only recalls currently IDLE robots sitting in roboport inventories. Should work with any modded robots that work in roboports, tested with bobs and angels robots.

__Robot Redeployment Station__
A logistic container which automatically places any bots put in it. Bots will automatically move to any roboports in their vicinity. Robots will only be deployed, if at the time of deployment, there is space for it in the logistic network. This container does the equivalent of placing a bot manually as the player, on the position the container is at.

Note: Recall progress was not saved in between sessions before version 0.1.6. That has now changed. As a result, a massive desync has also been fixed. This mod is now multiplayer safe and persistent between sessions (yay!)

__Missing your Locale?__
Feel free to go to the github repo and create a pull request with your own locale file and locale changes!