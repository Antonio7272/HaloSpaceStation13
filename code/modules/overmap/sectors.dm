//===================================================================================
//Overmap object representing zlevel(s)
//===================================================================================
GLOBAL_LIST_EMPTY(overmap_tiles_uncontrolled) //This is any overmap sectors that are uncontrolled by any faction

GLOBAL_LIST_EMPTY(overmap_spawn_near)
GLOBAL_LIST_EMPTY(overmap_spawn_in)

var/list/points_of_interest = list()

/obj/effect/overmap
	name = "map object"
	icon = 'icons/obj/overmap.dmi'
	icon_state = "object"
	dir = 1
	ai_access_level = 0
	var/list/map_z = list()
	var/list/map_z_data = list()
	var/list/targeting_locations = list() // Format: "location" = list(TOP_LEFT_X,TOP_LEFT_Y,BOTTOM_RIGHT_X,BOTTOM_RIGHT_Y)
	var/list/active_effects = list()
	var/weapon_miss_chance = 0

	//This is a list used by overmap projectiles to ensure they actually hit somewhere on the ship. This should be set so projectiles can narrowly miss, but not miss by much.
	var/list/map_bounds = list(1,255,255,1) //Format: (TOP_LEFT_X,TOP_LEFT_Y,BOTTOM_RIGHT_X,BOTTOM_RIGHT_Y)

	var/list/generic_waypoints = list()    //waypoints that any shuttle can use
	var/list/restricted_waypoints = list() //waypoints for specific shuttles

	var/start_x			//coordinates on the
	var/start_y			//overmap zlevel

	var/base = 0		//starting sector, counts as station_levels
	var/flagship = 0
	var/known = 1		//shows up on nav computers automatically
	var/in_space = 1	//can be accessed via lucky EVA
	var/block_slipspace = 0		//for planets with gravity wells etc
	var/occupy_range = 0

	var/list/hull_segments = list()
	var/superstructure_failing = 0
	var/list/connectors = list() //Used for docking umbilical type-items.
	var/faction = "civilian" //The faction of this object, used by sectors and NPC ships (before being loaded in). Ships have an override
	var/datum/faction/my_faction
	var/slipspace_status = 0		//0: realspace, 1: slipspace but returning to system, 2: out of system

	var/datum/targeting_datum/targeting_datum = new

	var/glassed = 0
	var/nuked = 0
	var/demolished = 0

	var/damage_overlay_file = null

	var/last_adminwarn_attack = 0

	var/controlling_faction = null

	//this is used for when we need to iterate over an entire sector's areas
	var/parent_area_type

	var/list/overmap_spawn_near_me = list()	//type path of other overmap objects to spawn near this object
	var/list/overmap_spawn_in_me = list()	//type path of other overmap objects to spawn inside this object

	var/datum/pixel_transform/my_pixel_transform
	var/list/my_observers = list()

/obj/effect/overmap/New()
	//this should already be named with a custom name by this point
	if(name == "map object")
		name = "invalid-\ref[src]"

	if(!(src in GLOB.mobs_in_sectors))
		GLOB.mobs_in_sectors[src] = list()

	//custom tags are allowed to be set in map or elsewhere
	if(!tag)
		tag = name

	. = ..()

/obj/effect/overmap/Initialize()
	..()

	for(var/entry in overmap_spawn_near_me)
		GLOB.overmap_spawn_near[entry] = src

	for(var/entry in overmap_spawn_in_me)
		GLOB.overmap_spawn_in[entry] = src

	setup_object()
	generate_targetable_areas()

	if(occupy_range)
		GLOB.overmap_tiles_uncontrolled -= trange(occupy_range,src)

	return INITIALIZE_HINT_LATELOAD

/obj/effect/overmap/LateInitialize()
	var/obj/effect/overmap/summoning_me = GLOB.overmap_spawn_near[src.type]
	if(summoning_me)
		var/list/spawn_locs = list()
		for(var/turf/t in orange(1,summoning_me))
			spawn_locs += t
		src.forceMove(pick(spawn_locs))
		GLOB.overmap_spawn_near -= src.type

	summoning_me = GLOB.overmap_spawn_in[src.type]
	if(summoning_me)
		src.forceMove(summoning_me)
		GLOB.overmap_spawn_in -= src.type

	if(flagship && faction)
		var/datum/faction/F = GLOB.factions_by_name[faction]
		if(F)
			F.flagship = src
			F.get_flagship_name()	//update the archived name
		var/datum/game_mode/gm = ticker.mode
		if(istype(gm) && gm.factions.len > 0)
			if(!(F.type in ticker.mode.factions))
				loc = null //Throw them into nullspace. Slipspace capable ships will be able to escape this, so it's not completely unescapable.
				slipspace_status = 1 //Log that they're in slipspace.

	if(base && faction)
		var/datum/faction/F = GLOB.factions_by_name[faction]
		if(F)
			F.base = src
			F.get_base_name()		//update the archived name

	my_faction = GLOB.factions_by_name[faction]

