/obj/item/organ/internal/lungs
	name = "lungs"
	icon_state = "lungs"
	parent_organ_zone = BODY_ZONE_CHEST
	slot = INTERNAL_ORGAN_LUNGS
	gender = PLURAL
	w_class = WEIGHT_CLASS_NORMAL

	//Breath damage

	var/safe_oxygen_min = 16 // Minimum safe partial pressure of O2, in kPa
	var/safe_oxygen_max = 0
	var/safe_nitro_min = 0
	var/safe_nitro_max = 0
	var/safe_co2_min = 0
	var/safe_co2_max = 10 // Yes it's an arbitrary value who cares?
	var/safe_toxins_min = 0
	var/safe_toxins_max = 0.05
	var/SA_para_min = 1 //Sleeping agent
	var/SA_sleep_min = 5 //Sleeping agent


	var/oxy_breath_dam_min = MIN_TOXIC_GAS_DAMAGE
	var/oxy_breath_dam_max = MAX_TOXIC_GAS_DAMAGE
	var/oxy_damage_type = OXY
	var/nitro_breath_dam_min = MIN_TOXIC_GAS_DAMAGE
	var/nitro_breath_dam_max = MAX_TOXIC_GAS_DAMAGE
	var/nitro_damage_type = OXY
	var/co2_breath_dam_min = MIN_TOXIC_GAS_DAMAGE
	var/co2_breath_dam_max = MAX_TOXIC_GAS_DAMAGE
	var/co2_damage_type = OXY
	var/tox_breath_dam_min = MIN_TOXIC_GAS_DAMAGE
	var/tox_breath_dam_max = MAX_TOXIC_GAS_DAMAGE
	var/tox_damage_type = TOX

	var/cold_message = "your face freezing and an icicle forming"
	var/cold_level_1_threshold = 260
	var/cold_level_2_threshold = 200
	var/cold_level_3_threshold = 120
	var/cold_level_1_damage = COLD_GAS_DAMAGE_LEVEL_1 //Keep in mind with gas damage levels, you can set these to be negative, if you want someone to heal, instead.
	var/cold_level_2_damage = COLD_GAS_DAMAGE_LEVEL_2
	var/cold_level_3_damage = COLD_GAS_DAMAGE_LEVEL_3
	var/cold_damage_types = list(BURN = 1)

	var/hot_message = "your face burning and a searing heat"
	var/heat_level_1_threshold = 360
	var/heat_level_2_threshold = 400
	var/heat_level_3_threshold = 1000
	var/heat_level_1_damage = HEAT_GAS_DAMAGE_LEVEL_1
	var/heat_level_2_damage = HEAT_GAS_DAMAGE_LEVEL_2
	var/heat_level_3_damage = HEAT_GAS_DAMAGE_LEVEL_3
	var/heat_damage_types = list(BURN = 1)

/obj/item/organ/internal/lungs/emp_act()
	if(!is_robotic() || emp_proof)
		return
	if(owner)
		owner.LoseBreath(40 SECONDS)

/obj/item/organ/internal/lungs/insert(mob/living/carbon/target, special = ORGAN_MANIPULATION_DEFAULT)
	..()
	for(var/thing in list("oxy", "tox", "co2", "nitro"))
		target.clear_alert("not_enough_[thing]")
		target.clear_alert("too_much_[thing]")

/obj/item/organ/internal/lungs/remove(mob/living/carbon/M, special = ORGAN_MANIPULATION_DEFAULT)
	for(var/thing in list("oxy", "tox", "co2", "nitro"))
		M.clear_alert("not_enough_[thing]")
		M.clear_alert("too_much_[thing]")
	return ..()

/obj/item/organ/internal/lungs/on_life()
	if(germ_level > INFECTION_LEVEL_ONE)
		if(prob(5))
			owner.emote("cough")		//respitory tract infection

	if(is_bruised())
		if(prob(2))
			owner.custom_emote(EMOTE_AUDIBLE, "откашлива%(ет,ют)% большое количество крови!")
			owner.bleed(1)
		if(prob(4))
			owner.custom_emote(EMOTE_VISIBLE, "задыха%(ет,ют)%ся!")
			owner.AdjustLoseBreath(10 SECONDS)


