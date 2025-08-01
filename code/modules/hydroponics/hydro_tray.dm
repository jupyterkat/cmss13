#define HYDRO_SPEED_MULTIPLIER 1
#define HYDRO_WATER_CONSUMPTION_MULTIPLIER 1.5

/obj/structure/machinery/portable_atmospherics/hydroponics
	name = "hydroponics tray"
	icon = 'icons/obj/structures/machinery/hydroponics.dmi'
	icon_state = "hydrotray3"
	density = TRUE
	anchored = TRUE
	unslashable = FALSE
	health = 100
	flags_atom = OPENCONTAINER
	throwpass = 1
	layer = BELOW_OBJ_LAYER

	var/draw_warnings = 1 //Set to 0 to stop it from drawing the alert lights.

	// Plant maintenance vars.
	var/waterlevel = 100    // Water (max 100)
	var/nutrilevel = 100    // Nutrient (max 100)
	var/pestlevel = 0   // Pests (max 10)
	var/weedlevel = 0   // Weeds (max 10)

	// Tray state vars.
	var/dead = 0    // Is it dead?
	var/harvest = 0 // Is it ready to harvest?
	var/age = 0 // Current plant age
	var/sampled = 0 // Have wa taken a sample?

	// Harvest/mutation mods.
	var/yield_mod = 0   // Modifier to yield
	var/mutation_mod = 0    // Modifier to mutation chance
	var/toxins = 0  // Toxicity in the tray?
	var/mutation_level = 0  // When it hits 100, the plant mutates.

	// Mechanical concerns.
	var/plant_health = 0  // Plant health.
	var/lastproduce = 0 // Last time tray was harvested
	var/lastcycle = 0   // Cycle timing/tracking var.
	var/cycledelay = 150    // Delay per cycle.
	var/closed_system   // If set, the tray will attempt to take atmos from a pipe.
	var/force_update    // Set this to bypass the cycle time check.
	var/obj/temp_chem_holder   // Something to hold reagents during process_reagents()

	// Seed details/line data.
	var/datum/seed/seed = null // The currently planted seed

	// Reagent information for process(), consider moving this to a controller along
	// with cycle information under 'mechanical concerns' at some point.
	var/global/list/toxic_reagents = list(
		"anti_toxin" =  -2,
		"arithrazine" = -1.5,
		"carbon" =  -1,
		"silicon" = -0.5,
		"chlorine" = 1.5,
		"sulphuric acid" =    1.5,
		"fuel" = 2,
		"toxin" =    2,
		"radium" =   2,
		"dinitroaniline" =  2,
		"mutagen" =  2.5,
		"fluorine" = 2.5,
		"pacid" =    3,
		"plantbgone" =   3,
		"chlorine trifluoride" = 8
		)
	var/global/list/nutrient_reagents = list(
		"milk" = 0.1,
		"phosphorus" =   0.1,
		"sugar" =    0.1,
		"sodawater" =    0.1,
		"beer" = 0.25,
		"nutriment" =    1,
		"adminordrazine" =  1,
		"eznutrient" =   1,
		"robustharvest" =   1,
		"left4zed" = 1,
		"ammonia" =  2,
		"diethylamine" = 3
		)
	var/global/list/weedkiller_reagents = list(
		"plantbgone" =  -8,
		"dinitroaniline" = -6,
		"adminordrazine" = -5,
		"pacid" =   -4,
		"fluorine" =    -4,
		"chlorine" =    -3,
		"sulphuric acid" =   -2,
		"phosphorus" =  -2,
		"sugar" =    2
		)
	var/global/list/pestkiller_reagents = list(
		"adminordrazine" = -5,
		"dinitroaniline" = -3,
		"diethylamine" =   -2,
		"sugar" =    2
		)
	var/global/list/water_reagents = list(
		"water" =    1,
		"adminordrazine" =  1,
		"milk" = 0.9,
		"beer" = 0.7,
		"flourine" =    -0.5,
		"chlorine" =    -0.5,
		"phosphorus" =  -0.5,
		"water" =    1,
		"sodawater" =    1,
		)

	// Beneficial reagents also have values for modifying yield_mod and mut_mod (in that order).
	var/global/list/beneficial_reagents = list(
		"beer" =    list( -0.05, 0,   0   ),
		"fluorine" =    list( -2, 0,   0   ),
		"chlorine" =    list( -1, 0,   0   ),
		"phosphorus" =  list( -0.75, 0,   0   ),
		"sodawater" =   list(  0.1,  0,   0   ),
		"sulphuric acid" =   list( -1, 0,   0   ),
		"pacid" =   list( -2, 0,   0   ),
		"plantbgone" =  list( -2, 0,   0.2 ),
		"dinitroaniline" = list( -0.5,  0,   0.1 ),
		"ammonia" = list(  0.5,  0,   0   ),
		"diethylamine" =   list(  2, 0,   0   ),
		"nutriment" =   list(  0.5,  0.1,   0 ),
		"radium" =  list( -1.5,  0,   0.2 ),
		"adminordrazine" = list(  1, 1,   1   ),
		"robustharvest" =  list(  0, 0.2, 0   ),
		"left4zed" =    list(  0, 0,   0.2 )
		)

	// Mutagen list specifies minimum value for the mutation to take place, rather
	// than a bound as the lists above specify.
	var/global/list/mutagenic_reagents = list(
		"ryetalyn" =  -8,
		"arithrazine" = -6,
		"radium" =  8,
		"mutagen" = 15
		)