/obj/effect/overmap/proc/get_visible_damage()
	return min(glassed,5)

/obj/effect/overmap/proc/update_damage_sprite()
	if(damage_overlay_file)
		overlays.Cut()
		overlays += image(damage_overlay_file,loc,"[get_visible_damage()]")

/obj/effect/overmap/proc/generate_targetable_areas()
	if(isnull(parent_area_type))
		return
	var/list/areas_scanthrough = typesof(parent_area_type) - parent_area_type
	if(areas_scanthrough.len == 0)
		return
	for(var/a in areas_scanthrough)
		var/area/located_area = locate(a)
		if(isnull(located_area))
			continue
		var/low_x = 255
		var/upper_x = 0
		var/low_y = 255
		var/upper_y = 0
		for(var/turf/t in located_area.contents)
			if(t.x < low_x)
				low_x = t.x
			if(t.y < low_y)
				low_y = t.y
			if(t.x > upper_x)
				upper_x = t.x
			if(t.y > upper_y)
				upper_y = t.x
		targeting_locations["[located_area.name]"] = list(low_x,upper_y,upper_x,low_y)

/obj/effect/overmap/proc/get_superstructure_strength() //Returns a decimal percentage calculated from currstrength/maxstrength
	var/list/hull_strengths = list(0,0)
	for(var/obj/effect/hull_segment/hull_segment in hull_segments)
		if(hull_segment.is_segment_destroyed() == 0)
			hull_strengths[1] += hull_segment.segment_strength
		hull_strengths[2] += hull_segment.segment_strength

	if(hull_strengths[2] == 0)
		return null

	return (hull_strengths[1]/hull_strengths[2])

/obj/effect/overmap/proc/get_faction()
	return faction

/obj/effect/overmap/proc/setup_object()

	/*
	if(!GLOB.using_map.use_overmap)
		return INITIALIZE_HINT_QDEL
		*/

	if(!GLOB.using_map.overmap_z && GLOB.using_map.use_overmap)
		build_overmap()

	if(!isnull(loc))
		map_z |= loc.z
	//map_z = GetConnectedZlevels(z)
	//for(var/zlevel in map_z)
	map_sectors["[z]"] = src
	if(GLOB.using_map.use_overmap)
		var/turf/move_to_loc = null
		if(GLOB.overmap_tiles_uncontrolled.len > 0)
			move_to_loc = pick(GLOB.overmap_tiles_uncontrolled)
		else
			move_to_loc = loc

		forceMove(move_to_loc)

		testing("Located sector \"[name]\" at [move_to_loc.x],[move_to_loc.y], containing Z [english_list(map_z)]")
	//points_of_interest += name

	/*
	GLOB.using_map.player_levels |= map_z
		*/

	/*
	if(!in_space)
		GLOB.using_map.sealed_levels |= map_z
		*/

	/*
	if(base)
		GLOB.using_map.station_levels |= map_z
		GLOB.using_map.contact_levels |= map_z
		*/

	//find shuttle waypoints
	var/list/found_waypoints = list()
	for(var/waypoint_tag in generic_waypoints)
		var/obj/effect/shuttle_landmark/WP = locate(waypoint_tag)
		if(WP)
			found_waypoints += WP
		else
			log_error("Sector \"[name]\" containing Z [english_list(map_z)] could not find waypoint with tag [waypoint_tag]!")
	generic_waypoints = found_waypoints

	for(var/shuttle_name in restricted_waypoints)
		found_waypoints = list()
		for(var/waypoint_tag in restricted_waypoints[shuttle_name])
			var/obj/effect/shuttle_landmark/WP = locate(waypoint_tag)
			if(WP)
				found_waypoints += WP
			else
				log_error("Sector \"[name]\" containing Z [english_list(map_z)] could not find waypoint with tag [waypoint_tag]!")
		restricted_waypoints[shuttle_name] = found_waypoints

/obj/effect/overmap/proc/link_zlevel(var/obj/effect/landmark/map_data/new_data)
	if(new_data)
		map_sectors["[new_data.z]"] = src
		map_z |= new_data.z

		var/obj/effect/landmark/map_data/above
		var/obj/effect/landmark/map_data/below
		for(var/obj/effect/landmark/map_data/check_data in map_z_data)

			//possible candidate for above
			if(check_data.z < new_data.z)
				//check_data is higher than new_data

				if(!above || check_data.z > above.z)
					//gottem
					above = check_data


			//possible candidate for below
			if(check_data.z > new_data.z)
				//check_data is lower than new_data

				if(!below || check_data.z < below.z)
					//gottem
					below = check_data


		//update the other linkages
		new_data.above = above
		if(above)
			above.below = new_data
		//
		new_data.below = below
		if(below)
			below.above = new_data

		//add it to our list
		map_z_data.Add(new_data)

/obj/effect/overmap/proc/get_waypoints(var/shuttle_name)
	. = generic_waypoints.Copy()
	if(shuttle_name in restricted_waypoints)
		. += restricted_waypoints[shuttle_name]

