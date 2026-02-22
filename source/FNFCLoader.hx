package;

import haxe.Json;
import haxe.io.Bytes;
import haxe.zip.Entry;
import haxe.zip.Reader;
import sys.FileSystem;
import sys.io.File;
import Song.SwagSong;
import Section.SwagSection;

#if sys
import openfl.media.Sound;
#end

/**
 * FNFCLoader
 * ==========
 * Loads Friday Night Funkin' Chart (.fnfc) files and converts them into
 * the legacy SwagSong format that PlayState understands.
 *
 * A .fnfc is a ZIP archive. For "bopeebo" the zip contains:
 *   manifest.json
 *   bopeebo-metadata.json           ← base variation (easy / normal / hard)
 *   bopeebo-chart.json
 *   bopeebo-metadata-erect.json     ← erect variation  →  in-game: "expert"
 *   bopeebo-chart-erect.json
 *   Inst.ogg, Inst-erect.ogg
 *   Voices-bf.ogg, Voices-dad.ogg, Voices-bf-erect.ogg, Voices-dad-erect.ogg …
 *
 * DIFFICULTY MAPPING  (PlayState.storyDifficulty integer):
 *   0 → easy    → base variation, chart key "easy"
 *   1 → normal  → base variation, chart key "normal"
 *   2 → hard    → base variation, chart key "hard"
 *   3 → expert  → erect variation, chart key "erect"
 *   "nightmare" is ALWAYS excluded and never loaded.
 *
 * FILES THAT NEED EDITS (see companion patch files):
 *   Song.hx      → call FNFCLoader.load() when .fnfc exists
 *   PlayState.hx → extractAudio() + Sound.fromFile for inst/voices
 *   CoolUtil.hx  → ensure difficultyString() returns "Expert" at index 3
 */
class FNFCLoader
{
	// ── Difficulty int → FNF v2 chart JSON key ────────────────────────────────
	static final DIFF_TO_CHART_KEY:Map<Int, String> = [
		0 => "easy",
		1 => "normal",
		2 => "hard",
		3 => "erect"   // inside the .fnfc this is "erect"; in-game we call it "expert"
	];

	// Temp folder for extracted audio (relative to game executable).
	static final TEMP_DIR:String = "./fnfc-temp/";

	// Where .fnfc files live at runtime (preload library strips the "preload/" prefix on export).
	static final FNFC_ASSET_DIR:String = "assets/data/";

	// ── Public state flags (read by PlayState / Song) ─────────────────────────
	/** True while the current song was loaded from a .fnfc file. */
	public static var isActive:Bool = false;

	/** The songId of the currently active FNFC song, e.g. "bopeebo". */
	public static var activeSongId:String = "";

	/** The variation used for the active load ("" = base, "erect", "pico"…). */
	public static var activeVariation:String = "";

	// Internal zip entry cache — avoids re-reading the archive on every call.
	static var zipCache:Map<String, List<Entry>> = new Map();

	// ══════════════════════════════════════════════════════════════════════════
	// PUBLIC API
	// ══════════════════════════════════════════════════════════════════════════

	/**
	 * Returns true when a .fnfc file exists for the given songId.
	 * Check this before deciding whether to use FNFCLoader or the old JSON path.
	 */
	public static function exists(songId:String):Bool
	{
		return FileSystem.exists(getFnfcPath(songId));
	}

	/**
	 * Load a .fnfc and return a legacy-compatible SwagSong.
	 *
	 * @param songId     Song folder name, e.g. "bopeebo"
	 * @param difficulty 0=easy  1=normal  2=hard  3=expert
	 */
	public static function load(songId:String, difficulty:Int):SwagSong
	{
		var entries   = getEntries(songId);
		var id        = getSongIdFromManifest(entries, songId);
		var variation = resolveVariation(entries, id, difficulty);
		var varSuffix = (variation == "") ? "" : "-" + variation;

		var metaJson  = readJson(entries, id + "-metadata" + varSuffix + ".json");
		var chartJson = readJson(entries, id + "-chart"    + varSuffix + ".json");

		if (metaJson == null)
			throw '[FNFCLoader] metadata not found: ${id}-metadata${varSuffix}.json';
		if (chartJson == null)
			throw '[FNFCLoader] chart not found: ${id}-chart${varSuffix}.json';

		var chartKey = DIFF_TO_CHART_KEY.exists(difficulty) ? DIFF_TO_CHART_KEY[difficulty] : "normal";
		trace('[FNFCLoader] load() → id=$id  variation=$variation  chartKey=$chartKey');

		isActive        = true;
		activeSongId    = id;
		activeVariation = variation;

		return convertToSwagSong(id, metaJson, chartJson, chartKey);
	}