/obj/structure/machinery/portable_atmospherics/hydroponics/Initialize()
	. = ..()
	temp_chem_holder = new()
	temp_chem_holder.create_reagents(10)
	create_reagents(200)
	update_icon()
	start_processing()

/obj/structure/machinery/portable_atmospherics/hydroponics/initialize_pass_flags(datum/pass_flags_container/PF)
	..()
	if (PF)
		PF.flags_can_pass_all = PASS_OVER|PASS_AROUND|PASS_TYPE_CRAWLER

/obj/structure/machinery/portable_atmospherics/hydroponics/bullet_act(obj/projectile/Proj)

	//Don't act on seeds like dionaea that shouldn't change.
	if(seed && seed.immutable > 0)
		return 0

	..()

/obj/structure/machinery/portable_atmospherics/hydroponics/process()

	//Do this even if we're not ready for a plant cycle.
	process_reagents()

	// Update values every cycle rather than every process() tick.
	if(force_update)
		force_update = 0
	else if(world.time < (lastcycle + cycledelay))
		return
	lastcycle = world.time

	// Mutation level drops each main tick.
	mutation_level -= rand(2,4)

	// Weeds like water and nutrients, there's a chance the weed population will increase.
	// Bonus chance if the tray is unoccupied.
	if(waterlevel > 10 && nutrilevel > 2 && prob(QDELETED(seed) ? 5 : 1))
		weedlevel += 1 * HYDRO_SPEED_MULTIPLIER

	// There's a chance for a weed explosion to happen if the weeds take over.
	// Plants that are themselves weeds (weed_tolerance > 10) are unaffected.
	if (weedlevel >= 10 && prob(10))
		if(!seed || weedlevel >= seed.weed_tolerance)
			weed_invasion()

	// If there is no seed data (and hence nothing planted),
	// or the plant is dead, process nothing further.
	if(!seed || dead)
		if(draw_warnings)
			update_icon() //Harvesting would fail to set alert icons properly.
		return

	// Advance plant age.
	if(prob(30) && nutrilevel > 0 && waterlevel > 0)
		age += 1 * HYDRO_SPEED_MULTIPLIER

	//Highly mutable plants have a chance of mutating every tick.
	if(seed.immutable == -1)
		var/mut_prob = rand(1,100)
		if(mut_prob <= 5)
			mutate(mut_prob == 1 ? 2 : 1)

	// Other plants also mutate if enough mutagenic compounds have been added.
	if(!seed.immutable)
		if(prob(min(mutation_level,100)))
			mutate((rand(100) < 15) ? 2 : 1)
			mutation_level = 0

	// Maintain tray nutrient and water levels.
	if(seed.nutrient_consumption > 0 && nutrilevel > 0 && prob(25))
		nutrilevel -= max(0,seed.nutrient_consumption * HYDRO_SPEED_MULTIPLIER)
	if(seed.water_consumption > 0 && waterlevel > 0  && prob(25))
		waterlevel -= floor(max(0,(seed.water_consumption * HYDRO_WATER_CONSUMPTION_MULTIPLIER) * HYDRO_SPEED_MULTIPLIER))

	// Make sure the plant is not starving or thirsty. Adequate
	// water and nutrients will cause a plant to become healthier.
	// Checks if there are sufficient enough nutrients, if not the plant dies.
	var/healthmod = rand(1,3) * HYDRO_SPEED_MULTIPLIER
	if(seed.requires_nutrients && prob(35))
		plant_health += (nutrilevel < 2 ? -healthmod : healthmod)
	if(seed.requires_water && prob(35))
		plant_health += (waterlevel < 10 ? -healthmod : healthmod)

	// Check that pressure, heat are all within bounds.
	// First, handle an open system or an unconnected closed system.

	// Toxin levels beyond the plant's tolerance cause damage, but
	// toxins are sucked up each tick and slowly reduce over time.
	if(toxins > 0)
		var/toxin_uptake = max(1,floor(toxins/10))
		if(toxins > seed.toxins_tolerance)
			plant_health -= toxin_uptake
		toxins -= toxin_uptake

	// Check for pests and weeds.
	// Some carnivorous plants happily eat pests.
	if(pestlevel > 0)
		if(seed.carnivorous)
			plant_health += HYDRO_SPEED_MULTIPLIER
			pestlevel -= HYDRO_SPEED_MULTIPLIER
		else if (pestlevel >= seed.pest_tolerance)
			plant_health -= HYDRO_SPEED_MULTIPLIER

	// Some plants thrive and live off of weeds.
	if(weedlevel > 0)
		if(seed.parasite)
			plant_health += HYDRO_SPEED_MULTIPLIER
			weedlevel -= HYDRO_SPEED_MULTIPLIER
		else if (weedlevel >= seed.weed_tolerance)
			plant_health -= HYDRO_SPEED_MULTIPLIER

	// Handle life and death.
	// If the plant is too old, it loses health fast.
	if(age > seed.lifespan)
		plant_health -= rand(3,5) * HYDRO_SPEED_MULTIPLIER

	// When the plant dies, weeds thrive and pests die off.
	if(plant_health <= 0)
		dead = 1
		mutation_level = 0
		harvest = 0
		weedlevel += 1 * HYDRO_SPEED_MULTIPLIER
		pestlevel = 0

	// If enough time (in cycles, not ticks) has passed since the plant was harvested, we're ready to harvest again.
	else if(LAZYLEN(seed.products) && age > seed.production && (age - lastproduce) > seed.production && (!harvest && !dead))
		harvest = 1
		lastproduce = age

	if(prob(3))  // On each tick, there's a chance the pest population will increase
		pestlevel += 0.1 * HYDRO_SPEED_MULTIPLIER

	check_level_sanity()
	update_icon()
	return