/obj/effect/overmap/proc/do_superstructure_fail()
	var/obj/effect/overmap/sector/s = locate() in range(1,src)
	var/obj/effect/overmap/ship/self_ship = src
	var/crash_landing = 0
	if(s && istype(self_ship))
		crash_landing = 1
	for(var/mob/living/player in GLOB.mobs_in_sectors[src])
		if(istype(player.loc,/turf)) //There's a number of situations where being inside something may be a problem, so let's handle them all here.
			if(crash_landing)
				player.adjustBruteLoss(40)
				player.adjustFireLoss(40)
				to_chat(player,"<span class = 'userdanger'>You hang on for dear life as [src] de-orbits.</span>")
				player.Stun(6)
				player.flash_eyes()
			else
				player.dust()
	if(crash_landing)
		self_ship.do_crash_landing(s,0)
	else
		loc = null

		message_admins("NOTICE: Overmap object [src] has been destroyed. Please wait as it is deleted.")
		log_admin("NOTICE: Overmap object [src] has been destroyed.")
		sleep(10)//To allow the previous message to actually be seen
		for(var/z_level in map_z)
			shipmap_handler.free_map(z_level)
		qdel(src)

/obj/effect/overmap/proc/pre_superstructure_failing()
	for(var/mob/player in GLOB.mobs_in_sectors[src])
		if(istype(src,/obj/effect/overmap/sector))
			to_chat(player,"<span class = 'danger'>Core AO Planetary Structure Failing. ETA: [SUPERSTRUCTURE_FAIL_TIME/600] minutes.</span>")
		else
			to_chat(player,"<span class = 'danger'>SHIP SUPERSTRUCTURE FAILING. ETA: [SUPERSTRUCTURE_FAIL_TIME/600] minutes.</span>")
	superstructure_failing = 1
	spawn(SUPERSTRUCTURE_FAIL_TIME)
		do_superstructure_fail()

/obj/effect/overmap/proc/superstructure_process()
	if(superstructure_failing == -1)
		return
	if(superstructure_failing == 1)
		if(hull_segments.len == 0)
			return
		var/obj/explode_center = pick(hull_segments)
		var/turf/explode_at = pick(trange(7,explode_center))
		explosion(explode_at,1,3,5,5, adminlog = 0)
		return
	var/list/superstructure_strength = get_superstructure_strength()
	if(isnull(superstructure_strength))
		superstructure_failing = -1
		return
	if(superstructure_strength <= SUPERSTRUCTURE_FAIL_PERCENT)
		pre_superstructure_failing()

/obj/effect/overmap/process()
	for(var/e in active_effects)
		var/datum/overmap_effect/effect = e
		if(!effect.process_effect())
			active_effects -= src
			qdel(effect)
	if(!isnull(targeting_datum.current_target) && !(targeting_datum.current_target in range(src,7)))
		targeting_datum.current_target = null
		targeting_datum.targeted_location = "target lost"
	superstructure_process()

/obj/effect/overmap/update_icon()
	. = ..()
	update_damage_sprite()

/obj/effect/overmap/sector
	name = "generic sector"
	desc = "Sector with some stuff in it."
	icon_state = "sector"
	layer = TURF_LAYER
	anchored = 1

/obj/effect/overmap/sector/Initialize()
	. = ..()
	GLOB.processing_objects += src
	for(var/obj/machinery/computer/helm/H in GLOB.machines)
		H.get_known_sectors()
	if(base)
		GLOB.om_base_sectors += src

/obj/effect/overmap/proc/adminwarn_attack(var/attacker)
	if(world.time > last_adminwarn_attack + 1 MINUTE)
		last_adminwarn_attack = world.time
		var/msg = "[src] is under attack[attacker ? " by [attacker]" : ""]"
		log_admin(msg)
		message_admins(msg)

/proc/build_overmap()
	if(!GLOB.using_map.use_overmap)
		return 1

	report_progress("Building overmap...")
	world.maxz++
	GLOB.using_map.overmap_z = world.maxz
	var/list/turfs = list()
	for (var/square in block(locate(1,1,GLOB.using_map.overmap_z), locate(GLOB.using_map.overmap_size,GLOB.using_map.overmap_size,GLOB.using_map.overmap_z)))
		var/turf/T = square
		if(T.x == GLOB.using_map.overmap_size || T.y == GLOB.using_map.overmap_size)
			T = T.ChangeTurf(/turf/unsimulated/map/edge)
		else
			T = T.ChangeTurf(/turf/unsimulated/map/)
			GLOB.overmap_tiles_uncontrolled += T
		T.lighting_clear_overlay()
		turfs += T

	var/area/overmap/A = new
	A.contents.Add(turfs)

	GLOB.using_map.sealed_levels |= GLOB.using_map.overmap_z
	if(GLOB.using_map.overmap_event_tokens > 0)
		for(var/i = 0 to GLOB.using_map.overmap_event_tokens)
			new /obj/effect/overmap/hazard/random

	report_progress("Overmap build complete.")
	shipmap_handler.max_z_cached = world.maxz
	return 1



