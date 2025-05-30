/*!
 * Copyright (c) 2020 Aleksej Komarov
 * SPDX-License-Identifier: MIT
 */

/**
 * Maximum number of connection records allowed to analyze.
 * Should match the value set in the browser.
 */
#define TGUI_TELEMETRY_MAX_CONNECTIONS 5

/**
 * Maximum time allocated for sending a telemetry packet.
 */
#define TGUI_TELEMETRY_RESPONSE_WINDOW 30 SECONDS

/// Time of telemetry request
/datum/tgui_panel/var/telemetry_requested_at
/// Time of telemetry analysis completion
/datum/tgui_panel/var/telemetry_analyzed_at
/// List of previous client connections
/datum/tgui_panel/var/list/telemetry_connections

/**
 * private
 *
 * Requests some telemetry from the client.
 */
/datum/tgui_panel/proc/request_telemetry()
	telemetry_requested_at = world.time
	telemetry_analyzed_at = null
	window.send_message("telemetry/request", list(
		"limits" = list(
			"connections" = TGUI_TELEMETRY_MAX_CONNECTIONS,
		),
	))

/**
 * private
 *
 * Analyzes a telemetry packet.
 *
 * Is currently only useful for detecting ban evasion attempts.
 */
/datum/tgui_panel/proc/analyze_telemetry(payload)
	if(world.time > telemetry_requested_at + TGUI_TELEMETRY_RESPONSE_WINDOW)
		message_admins("[key_name(client)] sent telemetry outside of the allocated time window.")
		return
	if(telemetry_analyzed_at)
		message_admins("[key_name(client)] sent telemetry more than once.")
		return
	telemetry_analyzed_at = world.time
	if(!payload)
		return
	telemetry_connections = payload["connections"]
	var/len = length(telemetry_connections)
	if(len == 0)
		return
	if(len > TGUI_TELEMETRY_MAX_CONNECTIONS)
		message_admins("[key_name(client)] was kicked for sending a huge telemetry payload")
		qdel(client)
		return

	var/ckey = client?.ckey
	if (!ckey)
		return

	var/list/known_alts = list()
	for(var/datum/view_record/known_alt/alts in DB_VIEW(/datum/view_record/known_alt, DB_COMP("player_ckey", DB_EQUALS, ckey)))
		known_alts += alts.ckey

	var/list/found

	for(var/i in 1 to len)
		if(QDELETED(client))
			// He got cleaned up before we were done
			return
		var/list/row = telemetry_connections[i]

		// Check for a malformed history object
		if (LAZYLEN(row) < 3 || (!row["ckey"] || !row["address"] || !row["computer_id"]))
			continue

		/* TODO - Reintroduce this when we get a proper round ID tracking,
			and we want to log it to database

		var/list/query_data = list()
		if (!isnull(GLOB.round_id))
			query_data += list(list(
				"telemetry_ckey" = row["ckey"],
				"address" = row["address"],
				"computer_id" = row["computer_id"],
			))
		*/

		if (row["ckey"] in known_alts)
			continue


		if (world.IsBanned(row["ckey"], row["address"], row["computer_id"], real_bans_only = TRUE, is_telemetry = TRUE))
			found = row
			break

		CHECK_TICK

	// This fucker has a history of playing on a banned account.
	if(found)
		var/msg = "[key_name(client)] has a banned account in connection history! (Matched: [found["ckey"]], [found["address"]], [found["computer_id"]])"
		message_admins(msg)
		log_admin_private(msg)
		//log_suspicious_login(msg, access_log_mirror = FALSE)