//Process reagents being input into the tray.
/obj/structure/machinery/portable_atmospherics/hydroponics/proc/process_reagents()

	if(!reagents)
		return

	if(reagents.total_volume <= 0)
		return

	reagents.trans_to(temp_chem_holder, min(reagents.total_volume,rand(1,3)))

	for(var/datum/reagent/R in temp_chem_holder.reagents.reagent_list)

		var/reagent_total = temp_chem_holder.reagents.get_reagent_amount(R.id)

		if(seed && !dead)
			//Handle some general level adjustments.
			if(toxic_reagents[R.id])
				toxins += toxic_reagents[R.id]  * reagent_total
			if(weedkiller_reagents[R.id])
				weedlevel += weedkiller_reagents[R.id] * reagent_total
			if(pestkiller_reagents[R.id])
				pestlevel += pestkiller_reagents[R.id] * reagent_total

			// Beneficial reagents have a few impacts along with health buffs.
			if(beneficial_reagents[R.id])
				plant_health += beneficial_reagents[R.id][1]    * reagent_total
				yield_mod += beneficial_reagents[R.id][2] * reagent_total
				mutation_mod += beneficial_reagents[R.id][3] * reagent_total

			// Mutagen is distinct from the previous types and mostly has a chance of proccing a mutation.
			if(mutagenic_reagents[R.id])
				mutation_level += reagent_total*mutagenic_reagents[R.id]+mutation_mod

		// Handle nutrient refilling.
		if(nutrient_reagents[R.id])
			nutrilevel += nutrient_reagents[R.id]  * reagent_total

		// Handle water and water refilling.
		var/water_added = 0
		if(water_reagents[R.id])
			var/water_input = water_reagents[R.id] * reagent_total
			water_added += water_input
			waterlevel += water_input

		// Water dilutes toxin level.
		if(water_added > 0)
			toxins -= floor(water_added/4)

	temp_chem_holder.reagents.clear_reagents()
	check_level_sanity()
	update_icon()

