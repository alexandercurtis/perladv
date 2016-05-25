# Perladv
A text adventure engine written in Perl.
by Alex Curtis, 2008

## Usage

    perl adv.pl house.adv

## Playing the game

Like any text adventure, the game is played by reading the description of your situation and reacting by entering simple commands of the form `VERB OBJECT`.

Possible verbs include:

* `help`,`verbs`,`words`
* `instructions`
* `quit`,`q`
* `look`
* `exits`
* `dump` *Prints the current adventure data to stdout.*
* `north`,`n`
* `south`,`s`
* `east`,`e`
* `west`,`w`
* `up`,`u`
* `down`,`d`
* `northeast`,`ne`
* `southeast`,`se`
* `northwest`,`nw`
* `southwest`,`sw`
* `in`
* `out`,`exit`
* `chk`
* `take`,`get`
* `drop`
* `inventory`,`inv`,`invent`
* `examine`,`exam`

## God Mode

There are various *god commands* that can be used to develop an adventure while playing it:

* `write <filename>`
* `addlocation`    - it prompts you for the details
* `addexit` - it prompts you for details. including what to say when user takes this exit.
* `rmexit`
* `addobject <objname>:<specifier>:<description>[:<visibility>[:<gettable>]]` - specifier = {"a","some",...}, visibility = {visible,hidden}, gettable = {"","You can't","replenishes"}
* `addsynonym <synonym>:<objname>`
* `summon`  automatically gets an object from anywhere to current loc
* `own`  automatically gets an object from anywhere
* `hide` automatically make a carried object disappear
* `state` sets a state variable
* `debug <number>` sets the level of debug output

Use `addlocation` and `addexit` god commands to add to the world. `addlocation` can also be used to edit a location by overwriting it. Save with `write adventure_.adv`.