	/**
	 * Extract instrumental and vocals from the .fnfc ZIP to TEMP_DIR on disk.
	 *
	 * Extracted files:
	 *   fnfc-temp/{songId}/Inst.ogg           ← instrumental
	 *   fnfc-temp/{songId}/Voices.ogg         ← player (BF) vocals — gets muted on miss
	 *   fnfc-temp/{songId}/VoicesOpponent.ogg ← opponent vocals (bonus; future 2-track use)
	 *
	 * Call from PlayState.create() BEFORE any audio caching, only when isActive==true.
	 */
	public static function extractAudio(songId:String, difficulty:Int):Void
	{
		#if sys
		var entries   = getEntries(songId);
		var id        = getSongIdFromManifest(entries, songId);
		var variation = resolveVariation(entries, id, difficulty);
		var varSuffix = (variation == "") ? "" : "-" + variation;

		var outDir = TEMP_DIR + id + "/";
		if (!FileSystem.exists(TEMP_DIR)) FileSystem.createDirectory(TEMP_DIR);
		if (!FileSystem.exists(outDir))   FileSystem.createDirectory(outDir);

		// ── Instrumental ──────────────────────────────────────────────────────
		if (!extractEntry(entries, "Inst" + varSuffix + ".ogg", outDir + "Inst.ogg"))
			extractEntry(entries, "Inst.ogg", outDir + "Inst.ogg");

		// ── Read character IDs from metadata ──────────────────────────────────
		var metaJson = readJson(entries, id + "-metadata" + varSuffix + ".json");
		var oppChar  = "dad";
		var plyChar  = "bf";
		if (metaJson != null && metaJson.playData != null && metaJson.playData.characters != null)
		{
			var chars:Dynamic = metaJson.playData.characters;
			if (chars.opponent != null) oppChar = Std.string(chars.opponent);
			if (chars.player   != null) plyChar  = Std.string(chars.player);
		}

		// ── Player (BF) vocals → Voices.ogg ──────────────────────────────────
		// BF's vocals go here because PlayState.vocals is the track that gets
		// silenced (volume=0) when the player misses a note.
		if (!extractEntry(entries, "Voices-" + plyChar + varSuffix + ".ogg", outDir + "Voices.ogg"))
			if (!extractEntry(entries, "Voices-" + plyChar + ".ogg",                outDir + "Voices.ogg"))
				extractEntry(entries, "Voices.ogg",                                 outDir + "Voices.ogg");

		// ── Opponent vocals → VoicesOpponent.ogg ─────────────────────────────
		if (!extractEntry(entries, "Voices-" + oppChar + varSuffix + ".ogg", outDir + "VoicesOpponent.ogg"))
			extractEntry(entries, "Voices-" + oppChar + ".ogg",               outDir + "VoicesOpponent.ogg");

		trace('[FNFCLoader] Audio extracted for "$id" (variation="$variation") → $outDir');
		#else
		trace("[FNFCLoader] extractAudio() requires a sys (desktop) target — skipped.");
		#end
	}

	// ── Path/sound getters used by PlayState patches ──────────────────────────

	/** Filesystem path to the extracted instrumental. */
	public static function getTempInstPath(songId:String):String
		return TEMP_DIR + songId + "/Inst.ogg";

	/** Filesystem path to the extracted player vocals. */
	public static function getTempVoicesPath(songId:String):String
		return TEMP_DIR + songId + "/Voices.ogg";

	#if sys
	/**
	 * Load the extracted instrumental as an openfl Sound object.
	 * Use this in PlayState.startSong() when isActive == true.
	 */
	public static function loadInstSound(songId:String):Sound
		return Sound.fromFile(getTempInstPath(songId));

