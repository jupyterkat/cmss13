
// Light Replacer (LR)
//
// ABOUT THE DEVICE
//
// This is a device supposedly to be used by Janitors and Janitor Cyborgs which will
// allow them to easily replace lights. This was mostly designed for Janitor Cyborgs since
// they don't have hands or a way to replace lightbulbs.
//
// HOW IT WORKS
//
// You attack a light fixture with it, if the light fixture is broken it will replace the
// light fixture with a working light; the broken light is then placed on the floor for the
// user to then pickup with a trash bag. If it's empty then it will just place a light in the fixture.
//
// HOW TO REFILL THE DEVICE
//
// It will need to be manually refilled with lights.
// If it's part of a robot module, it will charge when the Robot is inside a Recharge Station.
//
// EMAGGED FEATURES
//
// NOTICE: The Cyborg cannot use the emagged Light Replacer and the light's explosion was nerfed. It cannot create holes in the station anymore.
//
// I'm not sure everyone will react the emag's features so please say what your opinions are of it.
//
// When emagged it will rig every light it replaces, which will explode when the light is on.
// This is VERY noticeable, even the device's name changes when you emag it so if anyone
// examines you when you're holding it in your hand, you will be discovered.
// It will also be very obvious who is setting all these lights off, since only Janitor Borgs and Janitors have easy
// access to them, and only one of them can emag their device.
//
// The explosion cannot insta-kill anyone with 30% or more health.

#define LIGHT_OK 0
#define LIGHT_EMPTY 1
#define LIGHT_BROKEN 2
#define LIGHT_BURNED 3


/obj/item/device/lightreplacer

	name = "light replacer"
	desc = "A device to automatically replace lights. Can be refill with working lightbulbs and sheets of glass, and can recycle broken lightbulbs."

	icon = 'icons/obj/janitor.dmi'
	icon_state = "lightreplacer0"
	item_state = "light_replacer"
	item_icons = list(
		WEAR_L_HAND = 'icons/mob/humans/onmob/inhands/equipment/tools_lefthand.dmi',
		WEAR_R_HAND = 'icons/mob/humans/onmob/inhands/equipment/tools_righthand.dmi',
	)

	flags_atom = FPRINT|CONDUCT
	flags_equip_slot = SLOT_WAIST

	matter = list("metal" = 20,"glass" = 50)

	var/max_uses = 50
	var/uses = 50
	var/failmsg = ""
	var/charge = 1
	var/recycle = 0
	var/max_recycle = 3

/obj/item/device/lightreplacer/empty
	uses = 0

/obj/item/device/lightreplacer/Initialize()
	. = ..()
	failmsg = "The [name]'s refill light blinks red."

/obj/item/device/lightreplacer/get_examine_text(mob/user)
	. = ..()
	. += "It has [uses] lights remaining, and [recycle] broken lights stored."

/obj/item/device/lightreplacer/attackby(obj/item/W, mob/user)
	if(istype(W, /obj/item/stack/sheet/glass))
		var/obj/item/stack/sheet/glass/glass = W
		if(uses >= max_uses)
			to_chat(user, SPAN_WARNING("[src] is full."))
			return
		else if(glass.use(1))
			AddUses(5)
			to_chat(user, SPAN_NOTICE("You insert a piece of glass into the [src]. You have [uses] lights remaining."))
			return
		else
			to_chat(user, SPAN_WARNING("You need one sheet of glass to replace lights."))

	if(istype(W, /obj/item/light_bulb))
		var/obj/item/light_bulb/bulb = W
		if(bulb.status == 0) // LIGHT OKAY
			if(uses < max_uses)
				AddUses(1)
				to_chat(user, SPAN_NOTICE("You insert the [bulb] into [src]. You have [uses] lights remaining."))
				user.drop_held_item()
				qdel(bulb)
				return
		else
			Recycle()
			to_chat(user, SPAN_NOTICE("You insert the [bulb] into [src] for recycling."))
			user.drop_held_item()
			qdel(bulb)
			return


/obj/item/device/lightreplacer/attack_self(mob/user)
	..()
	to_chat(usr, "It has [uses] lights remaining, and has [recycle] broken lights stored.")

/obj/item/device/lightreplacer/update_icon()
	icon_state = "lightreplacer0"


/obj/item/device/lightreplacer/proc/Use(mob/user)

	AddUses(-1)
	return 1

// Negative numbers will subtract
/obj/item/device/lightreplacer/proc/AddUses(amount = 1)
	playsound(src, 'sound/machines/click.ogg', 25, 1)
	uses = min(max(uses + amount, 0), max_uses)

/obj/item/device/lightreplacer/proc/Charge(mob/user)
	charge++
	if(charge > 7)
		AddUses(1)
		charge = 1

/obj/item/device/lightreplacer/proc/Recycle(mob/living/U)
	if(recycle == max_recycle)
		recycle = 0
		AddUses(1)
		playsound(src, 'sound/machines/ding.ogg', 5, 1)
		return
	else
		playsound(src, 'sound/machines/click.ogg', 25, 1)
		recycle += 1

/obj/item/device/lightreplacer/proc/ReplaceLight(obj/structure/machinery/light/target, mob/living/U)

	if(target.status != LIGHT_OK)
		if(CanUse(U))
			if(!Use(U))
				return
			to_chat(U, SPAN_NOTICE("You replace the [target.fitting] with [src]."))

			if(target.status != LIGHT_EMPTY)

				target.switchcount = 0
				target.status = LIGHT_EMPTY
				target.update()

				Recycle()

			var/obj/item/light_bulb/bulb = new target.light_type()

			target.status = bulb.status
			target.switchcount = bulb.switchcount
			target.rigged = FALSE
			target.brightness = bulb.brightness
			target.on = target.has_power()
			target.update()
			qdel(bulb)

			if(target.on && target.rigged)
				target.explode()
			return

		else
			to_chat(U, SPAN_DANGER(failmsg))
			return
	else
		to_chat(U, "There is a working [target.fitting] already inserted.")
		return

//Can you use it?

/obj/item/device/lightreplacer/proc/CanUse(mob/living/user)
	src.add_fingerprint(user)
	//Not sure what else to check for. Maybe if clumsy?
	if(uses > 0)
		return 1
	else
		return 0

#undef LIGHT_OK
#undef LIGHT_EMPTY
#undef LIGHT_BROKEN
#undef LIGHT_BURNED
