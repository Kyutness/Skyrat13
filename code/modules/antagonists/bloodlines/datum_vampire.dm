
/datum/antagonist/vampire
	name = "Vampire"
	roundend_category = "bloodline vampire"
	antagpanel_category = "Bloodline Vampire"
	job_rank = ROLE_BLOODLINE_VAMPIRE
	threat = 5

	var/gift_points = 12
	var/bloodlines = list() //What bloodlines do we have available?
	var/vampire_clan //To which clan do we belong?
	var/power = 35
	var/max_power = 100
	var/max_blood_volume = 600
	var/static/list/defaultTraits = list(TRAIT_STABLEHEART, TRAIT_NOCRITDAMAGE, TRAIT_RESISTCOLD, TRAIT_RADIMMUNE, TRAIT_NIGHT_VISION, \
										      TRAIT_NOMARROW, TRAIT_VIRUSIMMUNE, TRAIT_NOSOFTCRIT)

	var/had_toxlover

	var/list/powers = list() //all powers we've gained from being a vampire

	var/static/list/all_powers = typecacheof(/datum/action/vampire,TRUE)
	var/datum/vampiric_gifts/vampiric_gifts
	var/datum/action/innate/vampiric_gifts/vampiric_gifts_action

/datum/antagonist/vampire/on_gain()
	. = ..()
	SSticker.mode.vampires |= owner
	vampiric_gifts = new(src)
	vampiric_gifts_action = new(vampiric_gifts)
	vampiric_gifts_action.Grant(owner.current)
	bloodlines += /datum/bloodline/brujah
	AssignStarterPowersAndStats()// Give Powers & Stats

/datum/antagonist/vampire/on_removal()
	SSticker.mode.vampires -= owner
	QDEL_NULL(vampiric_gifts)
	QDEL_NULL(vampiric_gifts_action)
	ClearAllPowersAndStats()// Clear Powers & Stats
	. = ..()

/datum/antagonist/vampire/proc/GainBloodlinesFromClan(var/datum/vampire_clan/VampClan)
	for(var/path in VampClan.bloodlines)
		bloodlines |= path

/datum/antagonist/vampire/proc/AddBloodVolume(value)
	owner.current.blood_volume = clamp(owner.current.blood_volume + value, 0, max_blood_volume)
	update_hud()

/datum/antagonist/vampire/proc/BloodlinePermitsPurchase(ability_typepath)
	var/datum/action/vampire/abil = ability_typepath
	if(!abil.purchasable)
		return FALSE
	for(var/datum/bloodline/Bld in bloodlines)
		for(var/datum/discipline/disci in Bld.disciplines)
			if(ability_typepath in disci)
				return TRUE
	return FALSE


/datum/antagonist/vampire/proc/AddPower(pwr)
	power += pwr
	if(power > max_power)
		power = max_power
	else if (power < 0)
		power = 0
	update_hud()

/datum/antagonist/vampire/proc/ClearAllPowersAndStats()
	// Blood/Rank Counter
	remove_hud()
	// Powers
	while(powers.len)
		var/datum/action/bloodsucker/power = pick(powers)
		powers -= power
		power.Remove(owner.current)
		// owner.RemoveSpell(power)
	// Traits
	for(var/T in defaultTraits)
		REMOVE_TRAIT(owner.current, T, BLOODSUCKER_TRAIT)
	if(had_toxlover)
		ADD_TRAIT(owner.current, TRAIT_TOXINLOVER, SPECIES_TRAIT)

	// Traits: Species
	if(ishuman(owner.current))
		var/mob/living/carbon/human/H = owner.current
		H.set_species(H.dna.species.type)
	// Stats
	if(ishuman(owner.current))
		var/mob/living/carbon/human/H = owner.current
		var/datum/species/S = H.dna.species
		// Make Changes
		H.physiology.brute_mod *= 1.25
		H.physiology.cold_mod = 1
		H.physiology.stun_mod *= 2 //Not like this matters in stam combat
		H.physiology.siemens_coeff *= 1.25 	//base electrocution coefficient  1
		S.punchdamagelow -= 1       //lowest possible punch damage   0
		S.punchdamagehigh -= 1      //highest possible punch damage	 9
		// Clown
		if(istype(H) && owner.assigned_role == "Clown")
			H.dna.add_mutation(CLOWNMUT)

	// Language
	owner.current.remove_language(/datum/language/vampiric, TRUE, TRUE, LANGUAGE_BLOODSUCKER)
	// Soul
	if (owner.soulOwner == owner) // Return soul, if *I* own it.
		owner.hasSoul = TRUE