	/**
	 * Load the extracted player vocals as an openfl Sound object.
	 * Use this in PlayState.generateSong() when isActive == true.
	 */
	public static function loadVoicesSound(songId:String):Sound
		return Sound.fromFile(getTempVoicesPath(songId));
	#end

	/**
	 * Reset active state and clear the zip cache.
	 * Call from PlayState.destroy() to free memory.
	 */
	public static function reset():Void
	{
		isActive        = false;
		activeSongId    = "";
		activeVariation = "";
		zipCache.clear();
		trace("[FNFCLoader] Cache cleared.");
	}

	// ══════════════════════════════════════════════════════════════════════════
	// CHART CONVERSION   FNF v2.0.0 → legacy SwagSong
	// ══════════════════════════════════════════════════════════════════════════

	static function convertToSwagSong(id:String, meta:Dynamic, chart:Dynamic, diffKey:String):SwagSong
	{
		// ── BPM from first timeChange entry ───────────────────────────────────
		var bpm:Float = 100;
		if (meta.timeChanges != null)
		{
			var tcs:Array<Dynamic> = cast meta.timeChanges;
			if (tcs.length > 0 && tcs[0].bpm != null)
				bpm = tcs[0].bpm;
		}
		var stepCrochet:Float = (60.0 / bpm * 1000.0) / 4.0; // ms per step

		// ── Scroll speed ──────────────────────────────────────────────────────
		var speed:Float = 2.0;
		if (chart.scrollSpeed != null && Reflect.hasField(chart.scrollSpeed, diffKey))
			speed = Reflect.field(chart.scrollSpeed, diffKey);

		// ── Raw notes for this difficulty ─────────────────────────────────────
		var rawNotes:Array<Dynamic> = [];
		if (chart.notes != null && Reflect.hasField(chart.notes, diffKey))
			rawNotes = cast Reflect.field(chart.notes, diffKey);

		if (rawNotes.length == 0)
			trace('[FNFCLoader] WARNING: no notes found for diffKey="$diffKey" — chart may be empty!');

		// ── How many sections do we need? ─────────────────────────────────────
		var maxTime:Float = 0;
		for (n in rawNotes)
		{
			var endMs:Float = (n.t : Float) + (n.l : Float);
			if (endMs > maxTime) maxTime = endMs;
		}

		// ── Camera events → mustHitSection per section ────────────────────────
		// Pass totalSections so parseCameraEvents can return a full Array<Bool>
		// indexed directly by section number. Algorithm: for each section S,
		// the camera state = the last FocusCamera event where t < (S+1)*sectionMs.
		var totalSections:Int = Std.int(Math.ceil(maxTime / (16.0 * stepCrochet))) + 2;
		var sectionFocus:Array<Bool> = parseCameraEvents(chart.events, stepCrochet, totalSections);

		// ── Build section array ───────────────────────────────────────────────
		// Anonymous objects MUST include every field from the SwagSection typedef:
		//   sectionNotes, lengthInSteps, typeOfSection, mustHitSection,
		//   bpm, changeBPM, altAnim
		var sections:Array<SwagSection> = [];
		for (i in 0...totalSections)
		{
			var mustHit:Bool = sectionFocus[i];
			var sec:SwagSection = cast {
				sectionNotes  : ([] : Array<Dynamic>),
				lengthInSteps : 16,
				typeOfSection : 0,
				mustHitSection: mustHit,
				bpm           : bpm,
				changeBPM     : false,
				altAnim       : false
			};
			sections.push(sec);
		}

		// ── Distribute FNF v2 notes into legacy sections ───────────────────────
		//
		// FNF v2 "d" (direction) field encoding — ABSOLUTE, not relative to section:
		//   d 0-3 = player (BF)    notes  [left, down, up, right]
		//   d 4-7 = opponent (Dad) notes  [left, down, up, right]
		//
		// Legacy PlayState sectionNotes: [time, noteData, sustainLength]
		//   mustHitSection=TRUE  → noteData 0-3 = BF plays,  noteData 4-7 = Dad plays
		//   mustHitSection=FALSE → noteData 0-3 = Dad plays, noteData 4-7 = BF plays
		//   (PlayState flips gottaHitNote when noteData > 3)
		//
		// Conversion:
		//   mustHitSection=TRUE  → legacyData = d  (BF already in 0-3, Dad already in 4-7)
		//   mustHitSection=FALSE → BF note (d<4): legacyData = d+4
		//                        → Dad note (d>=4): legacyData = d-4
		//
		for (rawNote in rawNotes)
		{
			var t:Float       = rawNote.t;
			var d:Int         = Std.int(rawNote.d);
			var l:Float       = rawNote.l;
			var isPlayer:Bool = (d < 4); // d 0-3 = BF (player), d 4-7 = Dad (opponent)

			var sIdx:Int = Std.int(Math.floor(t / (16.0 * stepCrochet)));
			if (sIdx < 0)                sIdx = 0;
			if (sIdx >= sections.length) sIdx = sections.length - 1;

			var sec = sections[sIdx];
			// mustHitSection=true:  BF(0-3) stays 0-3, Dad(4-7) stays 4-7  → no change
			// mustHitSection=false: BF(0-3) → 4-7 (+4),  Dad(4-7) → 0-3 (-4)
			var legacyData:Int = sec.mustHitSection
				? d
				: (isPlayer ? (d + 4) : (d - 4));

			sec.sectionNotes.push([t, legacyData, l]);
		}

		// ── Character IDs ─────────────────────────────────────────────────────
		var player1 = "bf";
		var player2 = "dad";
		if (meta.playData != null && meta.playData.characters != null)
		{
			var chars:Dynamic = meta.playData.characters;
			if (chars.player   != null) player1 = Std.string(chars.player);
			if (chars.opponent != null) player2 = Std.string(chars.opponent);
		}

		// ── Song display name ─────────────────────────────────────────────────
		// We use the capitalised songId (e.g. "Bopeebo") rather than the
		// metadata's songName (e.g. "Bopeebo Erect") so that PlayState's
		// switch/case blocks like 'case "bopeebo":' keep working for ALL
		// variations of the same song.
		var songDisplayName:String = id.charAt(0).toUpperCase() + id.substr(1).toLowerCase();

		// ── Assemble SwagSong ─────────────────────────────────────────────────
		// Must include every field from the SwagSong typedef:
		//   song, notes, bpm, needsVoices, speed, player1, player2, validScore
		var swagSong:SwagSong = cast {
			song        : songDisplayName,
			notes       : sections,
			bpm         : bpm,
			needsVoices : true,
			speed       : speed,
			player1     : player1,
			player2     : player2,
			validScore  : true
		};

		trace('[FNFCLoader] Converted "${songDisplayName}" — ${sections.length} sections, ${rawNotes.length} notes, BPM=$bpm, speed=$speed');
		return swagSong;
	}