//Harvests the product of a plant.
/obj/structure/machinery/portable_atmospherics/hydroponics/proc/harvest(mob/user)

	//Harvest the product of the plant,
	if(!seed || !harvest || !user)
		return

	if(closed_system)
		to_chat(user, "You can't harvest from the plant while the lid is shut.")
		return

	seed.harvest(user,yield_mod)

	// Reset values.
	harvest = 0
	lastproduce = age

	if(!seed.harvest_repeat)
		yield_mod = 0
		seed = null
		dead = 0
		age = 0
		sampled = 0
		mutation_mod = 0

	check_level_sanity()
	update_icon()
	return

//Clears out a dead plant.
/obj/structure/machinery/portable_atmospherics/hydroponics/proc/remove_dead(mob/user)
	if(!user || !dead)
		return

	if(closed_system)
		to_chat(user, SPAN_WARNING("You can't remove the dead plant while the lid is shut."))
		return

	seed = null
	dead = 0
	sampled = 0
	age = 0
	yield_mod = 0
	mutation_mod = 0

	to_chat(user, SPAN_NOTICE("You remove the dead plant from [src]."))
	check_level_sanity()
	update_icon()

//Refreshes the icon and sets the luminosity
/obj/structure/machinery/portable_atmospherics/hydroponics/update_icon()

	overlays.Cut()

	// Updates the plant overlay.
	if(!QDELETED(seed))

		if(draw_warnings && plant_health <= (seed.endurance / 2))
			overlays += "over_lowhealth3"

		if(dead)
			overlays += "[seed.plant_icon]-dead"
		else if(harvest)
			overlays += "[seed.plant_icon]-harvest"
		else if(age < seed.maturation)

			var/t_growthstate = floor(age/seed.maturation * seed.growth_stages)
			overlays += "[seed.plant_icon]-grow[t_growthstate]"
			lastproduce = age
		else
			overlays += "[seed.plant_icon]-grow[seed.growth_stages]"

	//Draw the cover.
	if(closed_system)
		overlays += "hydrocover"

	//Updated the various alert icons.
	if(draw_warnings)
		if(waterlevel <= 10)
			overlays += "over_lowwater3"
		if(nutrilevel <= 2)
			overlays += "over_lownutri3"
		if(weedlevel >= 5 || pestlevel >= 5 || toxins >= 40)
			overlays += "over_alert3"
		if(harvest)
			overlays += "over_harvest3"

	// Update bioluminescence.
	if(seed)
		if(seed.biolum)
			set_light(floor(seed.potency/10))
			return

	set_light(0)
	return

// If a weed growth is sufficient, this proc is called.
/obj/structure/machinery/portable_atmospherics/hydroponics/proc/weed_invasion()

	//Remove the seed if something is already planted.
	if(seed)
		seed = null
	seed = GLOB.seed_types[pick(list("mushrooms","plumphelmet","harebells","poppies","grass","weeds"))]
	if(!seed)
		return //Weed does not exist, someone fucked up.

	dead = 0
	age = 0
	plant_health = seed.endurance
	lastcycle = world.time
	harvest = 0
	weedlevel = 0
	pestlevel = 0
	sampled = 0
	update_icon()
	visible_message(SPAN_NOTICE("[src] has been overtaken by [seed.display_name]."))

	return