/obj/item/organ/internal/lungs/proc/check_breath(datum/gas_mixture/breath, mob/living/carbon/human/H)
	if((H.status_flags & GODMODE) || HAS_TRAIT(H, TRAIT_NO_BREATH))
		return

	if(!breath || (breath.total_moles() == 0))
		if(isspaceturf(H.loc))
			H.adjustOxyLoss(10)
		else
			H.adjustOxyLoss(5)

		if(safe_oxygen_min)
			H.throw_alert(ALERT_NOT_ENOUGH_OXYGEN, /atom/movable/screen/alert/not_enough_oxy)
		else if(safe_toxins_min)
			H.throw_alert(ALERT_NOT_ENOUGH_TOX, /atom/movable/screen/alert/not_enough_tox)
		else if(safe_co2_min)
			H.throw_alert(ALERT_NOT_ENOUGH_CO2, /atom/movable/screen/alert/not_enough_co2)
		else if(safe_nitro_min)
			H.throw_alert(ALERT_NOT_ENOUGH_NITRO, /atom/movable/screen/alert/not_enough_nitro)
		return FALSE


	if(H.health < HEALTH_THRESHOLD_CRIT)
		return FALSE

	var/gas_breathed = 0

	//Partial pressures in our breath
	var/O2_pp = breath.get_breath_partial_pressure(breath.oxygen)
	var/N2_pp = breath.get_breath_partial_pressure(breath.nitrogen)
	var/Toxins_pp = breath.get_breath_partial_pressure(breath.toxins)
	var/CO2_pp = breath.get_breath_partial_pressure(breath.carbon_dioxide)
	var/SA_pp = breath.get_breath_partial_pressure(breath.sleeping_agent)


	//-- OXY --//

	//Too much oxygen! //Yes, some species may not like it.
	if(safe_oxygen_max)
		if(O2_pp > safe_oxygen_max)
			var/ratio = (breath.oxygen / safe_oxygen_max / safe_oxygen_max) * 10
			H.apply_damage(clamp(ratio, oxy_breath_dam_min, oxy_breath_dam_max), oxy_damage_type, spread_damage = TRUE, forced = TRUE)
			H.throw_alert(ALERT_TOO_MUCH_OXYGEN, /atom/movable/screen/alert/too_much_oxy)
		else
			H.clear_alert(ALERT_TOO_MUCH_OXYGEN)

	//Too little oxygen!
	if(safe_oxygen_min)
		if(O2_pp < safe_oxygen_min)
			gas_breathed = handle_too_little_breath(H, O2_pp, safe_oxygen_min, breath.oxygen)
			H.throw_alert(ALERT_NOT_ENOUGH_OXYGEN, /atom/movable/screen/alert/not_enough_oxy)
		else
			H.heal_damage_type(HUMAN_MAX_OXYLOSS, OXY)
			gas_breathed = breath.oxygen
			H.clear_alert(ALERT_NOT_ENOUGH_OXYGEN)

	//Exhale
	breath.oxygen -= gas_breathed
	breath.carbon_dioxide += gas_breathed
	gas_breathed = 0

	//-- Nitrogen --//

	//Too much nitrogen!
	if(safe_nitro_max)
		if(N2_pp > safe_nitro_max)
			var/ratio = (breath.nitrogen / safe_nitro_max) * 10
			H.apply_damage(clamp(ratio, nitro_breath_dam_min, nitro_breath_dam_max), nitro_damage_type, spread_damage = TRUE, forced = TRUE)
			H.throw_alert(ALERT_TOO_MUCH_NITRO, /atom/movable/screen/alert/too_much_nitro)
		else
			H.clear_alert(ALERT_TOO_MUCH_NITRO)

	//Too little nitrogen!
	if(safe_nitro_min)
		if(N2_pp < safe_nitro_min)
			gas_breathed = handle_too_little_breath(H, N2_pp, safe_nitro_min, breath.nitrogen)
			H.throw_alert(ALERT_NOT_ENOUGH_NITRO, /atom/movable/screen/alert/not_enough_nitro)
		else
			H.heal_damage_type(HUMAN_MAX_OXYLOSS, OXY)
			gas_breathed = breath.nitrogen
			H.clear_alert(ALERT_NOT_ENOUGH_NITRO)

	//Exhale
	breath.nitrogen -= gas_breathed
	breath.carbon_dioxide += gas_breathed
	gas_breathed = 0

	//-- CO2 --//

	//CO2 does not affect failed_last_breath. So if there was enough oxygen in the air but too much co2, this will hurt you, but only once per 4 ticks, instead of once per tick.
	if(safe_co2_max)
		if(CO2_pp > safe_co2_max)
			if(!H.co2overloadtime) // If it's the first breath with too much CO2 in it, lets start a counter, then have them pass out after 12s or so.
				H.co2overloadtime = world.time
			else if(world.time - H.co2overloadtime > 120)
				H.Paralyse(6 SECONDS)
				H.apply_damage(HUMAN_MAX_OXYLOSS, co2_damage_type, spread_damage = TRUE, forced = TRUE) // Lets hurt em a little, let them know we mean business
				if(world.time - H.co2overloadtime > 300) // They've been in here 30s now, lets start to kill them for their own good!
					H.apply_damage(15, co2_damage_type, spread_damage = TRUE, forced = TRUE)
				H.throw_alert(ALERT_TOO_MUCH_CO2, /atom/movable/screen/alert/too_much_co2)
			if(prob(20)) // Lets give them some chance to know somethings not right though I guess.
				H.emote("cough")

		else
			H.co2overloadtime = 0
			H.clear_alert(ALERT_TOO_MUCH_CO2)

	//Too little CO2!
	if(safe_co2_min)
		if(CO2_pp < safe_co2_min)
			gas_breathed = handle_too_little_breath(H, CO2_pp, safe_co2_min, breath.carbon_dioxide)
			H.throw_alert(ALERT_NOT_ENOUGH_CO2, /atom/movable/screen/alert/not_enough_co2)
		else
			H.adjustOxyLoss(-HUMAN_MAX_OXYLOSS)
			gas_breathed = breath.carbon_dioxide
			H.clear_alert(ALERT_NOT_ENOUGH_CO2)

	//Exhale
	breath.carbon_dioxide -= gas_breathed
	breath.oxygen += gas_breathed
	gas_breathed = 0


	//-- TOX --//

	//Too much toxins!
	if(safe_toxins_max)
		if(Toxins_pp > safe_toxins_max)
			var/ratio = (breath.toxins / safe_toxins_max) * 10
			H.apply_damage(clamp(ratio, tox_breath_dam_min, tox_breath_dam_max), tox_damage_type, spread_damage = TRUE, forced = TRUE)
			H.throw_alert(ALERT_TOO_MUCH_TOX, /atom/movable/screen/alert/too_much_tox)
		else
			H.clear_alert(ALERT_TOO_MUCH_TOX)


	//Too little toxins!
	if(safe_toxins_min)
		if(Toxins_pp < safe_toxins_min)
			gas_breathed = handle_too_little_breath(H, Toxins_pp, safe_toxins_min, breath.toxins)
			H.throw_alert(ALERT_NOT_ENOUGH_TOX, /atom/movable/screen/alert/not_enough_tox)
		else
			H.heal_damage_type(HUMAN_MAX_OXYLOSS, OXY)
			gas_breathed = breath.toxins
			H.clear_alert(ALERT_NOT_ENOUGH_TOX)

	//Exhale
	breath.toxins -= gas_breathed
	breath.carbon_dioxide += gas_breathed
	gas_breathed = 0


	//-- TRACES --//

	if(breath.sleeping_agent)	// If there's some other shit in the air lets deal with it here.
		if(SA_pp > SA_para_min)
			H.Paralyse(6 SECONDS) // 6 seconds gives them one second to wake up and run away a bit!
			if(SA_pp > SA_sleep_min) // Enough to make us sleep as well
				H.AdjustSleeping(16 SECONDS, bound_lower = 0, bound_upper = 20 SECONDS)
		else if(SA_pp > 0.3)	// There is sleeping gas in their lungs, but only a little, so give them a bit of a warning
			if(prob(20))
				H.emote(pick("giggle", "laugh"))

	handle_breath_temperature(breath, H)

	return TRUE


