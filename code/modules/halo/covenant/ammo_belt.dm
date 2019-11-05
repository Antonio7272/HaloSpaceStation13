
/obj/item/weapon/storage/belt/covenant_ammo
	name = "Covenant martial belt"
	desc = "A belt with many various pouches to hold ammunition and weaponry"
	icon = 'tools.dmi'
	item_state = "securitybelt"
	color = "#ff99ff"
	sprite_sheets = list(
		"Tvaoan Kig-Yar" = null,\
		"Sangheili" = null\
		)

	can_hold = list(/obj/item/ammo_magazine,\
		/obj/item/ammo_box,\
		/obj/item/ammo_casing,\
		/obj/item/weapon/grenade,\
		/obj/item/weapon/melee/energy/elite_sword,\
		/obj/item/clothing/gloves/shield_gauntlet)

/obj/item/clothing/accessory/storage/bandolier/covenant
	name = "Covenant Bandolier"
	desc = "A lightweight synthetic bandolier made by the covenant to carry small items"
	icon = 'tools.dmi'
	icon_state = "covbandolier"

/obj/item/clothing/accessory/storage/bandolier/covenant/New()
	..()
	hold.can_hold = list(
		/obj/item/ammo_casing,
		/obj/item/weapon/material/hatchet/tacknife,
		/obj/item/weapon/material/kitchen/utensil/knife,
		/obj/item/weapon/material/knife,
		/obj/item/weapon/material/star,
		/obj/item/weapon/rcd_ammo,
		/obj/item/weapon/reagent_containers/syringe,
		/obj/item/weapon/reagent_containers/hypospray,
		/obj/item/weapon/reagent_containers/hypospray/autoinjector,
		/obj/item/weapon/syringe_cartridge,
		/obj/item/weapon/plastique,
		/obj/item/clothing/mask/smokable,
		/obj/item/weapon/screwdriver,
		/obj/item/device/multitool,
		/obj/item/weapon/magnetic_ammo,
		/obj/item/ammo_magazine
	)

//Exactly the same as the human variant, but cannont hold Grenades. This may be changed once plasma grenades are less insta-kill.