/obj/item/weapon/gun/energy
	name = "energy gun"
	desc = "A basic energy-based gun."
	icon_state = "energy"
	fire_sound = 'sound/weapons/Taser.ogg'
	fire_sound_text = "laser blast"

	hud_bullet_usebar = 1

	var/obj/item/weapon/cell/power_supply //What type of power cell this uses
	var/charge_cost = 20 //How much energy is needed to fire.
	var/max_shots = 10 //Determines the capacity of the weapon's power cell. Specifying a cell_type overrides this value.
	var/cell_type = null
	var/projectile_type = /obj/item/projectile/beam/practice
	var/modifystate
	var/charge_meter = 1	//if set, the icon state will be chosen based on the current charge

	//self-recharging
	var/self_recharge = 0	//if set, the weapon will recharge itself
	var/use_external_power = 0 //if set, the weapon will look for an external power source to draw from, otherwise it recharges magically
	var/recharge_time = 4
	var/charge_tick = 0
	var/alt_charge_method = 0 //If set, we use an alternate charging method and disallow wallcharging (cov guns)

/obj/item/weapon/gun/energy/switch_firemodes()
	. = ..()
	if(.)
		update_icon()

/obj/item/weapon/gun/energy/emp_act(severity)
	return //Let's not make the weapons lose all of their power on EMP. They're military grade, they should be vaguely hardened.

/obj/item/weapon/gun/energy/New()
	..()
	if(cell_type)
		power_supply = new cell_type(src)
	else
		power_supply = new /obj/item/weapon/cell/device/variable(src, max_shots*charge_cost)
	if(self_recharge)
		GLOB.processing_objects.Add(src)
	update_icon()

/obj/item/weapon/gun/energy/Destroy()
	if(self_recharge)
		GLOB.processing_objects.Remove(src)
	return ..()

/obj/item/weapon/gun/energy/process()
	. = PROCESS_KILL
	. = ..()
	if(self_recharge)
		. = process_self_recharge()
	return .

/obj/item/weapon/gun/energy/proc/process_self_recharge()
	if(self_recharge) //Every [recharge_time] ticks, recharge a shot for the cyborg
		charge_tick++
		if(charge_tick < recharge_time) return 0
		charge_tick = 0

		if(!power_supply || power_supply.charge >= power_supply.maxcharge)
			return 0 // check if we actually need to recharge

		if(use_external_power)
			var/obj/item/weapon/cell/external = get_external_power_supply()
			if(!external || !external.use(charge_cost)) //Take power from the borg...
				return 0

		power_supply.give(charge_cost) //... to recharge the shot
		update_icon()
		return 1

/obj/item/weapon/gun/energy/consume_next_projectile()
	if(!power_supply) return null
	if(!ispath(projectile_type)) return null
	if(!power_supply.checked_use(charge_cost)) return null
	if(self_recharge)
		GLOB.processing_objects.Add(src)
	return new projectile_type(src)

/obj/item/weapon/gun/energy/proc/get_external_power_supply()
	if(isrobot(src.loc))
		var/mob/living/silicon/robot/R = src.loc
		return R.cell
	if(istype(src.loc, /obj/item/rig_module))
		var/obj/item/rig_module/module = src.loc
		if(module.holder && module.holder.wearer)
			var/mob/living/carbon/human/H = module.holder.wearer
			if(istype(H) && H.back)
				var/obj/item/weapon/rig/suit = H.back
				if(istype(suit))
					return suit.cell
	return null

/obj/item/weapon/gun/energy/examine(mob/user)
	. = ..(user)
	var/extra_desc
	if(power_supply)
		extra_desc = "It has [round(100 * power_supply.charge / power_supply.maxcharge)]% charge left \
			([power_supply.charge/charge_cost]/[power_supply.maxcharge/charge_cost] shots)."
	else if(cell_type)
		var/obj/item/weapon/cell/P = cell_type
		extra_desc = "Accepts [initial(P.name)], but none are currently inserted."

	if(extra_desc)
		to_chat(user, extra_desc)

/obj/item/weapon/gun/energy/update_icon()
	..()
	if(charge_meter)
		var/ratio = power_supply.percent()

		//make sure that rounding down will not give us the empty state even if we have charge for a shot left.
		if(power_supply.charge < charge_cost)
			ratio = 0
		else
			ratio = max(round(ratio, 25), 25)

		if(modifystate)
			icon_state = "[modifystate][ratio]"
		else
			icon_state = "[initial(icon_state)][ratio]"
			
/obj/item/weapon/gun/energy/ammo_check()
	
	if(!power_supply || power_supply.charge < 1)  //If we have no power supply or it does not have enough charge to fire it fails the check
		return 0
	else 
		return 1

