
/obj/effect/overmap/sector/taurus
	name = "Taurus Colony"
	icon = 'ks7_sector_icon.dmi'
	icon_state = "ice"

	faction = "Human Civilian"
	base = 1
	block_slipspace = 1

	map_bounds = list(1,150,150,1) //Format: (TOP_LEFT_X,TOP_LEFT_Y,BOTTOM_RIGHT_X,BOTTOM_RIGHT_Y)

	overmap_spawn_near_me = list()
	overmap_spawn_in_me = list()
	parent_area_type = /area/planets/taurus

/obj/effect/overmap/sector/taurus/CanUntargetedBombard(var/obj/console_from)
	console_from.visible_message("<span class = 'notice'>Post firing scan reveals shot telemetry was scrambled by hostile devices. Direct laser designation will be required.</span>")
	return 0