/obj/item/organ/internal/lungs/proc/handle_too_little_breath(mob/living/carbon/human/H = null, breath_pp = 0, safe_breath_min = 0, true_pp = 0)
	. = 0
	if(!H || !safe_breath_min) //the other args are either: Ok being 0 or Specifically handled.
		return FALSE

	if(prob(20))
		H.emote("gasp")
	if(breath_pp > 0)
		var/ratio = safe_breath_min/breath_pp
		H.adjustOxyLoss(min(5*ratio, HUMAN_MAX_OXYLOSS)) // Don't fuck them up too fast (space only does HUMAN_MAX_OXYLOSS after all!
		. = true_pp*ratio/6
	else
		H.adjustOxyLoss(HUMAN_MAX_OXYLOSS)


/obj/item/organ/internal/lungs/proc/handle_breath_temperature(datum/gas_mixture/breath, mob/living/carbon/human/H) // called by human/life, handles temperatures
	var/breath_temperature = breath.temperature

	if(!HAS_TRAIT(H, TRAIT_RESIST_COLD)) // COLD DAMAGE
		var/CM = abs(H.dna.species.coldmod * H.physiology.cold_mod)
		var/TC = 0
		if(breath_temperature < cold_level_3_threshold)
			TC = cold_level_3_damage
		if(breath_temperature > cold_level_3_threshold && breath_temperature < cold_level_2_threshold)
			TC = cold_level_2_damage
		if(breath_temperature > cold_level_2_threshold && breath_temperature < cold_level_1_threshold)
			TC = cold_level_1_damage
		if(TC)
			for(var/D in cold_damage_types)
				H.apply_damage(TC * CM * cold_damage_types[D], D, spread_damage = TRUE, forced = TRUE)
		if(breath_temperature < cold_level_1_threshold)
			if(prob(20))
				to_chat(H, span_warning("You feel [cold_message] in your [name]!"))

	if(!HAS_TRAIT(H, TRAIT_RESIST_HEAT)) // HEAT DAMAGE
		var/HM = abs(H.dna.species.heatmod * H.physiology.heat_mod)
		var/TH = 0
		if(breath_temperature > heat_level_1_threshold && breath_temperature < heat_level_2_threshold)
			TH = heat_level_1_damage
		if(breath_temperature > heat_level_2_threshold && breath_temperature < heat_level_3_threshold)
			TH = heat_level_2_damage
		if(breath_temperature > heat_level_3_threshold)
			TH = heat_level_3_damage
		if(TH)
			for(var/D in heat_damage_types)
				H.apply_damage(TH * HM * heat_damage_types[D], D, spread_damage = TRUE, forced = TRUE)
		if(breath_temperature > heat_level_1_threshold)
			if(prob(20))
				to_chat(H, span_warning("You feel [hot_message] in your [name]!"))