/obj/structure/machinery/portable_atmospherics/hydroponics/proc/mutate(severity)

	// No seed, no mutations.
	if(!seed)
		return

	// Check if we should even bother working on the current seed datum.
	if(LAZYLEN(seed.mutants) && severity > 1)
		mutate_species()
		return

	// We need to make sure we're not modifying one of the global seed datums.
	// If it's not in the global list, then no products of the line have been
	// harvested yet and it's safe to assume it's restricted to this tray.
	if(!isnull(GLOB.seed_types[seed.name]))
		seed = seed.diverge()
	seed.mutate(severity,get_turf(src))

	return

/obj/structure/machinery/portable_atmospherics/hydroponics/proc/check_level_sanity()
	//Make sure various values are sane.
	if(seed)
		plant_health =  max(0,min(seed.endurance,plant_health))
	else
		plant_health = 0
		dead = 0

	mutation_level = max(0,min(mutation_level,100))
	nutrilevel =  max(0,min(nutrilevel,10))
	waterlevel =  max(0,min(waterlevel,100))
	pestlevel =   max(0,min(pestlevel,10))
	weedlevel =   max(0,min(weedlevel,10))
	toxins =  max(0,min(toxins,10))

/obj/structure/machinery/portable_atmospherics/hydroponics/proc/mutate_species()

	var/previous_plant = seed.display_name
	var/newseed = seed.get_mutant_variant()
	if(newseed in GLOB.seed_types)
		seed = GLOB.seed_types[newseed]
	else
		return

	dead = 0
	mutate(1)
	age = 0
	plant_health = seed.endurance
	lastcycle = world.time
	harvest = 0
	weedlevel = 0

	update_icon()
	visible_message(SPAN_DANGER("The \blue [previous_plant] \red has suddenly mutated into \blue [seed.display_name]!"))

	return

