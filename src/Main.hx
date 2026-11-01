package mods.shared_pet;

import haxe.Timer;
import mods.api.Context;
import mods.api.Mod;
import mods.api.account.Account;
import mods.api.account.OwnedHero;
import mods.api.account.Pet;
import openfl.events.Event;

/**
 * Moves the pet that follows onto the hero selected in town, in place of the one it carries. The pet
 * that follows is the selected hero's at the start, then whatever is equipped on the selected hero by
 * hand; none once it is left without a pet.
 */
class Main extends Mod {
	/** Seconds between two reads of what the selected hero carries; a change of hero is seen at once. */
	static inline final CHECK = 0.5;

	var context:Context;

	var moving:Bool = false;

	var checkedAt:Float = 0;

	/** The pet that follows, by `uid`: 0 for none, null until the first hero is read. */
	var pet:Null<UInt> = null;

	/** The selected hero at the last read. */
	var hero:UInt = 0;

	/** What the selected hero carried at the last read: a change while it stays selected was made by hand. */
	var carried:UInt = 0;

	override public function init(ctx:Context):Void {
		context = ctx;
		ctx.overlay.addEventListener(Event.ENTER_FRAME, function(_) check());
	}

	function check():Void {
		var account = context.state.account;
		if (!context.state.inTown || moving || account == null || account.activeAvatarId == 0)
			return;
		var now = Timer.stamp();
		var changed = account.activeAvatarId != hero;
		if (!changed && now - checkedAt < CHECK)
			return;
		checkedAt = now;
		hero = account.activeAvatarId;
		var selected = owned(account, hero);
		if (selected == null)
			return;
		var current = selected.pets.length > 0 ? selected.pets[0].uid : 0;
		if (!changed) {
			if (current != carried)
				pet = carried = current;
			return;
		}
		carried = current;
		if (pet == null) {
			pet = current;
			return;
		}
		var follows = find(account, pet);
		if (follows == null || current == pet)
			return;
		moving = true;
		var started = selected.equipPet(follows, function(ok) {
			moving = false;
			context.log(ok ? '${follows.name} moved to the ${selected.className}.' : '${follows.name} could not move to the ${selected.className}.');
		});
		if (!started)
			moving = false;
	}

	static function owned(account:Account, id:UInt):Null<OwnedHero> {
		for (hero in account.inventory.heroes)
			if (hero.id == id)
				return hero;
		return null;
	}

	/** The account's pet of that `uid`, in storage or on a hero. */
	static function find(account:Account, uid:UInt):Null<Pet> {
		if (uid == 0)
			return null;
		for (pet in account.inventory.pets)
			if (pet.uid == uid)
				return pet;
		for (hero in account.inventory.heroes)
			for (pet in hero.pets)
				if (pet.uid == uid)
					return pet;
		return null;
	}
}