	/**
	 * Build a per-section camera focus array.
	 *
	 * ALGORITHM: For each section S, the mustHitSection value =
	 * the last FocusCamera event where event.t < (S+1)*sectionMs.
	 *
	 * This is correct because:
	 *  - Events placed exactly at a section boundary (t = S*sectionMs) may
	 *    have float values of (S-epsilon), which floor() puts in section S-1.
	 *    Using t < section_END rather than t <= section_START avoids this.
	 *  - Events that fire mid-section correctly update that section's camera.
	 *  - A running pointer makes this O(sections + events).
	 *
	 * FocusCamera "v" field formats:
	 *   Base chart (v2.0.0):  v = Int       — 0=BF (mustHit=true), 1=Dad (mustHit=false)
	 *   Erect chart (newer):  v = Object    — char=0=BF, char=1=Dad, char=2=GF
	 *   char=2 (GF) is treated the same as Dad for mustHitSection purposes.
	 */
	static function parseCameraEvents(events:Dynamic, stepCrochet:Float, totalSections:Int):Array<Bool>
	{
		var sectionMs:Float = 16.0 * stepCrochet;

		// Default: all sections have camera on BF (mustHitSection=true)
		var result:Array<Bool> = [for (_ in 0...totalSections) true];

		if (events == null) return result;

		// Pre-filter to FocusCamera events only and sort by time ascending
		var arr:Array<Dynamic> = cast events;
		var focusEvents:Array<Dynamic> = arr.filter(function(e) return e.e == "FocusCamera");
		focusEvents.sort(function(a, b) return Reflect.compare(a.t, b.t));

		if (focusEvents.length == 0) return result;

		// Running pointer — advance through events as section windows move forward
		var ptr:Int = 0;
		var currentChar:Int = -1; // -1 = no event seen yet

		for (s in 0...totalSections)
		{
			var sectionEnd:Float = (s + 1) * sectionMs;

			// Consume all events that fire before this section ends
			while (ptr < focusEvents.length)
			{
				var t:Float = focusEvents[ptr].t;
				if (t >= sectionEnd) break;

				var v:Dynamic = focusEvents[ptr].v;
				if (Std.isOfType(v, Int) || Std.isOfType(v, Float))
				{
					currentChar = Std.int(v);
				}
				else if (Reflect.hasField(v, "char"))
				{
					currentChar = Std.int(Reflect.field(v, "char"));
				}
				ptr++;
			}

			// char=0 → BF (mustHit=true), anything else → Dad/GF (mustHit=false)
			// If no event has fired yet, default to true (camera on BF)
			result[s] = (currentChar == -1) ? true : (currentChar == 0);
		}

		return result;
	}