/obj/structure/machinery/portable_atmospherics/hydroponics/attackby(obj/item/O as obj, mob/user as mob)

	if (O.is_open_container())
		return 0

	if(HAS_TRAIT(O, TRAIT_TOOL_WIRECUTTERS) || istype(O, /obj/item/tool/surgery/scalpel) || istype(O, /obj/item/tool/kitchen/knife) || istype(O, /obj/item/attachable/bayonet))

		if(!seed)
			to_chat(user, "There is nothing to take a sample from in \the [src].")
			return

		if(sampled)
			to_chat(user, "You have already sampled from this plant.")
			return

		if(dead)
			to_chat(user, "The plant is dead.")
			return

		// Create a sample.
		seed.harvest(user,yield_mod,1)
		plant_health -= (rand(3,5)*10)

		if(prob(30))
			sampled = 1

		// Bookkeeping.
		check_level_sanity()


		return

	else if(istype(O, /obj/item/reagent_container/syringe))

		var/obj/item/reagent_container/syringe/S = O

		if (S.mode == 1)
			if(seed)
				return ..()
			else
				to_chat(user, "There's no plant to inject.")
				return 1
		else
			if(seed)
				//Leaving this in in case we want to extract from plants later.
				to_chat(user, "You can't get any extract out of this plant.")
			else
				to_chat(user, "There's nothing to draw something from.")
			return 1

	else if (istype(O, /obj/item/seeds))

		if(!seed)

			var/obj/item/seeds/S = O
			user.drop_held_item()

			if(!S.seed)
				to_chat(user, "The packet seems to be empty. You throw it away.")
				qdel(O)
				return

			to_chat(user, "You plant the [S.seed.seed_name] [S.seed.seed_noun].")

			if(S.seed.spread == 1)
				msg_admin_attack("[key_name(user)] has planted a creeper packet in [get_area(user)] ([user.loc.x],[user.loc.y],[user.loc.z]).", user.loc.x, user.loc.y, user.loc.z)
				var/obj/effect/plant_controller/creeper/PC = new(get_turf(src))
				if(PC)
					PC.seed = S.seed
			else if(S.seed.spread == 2)
				msg_admin_attack("[key_name(user)] has planted a spreading vine packet in [get_area(user)] ([user.loc.x],[user.loc.y],[user.loc.z]).", user.loc.x, user.loc.y, user.loc.z)
				var/obj/effect/plant_controller/PC = new(get_turf(src))
				if(PC)
					PC.seed = S.seed
			else
				seed = S.seed //Grab the seed datum.
				dead = 0
				age = 1
				//Snowflakey, maybe move this to the seed datum
				plant_health = (istype(S, /obj/item/seeds/cutting) ? floor(seed.endurance/rand(2,5)) : seed.endurance)

				lastcycle = world.time

			qdel(O)

			check_level_sanity()
			update_icon()

		else
			to_chat(user, SPAN_DANGER("\The [src] already has seeds in it!"))

	else if (istype(O, /obj/item/tool/minihoe))  // The minihoe

		if(weedlevel > 0)
			user.visible_message(SPAN_DANGER("[user] starts uprooting the weeds."), SPAN_DANGER("You remove the weeds from [src]."))
			weedlevel = 0
			update_icon()
		else
			to_chat(user, SPAN_DANGER("This plot is completely devoid of weeds. It doesn't need uprooting."))

	else if (istype(O, /obj/item/tool/shovel/spade))
		if(isnull(seed))
			return
		user.visible_message(SPAN_DANGER("[user] starts to uproot the plant."), SPAN_DANGER("You begin removing plant from [src]..."))
		if(!do_after(user, 1 SECONDS, INTERRUPT_NO_NEEDHAND|BEHAVIOR_IMMOBILE, BUSY_ICON_FRIENDLY, src, INTERRUPT_MOVED, BUSY_ICON_FRIENDLY))
			return
		to_chat(user, SPAN_NOTICE("You remove the plant from [src]."))
		seed = null
		dead = 0
		sampled = 0
		age = 0
		harvest = 0
		toxins = 0
		yield_mod = 0
		mutation_mod = 0

		check_level_sanity()
		update_icon()

	else if (istype(O, /obj/item/storage/bag/plants))

		attack_hand(user)

		var/obj/item/storage/bag/plants/S = O
		for (var/obj/item/reagent_container/food/snacks/grown/G in locate(user.x,user.y,user.z))
			if(!S.can_be_inserted(G, user))
				return
			S.handle_item_insertion(G, TRUE, user)

	else if ( istype(O, /obj/item/tool/plantspray) )

		var/obj/item/tool/plantspray/spray = O
		user.drop_held_item()
		toxins += spray.toxicity
		pestlevel -= spray.pest_kill_str
		weedlevel -= spray.weed_kill_str
		to_chat(user, "You spray [src] with [O].")
		playsound(loc, 'sound/effects/spray3.ogg', 25, 1, 3)
		qdel(O)

		check_level_sanity()
		update_icon()

	else if(HAS_TRAIT(O, TRAIT_TOOL_WRENCH))

		//If there's a connector here, the portable_atmospherics setup can handle it.
		if(locate(/obj/structure/pipes/portables_connector) in loc)
			return ..()

		playsound(loc, 'sound/items/Ratchet.ogg', 25, 1)
		anchored = !anchored
		to_chat(user, "You [anchored ? "wrench" : "unwrench"] \the [src].")