/datum/antagonist/vampire/proc/GainPowerAbility(datum/action/vampire/power) //(obj/effect/proc_holder/spell/power)
	powers += power
	power.Grant(owner.current)// owner.AddSpell(power)

/datum/antagonist/vampire/proc/AttemptPurchasePowerAbility(ability_typepath)
	var/datum/action/vampire/target_ability = ability_typepath
	if(!target_ability)
		return
	var/upgrading = FALSE
	var/datum/action/vampire/upgraded_ability
	for(var/datum/action/vampire/P in powers)
		if(initial(target_ability.name) == P.name)
			message_admins("breaking loop")
			upgrading = TRUE
			upgraded_ability = P
			break
	if(upgrading && upgraded_ability.level_current == upgraded_ability.level_max)
		return
	var/cost = initial(target_ability.gift_cost)
	if(cost <= gift_points)
		message_admins("[upgrading]")
		if(upgraded_ability)
			message_admins("upgraded: [upgraded_ability]")
		message_admins("[cost]")
		message_admins("[gift_points]")
		gift_points -= cost
		message_admins("[gift_points]")
		if(upgrading)
			upgraded_ability.level_current += 1
		else
			GainPowerAbility(new target_ability)

/datum/antagonist/vampire/proc/AssignStarterPowersAndStats()
	// Blood/Rank Counter
	//add_hud()
	//update_hud(TRUE) 	// Set blood value, current rank
	// Powers
	GainPowerAbility(new /datum/action/vampire/vitality)
	GainPowerAbility(new /datum/action/vampire/stamina)
	//BuyPower(new /datum/action/vampire/masquerade)
	//BuyPower(new /datum/action/vampire/veil)
	

	// Traits
	for(var/T in defaultTraits)
		ADD_TRAIT(owner.current, T, VAMPIRE_TRAIT)
	/*
	if(HAS_TRAIT(owner.current, TRAIT_TOXINLOVER)) //No slime bonuses here, no thank you
		had_toxlover = TRUE
		REMOVE_TRAIT(owner.current, TRAIT_TOXINLOVER, SPECIES_TRAIT)
	*/
	// Traits: Species
	if(ishuman(owner.current))
		var/mob/living/carbon/human/H = owner.current
		var/datum/species/S = H.dna.species
		S.species_traits |= DRINKSBLOOD
	// Clear Addictions
	owner.current.reagents.addiction_list = list() // Start over from scratch. Lucky you! At least you're not addicted to blood anymore (if you were)
	// Stats
	if(ishuman(owner.current))
		var/mob/living/carbon/human/H = owner.current
		var/datum/species/S = H.dna.species
		// Make Changes
		H.physiology.brute_mod *= 0.8
		H.physiology.cold_mod = 0
		H.physiology.stun_mod *= 0.5 //Not like this matters in stam combat
		H.physiology.siemens_coeff *= 0.8 	//base electrocution coefficient  1
		S.punchdamagelow += 1       //lowest possible punch damage   0
		S.punchdamagehigh += 1      //highest possible punch damage	 9
		if(istype(H) && owner.assigned_role == "Clown")
			H.dna.remove_mutation(CLOWNMUT)
			to_chat(H, "As a vampiric clown, you are no longer a danger to yourself. Your nature is subdued.")
	// Language
	owner.current.grant_language(/datum/language/vampiric, TRUE, TRUE, LANGUAGE_BLOODSUCKER)
	owner.hasSoul = FALSE 		// If false, renders the character unable to sell their soul.
	owner.isholy = FALSE 		// is this person a chaplain or admin role allowed to use bibles
	// Disabilities
	CureDisabilities()
	update_hud()

