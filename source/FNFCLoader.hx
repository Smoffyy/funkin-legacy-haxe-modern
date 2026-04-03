package;

import haxe.Json;
import haxe.io.Bytes;
import haxe.zip.Entry;
import haxe.zip.Reader;
import Song.SwagSong;
import Section.SwagSection;

#if sys
import sys.FileSystem;
import sys.io.File;
import openfl.media.Sound;
import openfl.Lib;
import openfl.events.Event;
#end

class FNFCLoader
{
	static final DIFF_TO_CHART_KEY:Map<Int, String> = [
		0 => "easy",
		1 => "normal",
		2 => "hard",
		3 => "erect",
		4 => "nightmare"
	];

	static final TEMP_DIR:String       = "./fnfc-temp/";
	static final FNFC_ASSET_DIR:String = "assets/data/";

	public static var isActive:Bool         = false;
	public static var activeSongId:String   = "";
	public static var activeVariation:String = "";
	public static var activeCharter:String  = "";
	public static var activeSongArtist:String = "";
	public static var activeEvents:Array<Dynamic> = [];

	// zip entry cache — avoids re-reading the archive per call
	static var zipCache:Map<String, List<Entry>> = new Map();

	#if sys
	static var exitHookRegistered:Bool = false;

	// Pre-built entry name→index lookup for O(1) searches instead of O(n) linear scans
	static var entryIndexCache:Map<String, Map<String, Entry>> = new Map();
	#end

	// ══════════════════════════════════════════════════════════════════════════
	// PUBLIC API
	// ══════════════════════════════════════════════════════════════════════════

	public static function exists(songId:String):Bool
	{
		#if sys
		return FileSystem.exists(getFnfcPath(songId));
		#else
		return false;
		#end
	}

	public static function load(songId:String, difficulty:Int):SwagSong
	{
		#if !sys
		throw "[FNFCLoader] .fnfc loading is not supported on this platform.";
		return null;
		#else

		if (!exitHookRegistered)
		{
			exitHookRegistered = true;
			if (FileSystem.exists(TEMP_DIR))
				deleteDirRecursive(TEMP_DIR);
			try {
				Lib.current.stage.addEventListener(Event.DEACTIVATE, function(_) {
					if (FileSystem.exists(TEMP_DIR))
						deleteDirRecursive(TEMP_DIR);
				});
			} catch (e:Dynamic) {}
		}

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

		if (isActive && activeSongId != "" && activeSongId != id)
		{
			var oldDir = TEMP_DIR + activeSongId + "/";
			if (FileSystem.exists(oldDir))
				deleteDirRecursive(oldDir);
		}

		isActive        = true;
		activeSongId    = id;
		activeVariation = variation;

		activeCharter    = (metaJson != null && metaJson.charter != null) ? Std.string(metaJson.charter) : "";
		activeSongArtist = (metaJson != null && metaJson.artist  != null) ? Std.string(metaJson.artist)  : "";

		activeEvents = [];
		if (chartJson.events != null)
		{
			var all:Array<Dynamic> = cast chartJson.events;
			activeEvents = all.copy();
			activeEvents.sort(function(a:Dynamic, b:Dynamic):Int {
				var ta:Float = a.t; var tb:Float = b.t;
				if (ta < tb) return -1; if (ta > tb) return 1; return 0;
			});
		}

		return convertToSwagSong(id, metaJson, chartJson, chartKey);
		#end
	}

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

		var instPath  = outDir + "Inst.ogg";
		var voicePath = outDir + "Voices.ogg";

		var metaJson = readJson(entries, id + "-metadata" + varSuffix + ".json");
		var plyVocal = "bf";
		var oppVocal = "dad";
		if (metaJson != null && metaJson.playData != null)
		{
			var pd:Dynamic = metaJson.playData;
			if (pd.characters != null && pd.characters.playerVocals != null)
			{
				var pv:Array<Dynamic> = cast pd.characters.playerVocals;
				if (pv.length > 0) plyVocal = Std.string(pv[0]);
			}
			if (pd.characters != null && pd.characters.opponentVocals != null)
			{
				var ov:Array<Dynamic> = cast pd.characters.opponentVocals;
				if (ov.length > 0) oppVocal = Std.string(ov[0]);
			}
		}

		if (!FileSystem.exists(instPath))
		{
			if (!extractEntry(entries, "Inst" + varSuffix + ".ogg", instPath))
				extractEntry(entries, "Inst.ogg", instPath);
		}

		if (!FileSystem.exists(voicePath))
		{
			if (!extractEntry(entries, "Voices-" + plyVocal + varSuffix + ".ogg", voicePath))
				if (!extractEntry(entries, "Voices-" + plyVocal + ".ogg", voicePath))
					extractEntry(entries, "Voices.ogg", voicePath);

			var oppVoicePath = outDir + "VoicesOpponent.ogg";
			if (!FileSystem.exists(oppVoicePath))
			{
				if (!extractEntry(entries, "Voices-" + oppVocal + varSuffix + ".ogg", oppVoicePath))
					extractEntry(entries, "Voices-" + oppVocal + ".ogg", oppVoicePath);
			}
		}