/obj/structure/machinery/portable_atmospherics/hydroponics/clicked(mob/user, list/mods)
	if(!mods[ALT_CLICK])
		return ..()

	var/obj/item/held_item = user.get_active_hand()
	if(!held_item)
		user.visible_message(SPAN_NOTICE("[user] runs their hand along \the [src]."))
		return TRUE

	// Check if it's a reagent container
	var/obj/item/reagent_container/RG = held_item
	if(!istype(RG))
		user.visible_message(SPAN_NOTICE("[user] taps \the [held_item] against \the [src]."))
		return TRUE

	if(!RG.is_open_container() || !RG.reagents || RG.reagents.total_volume <= 0)
		user.visible_message(SPAN_WARNING("[user] tries to pour \the [RG] into \the [src], but it's empty or sealed."))
		return TRUE

	var/available_space = reagents.maximum_volume - reagents.total_volume
	if(available_space <= 0)
		user.visible_message(SPAN_WARNING("[user] tries to pour \the [RG] into \the [src], but it's completely full."))
		return TRUE

	var/transfer_amount = min(RG.reagents.total_volume, available_space)
	RG.reagents.trans_to(src, transfer_amount)
	user.visible_message(SPAN_NOTICE("[user] pours \the [RG] into \the [src]."), SPAN_NOTICE("You pour \the [RG] into \the [src]."))

	if(transfer_amount < RG.reagents.total_volume)
		to_chat(user, SPAN_WARNING("The hydroponics tray is full."))

	return TRUE

/obj/structure/machinery/portable_atmospherics/hydroponics/get_examine_text(mob/user)
	. = ..()
	var/hydro_info = show_hydro_info(user)
	if(hydro_info)
		. += hydro_info

/obj/structure/machinery/portable_atmospherics/hydroponics/proc/show_hydro_info(mob/user as mob)
	var/info = ""
	if(seed && !dead)
		info += "[src] has " + SPAN_HELPFUL("[seed.display_name]") +" planted.\n"
		if(plant_health <= (seed.endurance / 2))
			info += "The plant looks " + SPAN_RED("unhealthy") + ".\n"
	else
		info += "[src] is empty.\n"
	info += "Water: [round(waterlevel,0.1)]/100\n"
	info += "Nutrient: [round(nutrilevel,0.1)]/10\n"
	if(weedlevel >= 5)
		info += "[src] is " + SPAN_WARNING("filled with weeds!\n")
	if(pestlevel >= 5)
		info += "[src] is " + SPAN_WARNING("filled with tiny worms!\n")

	return info

/obj/structure/machinery/portable_atmospherics/hydroponics/attack_hand(mob/user as mob)

	if(istype(user, /mob/living/silicon))
		return

	if(harvest)
		harvest(user)
	else if(dead)
		remove_dead(user)
	else
		to_chat(user, show_hydro_info(user))

/obj/structure/machinery/portable_atmospherics/hydroponics/verb/flush() //used to reset the tray
	set name = "Flush Tray"
	set category = "Object"
	set src in view(1)

	if(!usr || usr.stat || usr.is_mob_restrained())
		return
	if (alert(usr, "Are you sure you want to flush the hydroponics tray?", "Flush tray:", "Yes", "No") != "Yes")
		return

	seed = null
	dead = 0
	sampled = 0
	age = 0
	harvest = 0
	toxins = 0
	yield_mod = 0
	mutation_mod = 0
	waterlevel = 0
	nutrilevel = 0
	pestlevel = 0
	weedlevel = 0
	mutation_level = 0

	to_chat(usr, "You flush away everything in the tray.")
	check_level_sanity()
	update_icon()

/obj/structure/machinery/portable_atmospherics/hydroponics/soil
	name = "soil"
	icon = 'icons/obj/structures/machinery/hydroponics.dmi'
	icon_state = "soil"
	density = FALSE
	use_power = USE_POWER_NONE
	draw_warnings = 0

/obj/structure/machinery/portable_atmospherics/hydroponics/soil/attackby(obj/item/O as obj, mob/user as mob)
	if(istype(O, /obj/item/tool/shovel))
		to_chat(user, "You clear up [src]!")
		qdel(src)
	else if(istype(O,/obj/item/tool/shovel) || istype(O,/obj/item/tank))
		return
	else
		. = ..()

#undef HYDRO_SPEED_MULTIPLIER
#undef HYDRO_WATER_CONSUMPTION_MULTIPLIER

/obj/structure/machinery/portable_atmospherics/hydroponics/yautja
	icon_state = "yautja_tray"