/datum/antagonist/vampire/proc/CureDisabilities()
	var/mob/living/carbon/C = owner.current
	C.cure_blind(list(EYE_DAMAGE))//()
	C.cure_nearsighted(EYE_DAMAGE)
	C.set_blindness(0) 	// Added 9/2/19
	C.set_blurriness(0) // Added 9/2/19
	C.update_tint() 	// Added 9/2/19
	C.update_sight() 	// Added 9/2/19
	for(var/O in C.internal_organs) //owner.current.adjust_eye_damage(-100)  // This was removed by TG
		var/obj/item/organ/organ = O
		organ.setOrganDamage(0)
	owner.current.cure_husk()

/datum/antagonist/vampire/proc/remove_hud()
	// No Hud? Get out.
	if (!owner.current.hud_used)
		return
	owner.current.hud_used.vamp_blood_display.invisibility = INVISIBILITY_ABSTRACT
	owner.current.hud_used.vamp_power_display.invisibility = INVISIBILITY_ABSTRACT

/datum/antagonist/vampire/proc/update_hud()
	// No Hud? Get out.
	if(!owner.current.hud_used)
		return
	// Update Blood Counter
	if (owner.current.hud_used.vamp_blood_display)
		var/valuecolor = "#FF6666"
		if(owner.current.blood_volume > BLOOD_VOLUME_SAFE)
			valuecolor =  "#FFDDDD"
		else if(owner.current.blood_volume > BLOOD_VOLUME_BAD)
			valuecolor =  "#FFAAAA"
		var/new_state =  round((owner.current.blood_volume / (BLOOD_VOLUME_NORMAL * owner.current.blood_ratio))*10, 1)
		if(new_state > 10)
			new_state = 10
		else if (new_state < 0)
			new_state = 0
		owner.current.hud_used.vamp_blood_display.update_counter(owner.current.blood_volume, valuecolor, new_state)

	if (owner.current.hud_used.vamp_power_display)
		var/new_state = round((power/10), 1)
		if(new_state > 10)
			new_state = 10
		else if (new_state < 0)
			new_state = 0
		owner.current.hud_used.vamp_power_display.update_counter(power, "#FFDD9E", new_state)

/datum/hud
	var/obj/screen/vampire/blood_counter/vamp_blood_display
	var/obj/screen/vampire/power_counter/vamp_power_display

/obj/screen/vampire
	invisibility = INVISIBILITY_ABSTRACT
	var/base_icon

/obj/screen/vampire/Initialize()
	base_icon = icon_state

/obj/screen/vampire/proc/clear()
	invisibility = INVISIBILITY_ABSTRACT

/obj/screen/vampire/proc/update_counter(value, valuecolor)
	invisibility = 0

/obj/screen/vampire/blood_counter
	icon = 'modular_skyrat/icons/mob/actions/vampire_ui.dmi'
	name = "Blood Consumed"
	icon_state = "blood_display"
	screen_loc = "WEST:6,CENTER-2:0"

/obj/screen/vampire/blood_counter/update_counter(value, valuecolor, new_state)
	..()
	maptext = "<div class='statusDisplay' align='center' valign='middle' style='position:relative; top:0px; left:6px'><font color='[valuecolor]'>[round(value,1)]</font></div>"
	icon_state = "[base_icon][new_state]"

/obj/screen/vampire/power_counter
	icon = 'modular_skyrat/icons/mob/actions/vampire_ui.dmi'
	name = "Power Collected"
	icon_state = "power_display"
	screen_loc = "WEST:6,CENTER-1:0"

/obj/screen/vampire/power_counter/update_counter(value, valuecolor, new_state)
	..()
	maptext = "<div class='statusDisplay' align='center' valign='middle' style='position:relative; top:0px; left:6px'><font color='[valuecolor]'>[round(value,1)]</font></div>"
	icon_state = "[base_icon][new_state]"