		trace('[FNFCLoader] Audio ready for "$id" (variation="$variation") → $outDir');
		#else
		trace("[FNFCLoader] extractAudio() requires a sys (desktop) target — skipped.");
		#end
	}

	public static function getTempInstPath(songId:String):String
		return TEMP_DIR + songId + "/Inst.ogg";

	public static function getTempVoicesPath(songId:String):String
		return TEMP_DIR + songId + "/Voices.ogg";

	public static function getTempOpponentVoicesPath(songId:String):String
		return TEMP_DIR + songId + "/VoicesOpponent.ogg";

	public static function hasOpponentVoices(songId:String):Bool
	{
		#if sys
		return FileSystem.exists(getTempOpponentVoicesPath(songId));
		#else
		return false;
		#end
	}

	#if sys
	public static function loadInstSound(songId:String):Sound
		return Sound.fromFile(getTempInstPath(songId));

	public static function loadVoicesSound(songId:String):Sound
		return Sound.fromFile(getTempVoicesPath(songId));

	public static function loadOpponentVoicesSound(songId:String):Sound
		return Sound.fromFile(getTempOpponentVoicesPath(songId));
	#end

	public static function getPreviewInstPath(songId:String, difficulty:Int):String
	{
		#if sys
		var id = songId.toLowerCase();
		if (!exists(id)) return null;

		try
		{
			var entries    = getEntries(id);
			var manifestId = getSongIdFromManifest(entries, id);
			var variation  = resolveVariation(entries, manifestId, difficulty);
			var varSuffix  = (variation == "") ? "" : "-" + variation;
			var previewFile = "preview" + varSuffix + ".ogg";

			var outDir = TEMP_DIR + manifestId + "/";
			if (!FileSystem.exists(TEMP_DIR)) FileSystem.createDirectory(TEMP_DIR);
			if (!FileSystem.exists(outDir))   FileSystem.createDirectory(outDir);

			var destPath = outDir + previewFile;
			if (!FileSystem.exists(destPath))
			{
				if (!extractEntry(entries, "Inst" + varSuffix + ".ogg", destPath))
					extractEntry(entries, "Inst.ogg", destPath);
			}

			return FileSystem.exists(destPath) ? destPath : null;
		}
		catch (e:Dynamic)
		{
			trace('[FNFCLoader] getPreviewInstPath failed for "$songId": $e');
			return null;
		}
		#else
		return null;
		#end
	}

	public static function reset():Void
	{
		#if sys
		if (activeSongId != "")
		{
			var dir = TEMP_DIR + activeSongId + "/";
			if (FileSystem.exists(dir))
				deleteDirRecursive(dir);
		}
		#end
		isActive         = false;
		activeSongId     = "";
		activeVariation  = "";
		activeCharter    = "";
		activeSongArtist = "";
		activeEvents     = [];
		zipCache.clear();
		#if sys
		entryIndexCache.clear();
		#end
		trace("[FNFCLoader] Reset.");
	}

	// ══════════════════════════════════════════════════════════════════════════
	// CHART CONVERSION   FNF v2.0.0 → legacy SwagSong
	// ══════════════════════════════════════════════════════════════════════════

	static function convertToSwagSong(id:String, meta:Dynamic, chart:Dynamic, diffKey:String):SwagSong
	{
		var bpm:Float = 100;
		if (meta.timeChanges != null)
		{
			var tcs:Array<Dynamic> = cast meta.timeChanges;
			if (tcs.length > 0 && tcs[0].bpm != null)
				bpm = tcs[0].bpm;
		}
		var stepCrochet:Float = (60.0 / bpm * 1000.0) / 4.0;

		var speed:Float = 2.0;
		if (chart.scrollSpeed != null && Reflect.hasField(chart.scrollSpeed, diffKey))
			speed = Reflect.field(chart.scrollSpeed, diffKey);

		var rawNotes:Array<Dynamic> = [];
		if (chart.notes != null && Reflect.hasField(chart.notes, diffKey))
			rawNotes = cast Reflect.field(chart.notes, diffKey);

		if (rawNotes.length == 0)
			trace('[FNFCLoader] WARNING: no notes found for diffKey="$diffKey" — chart may be empty!');

		var maxTime:Float = 0;
		for (n in rawNotes)
		{
			var endMs:Float = (n.t : Float) + (n.l : Float);
			if (endMs > maxTime) maxTime = endMs;
		}

		var totalSections:Int = Std.int(Math.ceil(maxTime / (16.0 * stepCrochet))) + 2;
		var sectionFocus:Array<Bool> = parseCameraEvents(chart.events, stepCrochet, totalSections);

		// Pre-allocate sections array
		var sections:Array<SwagSection> = new Array();
		sections.resize(totalSections);
		for (i in 0...totalSections)
		{
			sections[i] = cast {
				sectionNotes  : ([] : Array<Dynamic>),
				lengthInSteps : 16,
				typeOfSection : 0,
				mustHitSection: sectionFocus[i],
				bpm           : bpm,
				changeBPM     : false,
				altAnim       : false
			};
		}

		// Precompute inverse section duration to avoid repeated division in the loop
		var invSectionMs:Float = 1.0 / (16.0 * stepCrochet);
		var lastSectionIdx:Int = sections.length - 1;

		for (rawNote in rawNotes)
		{
			var t:Float       = rawNote.t;
			var d:Int         = Std.int(rawNote.d);
			var l:Float       = rawNote.l;
			var isPlayer:Bool = (d < 4);

			var sIdx:Int = Std.int(t * invSectionMs);
			if (sIdx < 0)              sIdx = 0;
			if (sIdx > lastSectionIdx) sIdx = lastSectionIdx;

			var sec = sections[sIdx];
			var legacyData:Int = sec.mustHitSection
				? d
				: (isPlayer ? (d + 4) : (d - 4));

			sec.sectionNotes.push([t, legacyData, l]);
		}

		var player1 = "bf";
		var player2 = "dad";
		if (meta.playData != null && meta.playData.characters != null)
		{
			var chars:Dynamic = meta.playData.characters;
			if (chars.player   != null) player1 = Std.string(chars.player);
			if (chars.opponent != null) player2 = Std.string(chars.opponent);
		}

		var songDisplayName:String = id.charAt(0).toUpperCase() + id.substr(1).toLowerCase();

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

	static function parseCameraEvents(events:Dynamic, stepCrochet:Float, totalSections:Int):Array<Bool>
	{
		var sectionMs:Float = 16.0 * stepCrochet;
		var result:Array<Bool> = [for (_ in 0...totalSections) true];

		if (events == null) return result;

		var arr:Array<Dynamic> = cast events;
		var focusEvents:Array<Dynamic> = arr.filter(function(e) return e.e == "FocusCamera");
		focusEvents.sort(function(a, b) return Reflect.compare(a.t, b.t));

		if (focusEvents.length == 0) return result;

		var ptr:Int = 0;
		var currentChar:Int = -1;

		for (s in 0...totalSections)
		{
			var midpoint:Float = (s + 0.5) * sectionMs;

			while (ptr < focusEvents.length)
			{
				if (focusEvents[ptr].t > midpoint) break;

				var v:Dynamic = focusEvents[ptr].v;
				if (Std.isOfType(v, Int) || Std.isOfType(v, Float))
					currentChar = Std.int(v);
				else if (Reflect.hasField(v, "char"))
					currentChar = Std.int(Reflect.field(v, "char"));
				ptr++;
			}

			result[s] = (currentChar == -1) ? true : (currentChar == 0);
		}

		return result;
	}

	// ══════════════════════════════════════════════════════════════════════════
	// VARIATION RESOLUTION
	// ══════════════════════════════════════════════════════════════════════════

	static function resolveVariation(entries:List<Entry>, id:String, difficulty:Int):String
	{
		if ((difficulty == 3 || difficulty == 4) && hasEntry(entries, id + "-metadata-erect.json"))
			return "erect";
		return "";
	}

	// ══════════════════════════════════════════════════════════════════════════
	// ZIP / FILE HELPERS
	// ══════════════════════════════════════════════════════════════════════════

	static function getEntries(songId:String):List<Entry>
	{
		#if sys
		if (zipCache.exists(songId)) return zipCache.get(songId);

		var path = getFnfcPath(songId);
		if (!FileSystem.exists(path))
			throw '[FNFCLoader] .fnfc not found: $path';

		var fi      = File.read(path, true);
		var entries = new Reader(fi).read();
		fi.close();

		zipCache.set(songId, entries);

		// Build O(1) name→entry index for this archive
		var idx:Map<String, Entry> = new Map();
		for (e in entries)
			idx.set(e.fileName, e);
		entryIndexCache.set(songId, idx);

		trace('[FNFCLoader] Loaded zip: $path  (${Lambda.count(entries)} entries)');
		return entries;
		#else
		throw "[FNFCLoader] getEntries() is not supported on this platform.";
		return null;
		#end
	}

	// O(1) entry lookup via the index cache
	static function findEntry(songId:String, fileName:String):Entry
	{
		#if sys
		var idx = entryIndexCache.get(songId);
		if (idx != null) return idx.get(fileName);
		#end
		return null;
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

	public static function getFnfcPath(songId:String):String
		return FNFC_ASSET_DIR + songId + "/" + songId + ".fnfc";

	#if sys
	static function deleteDirRecursive(path:String):Void
	{
		if (!FileSystem.exists(path)) return;
		if (FileSystem.isDirectory(path))
		{
			for (entry in FileSystem.readDirectory(path))
				deleteDirRecursive(path + "/" + entry);
			try { FileSystem.deleteDirectory(path); } catch (e:Dynamic) {}
		}
		else
		{
			try { FileSystem.deleteFile(path); } catch (e:Dynamic) {}
		}
	}
	#end
}
