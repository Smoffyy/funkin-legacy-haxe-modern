package;

import Section.SwagSection;
import haxe.Json;
import haxe.format.JsonParser;
import lime.utils.Assets;

using StringTools;

typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;

	var player1:String;
	var player2:String;
	var validScore:Bool;
}

class Song
{
	public var song:String;
	public var notes:Array<SwagSection>;
	public var bpm:Float;
	public var needsVoices:Bool = true;
	public var speed:Float = 1;

	public var player1:String = 'bf';
	public var player2:String = 'dad';

	public function new(song, notes, bpm)
	{
		this.song = song;
		this.notes = notes;
		this.bpm = bpm;
	}

	/**
	 * Load song from JSON with automatic caching and Psych Engine support.
	 * Now also checks for a .fnfc file and uses FNFCLoader when one exists.
	 *
	 * @param jsonInput  The difficulty-suffixed song name, e.g. "bopeebo-hard"
	 * @param folder     The song folder / songId, e.g. "bopeebo"
	 */
	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		// ── FNFC check ────────────────────────────────────────────────────────
		// The `folder` parameter is always the bare songId (e.g. "bopeebo").
		// If a .fnfc exists for it, delegate entirely to FNFCLoader — it reads
		// the difficulty from PlayState.storyDifficulty (already set by the
		// menu before this function is called).
		if (folder != null && folder.length > 0)
		{
			var songId:String = folder.toLowerCase();
			if (FNFCLoader.exists(songId))
			{
				trace('[Song] .fnfc found for "$songId" — delegating to FNFCLoader.');
				return FNFCLoader.load(songId, PlayState.storyDifficulty);
			}
			if (FNFCLoader.isActive)
			{
				trace('[Song] No .fnfc for "$songId" but isActive was true — resetting FNFCLoader.');
				FNFCLoader.reset();
			}
		}

		// ── Legacy JSON path ──────────────────────────────────────────────────

		// Create a cache key from the inputs
		var cacheKey:String = (folder != null)
			? folder.toLowerCase() + "_" + jsonInput.toLowerCase()
			: jsonInput.toLowerCase();

		// Check if already cached
		var cachedData:Dynamic = AssetCacheManager.getCachedSongJson(cacheKey);
		if (cachedData != null && cachedData.song != null)
		{
			return parseJSONshit(Json.stringify(cachedData));
		}

		// Not cached, load normally
		var rawJson:String = Assets.getText(Paths.json(folder.toLowerCase() + '/' + jsonInput.toLowerCase())).trim();

		while (!rawJson.endsWith("}"))
		{
			rawJson = rawJson.substr(0, rawJson.length - 1);
		}

		// Check if this is a Psych Engine chart and convert if needed
		if (PsychEngineConverter.isPsychFormat(rawJson))
		{
			trace("=== Psych Engine Chart Detected ===");
			trace(PsychEngineConverter.getChartInfo(rawJson));
			trace("Converting to vanilla format...");
			rawJson = PsychEngineConverter.convertToVanilla(rawJson);
			trace("Conversion complete!");
		}

		// Parse the JSON
		var parsedJson:Dynamic = Json.parse(rawJson);

		// Cache it for next time
		AssetCacheManager.cacheSongJson(cacheKey, parsedJson);

		// Return the parsed song
		return parseJSONshit(Json.stringify(parsedJson));
	}

	/**
	 * Parse JSON string into SwagSong.
	 * Supports both vanilla and converted Psych Engine formats.
	 */
	public static function parseJSONshit(rawJson:String):SwagSong
	{
		var swagShit:SwagSong = cast Json.parse(rawJson).song;
		swagShit.validScore = true;
		return swagShit;
	}
}