/obj/item/organ/internal/lungs/prepare_eat()
	var/obj/S = ..()
	S.reagents.add_reagent("salbutamol", 5)
	return S

/obj/item/organ/internal/lungs/plasmaman
	name = "plasma filter"
	desc = "A spongy rib-shaped mass for filtering plasma from the air."
	icon = 'icons/obj/species_organs/plasmaman.dmi'
	icon_state = "lungs"

	safe_oxygen_min = 0 //We don't breath this
	safe_toxins_min = 16 //We breathe THIS!
	safe_toxins_max = 0

/obj/item/organ/internal/lungs/vox
	name = "Vox lungs"
	desc = "They're filled with dust....wow."
	icon = 'icons/obj/species_organs/vox.dmi'
	icon_state = "lungs"

	safe_oxygen_min = 0 //We don't breathe this
	safe_oxygen_max = 0.05 //This is toxic to us
	safe_nitro_min = 16 //We breathe THIS!
	oxy_damage_type = TOX //And it poisons us

/obj/item/organ/internal/lungs/drask
	icon = 'icons/obj/species_organs/drask.dmi'

	cold_message = "an invigorating coldness"
	cold_level_1_damage = -COLD_GAS_DAMAGE_LEVEL_1 //They heal when the air is cold
	cold_level_2_damage = -COLD_GAS_DAMAGE_LEVEL_2
	cold_level_3_damage = -COLD_GAS_DAMAGE_LEVEL_3
	cold_damage_types = list(BRUTE = 0.5, BURN = 0.25)

/obj/item/organ/internal/lungs/cybernetic
	name = "cybernetic lungs"
	desc = "A cybernetic version of the lungs found in traditional humanoid entities. It functions the same as an organic lung and is merely meant as a replacement."
	icon_state = "lungs-c"
	origin_tech = "biotech=4"
	status = ORGAN_ROBOT
	var/species_state = "human"
	pickup_sound = 'sound/items/handling/component_pickup.ogg'
	drop_sound = 'sound/items/handling/component_drop.ogg'

/obj/item/organ/internal/lungs/cybernetic/examine(mob/user)
	. = ..()
	. += span_notice("[src] is configured for [species_state] standards of atmosphere.")

/obj/item/organ/internal/lungs/cybernetic/multitool_act(mob/user, obj/item/I)
	. = TRUE
	if(!I.use_tool(src, user, 0, volume = I.tool_volume))
		return
	switch(species_state)
		if("human") // from human to vox
			safe_oxygen_min = 0
			safe_oxygen_max = safe_toxins_max
			safe_nitro_min = 16
			oxy_damage_type = TOX
			to_chat(user, span_notice("You configure [src] to replace vox lungs."))
			species_state = "vox"
		if("vox") // from vox to plasmamen
			safe_oxygen_max = initial(safe_oxygen_max)
			safe_toxins_min = 16
			safe_toxins_max = 0
			safe_nitro_min = initial(safe_nitro_min)
			oxy_damage_type = OXY
			to_chat(user, span_notice("You configure [src] to replace plasmamen lungs."))
			species_state = "plasmamen"
		if("plasmamen") // from plasmamen to human
			safe_oxygen_min = initial(safe_oxygen_min)
			safe_toxins_min = initial(safe_toxins_min)
			safe_toxins_max = initial(safe_toxins_max)
			to_chat(user, span_notice("You configure [src] back to default settings."))
			species_state = "human"

/obj/item/organ/internal/lungs/cybernetic/upgraded
	name = "upgraded cybernetic lungs"
	desc = "A more advanced version of the stock cybernetic lungs. They are capable of filtering out lower levels of toxins and carbon dioxide."
	icon_state = "lungs-c-u"
	origin_tech = "biotech=5"

	safe_toxins_max = 20
	safe_co2_max = 20

	cold_level_1_threshold = 200
	cold_level_2_threshold = 140
	cold_level_3_threshold = 100