	// ══════════════════════════════════════════════════════════════════════════
	// VARIATION RESOLUTION
	// ══════════════════════════════════════════════════════════════════════════

	/**
	 * Returns the variation string to use ("" = base, "erect", "pico"…).
	 * difficulty=3 always maps to the erect variation.
	 * "nightmare" is never selected.
	 */
	static function resolveVariation(entries:List<Entry>, id:String, difficulty:Int):String
	{
		if (difficulty == 3 && hasEntry(entries, id + "-metadata-erect.json"))
			return "erect";
		return ""; // base variation covers easy / normal / hard
	}

	// ══════════════════════════════════════════════════════════════════════════
	// ZIP / FILE HELPERS
	// ══════════════════════════════════════════════════════════════════════════

	static function getEntries(songId:String):List<Entry>
	{
		if (zipCache.exists(songId)) return zipCache.get(songId);

		var path = getFnfcPath(songId);
		if (!FileSystem.exists(path))
			throw '[FNFCLoader] .fnfc not found: $path';

		var fi      = File.read(path, true);
		var entries = new Reader(fi).read();
		fi.close();

		zipCache.set(songId, entries);
		trace('[FNFCLoader] Loaded zip: $path  (${Lambda.count(entries)} entries)');
		return entries;
	}

	static function hasEntry(entries:List<Entry>, fileName:String):Bool
	{
		for (e in entries) if (e.fileName == fileName) return true;
		return false;
	}

	static function readBytes(entries:List<Entry>, fileName:String):Bytes
	{
		for (e in entries)
		{
			if (e.fileName == fileName)
				return e.compressed ? haxe.zip.Uncompress.run(e.data) : e.data;
		}
		return null;
	}

	static function readJson(entries:List<Entry>, fileName:String):Dynamic
	{
		var bytes = readBytes(entries, fileName);
		if (bytes == null) return null;
		try   { return Json.parse(bytes.toString()); }
		catch (e:Dynamic) { trace('[FNFCLoader] JSON parse error in "$fileName": $e'); return null; }
	}

	/** Extracts one zip entry to a filesystem path. Returns true on success. */
	static function extractEntry(entries:List<Entry>, zipName:String, destPath:String):Bool
	{
		#if sys
		var bytes = readBytes(entries, zipName);
		if (bytes == null) { trace('[FNFCLoader] Not in zip: "$zipName"'); return false; }
		File.saveBytes(destPath, bytes);
		trace('[FNFCLoader] Extracted "$zipName" → $destPath');
		return true;
		#else
		return false;
		#end
	}

	static function getSongIdFromManifest(entries:List<Entry>, fallback:String):String
	{
		var manifest = readJson(entries, "manifest.json");
		return (manifest != null && manifest.songId != null) ? Std.string(manifest.songId) : fallback;
	}

	/** Returns the .fnfc path for a given songId. */
	public static function getFnfcPath(songId:String):String
		return FNFC_ASSET_DIR + songId + "/" + songId + ".fnfc";
}
