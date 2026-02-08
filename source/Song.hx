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
	 * Load song from JSON with automatic caching
	 * If cached, returns instant result
	 * If not cached, loads and caches for future use
	 * Supports both vanilla and Psych Engine JSON formats
	 */
	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
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

		// Parse the JSON
		var parsedJson:Dynamic = Json.parse(rawJson);
		
		// Normalize to vanilla format if needed
		var normalizedJson:Dynamic = normalizeJsonFormat(parsedJson);
		
		// Cache it for next time
		AssetCacheManager.cacheSongJson(cacheKey, normalizedJson);
		
		// Return the parsed song
		return parseJSONshit(Json.stringify(normalizedJson));
	}

	/**
	 * Detect and normalize JSON format to vanilla format
	 * Handles both vanilla and Psych Engine JSON formats
	 */
	private static function normalizeJsonFormat(rawData:Dynamic):Dynamic
	{
		var isVanillaFormat:Bool = false;
		var isPsychFormat:Bool = false;
		var songData:Dynamic = null;

		// Check if it's vanilla format (wrapped in "song" property)
		if (rawData.song != null && rawData.song.notes != null)
		{
			isVanillaFormat = true;
			songData = rawData.song;
		}
		// Check if it's Psych format (has "notes" at root and typically has "format" or "gfVersion")
		else if (rawData.notes != null && Std.is(rawData.notes, Array))
		{
			isPsychFormat = true;
			songData = rawData;
		}

		if (songData == null)
		{
			throw "Invalid chart format - cannot find 'notes' array";
		}

		// Normalize to vanilla format
		var vanillaData:Dynamic = {
			song: {
				song: songData.song != null ? songData.song : "Unknown",
				bpm: songData.bpm != null ? songData.bpm : 120,
				needsVoices: songData.needsVoices != null ? songData.needsVoices : true,
				player1: songData.player1 != null ? songData.player1 : "bf",
				player2: songData.player2 != null ? songData.player2 : "dad",
				speed: songData.speed != null ? songData.speed : 1,
				validScore: songData.validScore != null ? songData.validScore : true,
				notes: convertSections(songData.notes, isPsychFormat)
			}
		};

		return vanillaData;
	}

	/**
	 * Convert section array from Psych or vanilla format to vanilla format
	 * 
	 * In Psych Engine charts, note types mean:
	 * - 0-3 = Player notes
	 * - 4-7 = Opponent notes
	 * 
	 * Vanilla engine uses 0-3 for all notes, with mustHitSection determining the side
	 * 
	 * For duet sections (both player AND opponent notes):
	 * - Split into TWO sections
	 * - Player notes (0-3) → kept as 0-3 with mustHitSection=true (player plays)
	 * - Opponent notes (4-7) → converted to 0-3 with mustHitSection=false (opponent plays)
	 */
	private static function convertSections(sections:Array<Dynamic>, isPsychFormat:Bool):Array<SwagSection>
	{
		var convertedSections:Array<SwagSection> = [];

		for (section in sections)
		{
			if (!isPsychFormat)
			{
				// Vanilla format - no conversion needed
				var swagSection:SwagSection = {
					sectionNotes: section.sectionNotes,
					lengthInSteps: section.lengthInSteps != null ? section.lengthInSteps : 16,
					typeOfSection: section.typeOfSection != null ? section.typeOfSection : 0,
					mustHitSection: section.mustHitSection != null ? section.mustHitSection : true,
					bpm: section.bpm != null ? section.bpm : 0,
					changeBPM: section.changeBPM != null ? section.changeBPM : false,
					altAnim: section.altAnim != null ? section.altAnim : false
				};
				convertedSections.push(swagSection);
			}
			else
			{
				// Psych format - separate and convert player/opponent notes
				var allNotes:Array<Dynamic> = section.sectionNotes != null ? section.sectionNotes : [];
				var playerNotes:Array<Dynamic> = [];  // Psych 0-3
				var opponentNotes:Array<Dynamic> = [];  // Psych 4-7
				
				// Separate player (0-3) and opponent (4-7) notes
				for (note in allNotes)
				{
					if (Std.is(note, Array) && note.length >= 2)
					{
						var noteType:Int = Std.int(note[1]);
						
						// Psych: 0-3 are player, 4-7 are opponent
						if (noteType >= 0 && noteType <= 3)
						{
							playerNotes.push(note);
						}
						else if (noteType >= 4 && noteType <= 7)
						{
							opponentNotes.push(note);
						}
					}
				}
				
				var lengthInSteps:Int = section.sectionBeats != null 
					? Std.int(section.sectionBeats * 4) 
					: (section.lengthInSteps != null ? section.lengthInSteps : 16);
				
				var typeOfSection:Int = section.typeOfSection != null ? section.typeOfSection : 0;
				var bpm:Float = section.bpm != null ? section.bpm : 0;
				var changeBPM:Bool = section.changeBPM != null ? section.changeBPM : false;
				var altAnim:Bool = section.altAnim != null ? section.altAnim : false;
				
				// If BOTH player and opponent notes exist, split into two sections
				if (playerNotes.length > 0 && opponentNotes.length > 0)
				{
					// Player section first (mustHitSection=true, notes 0-3)
					var playerSection:SwagSection = {
						sectionNotes: playerNotes,
						lengthInSteps: lengthInSteps,
						typeOfSection: typeOfSection,
						mustHitSection: true,
						bpm: bpm,
						changeBPM: changeBPM,
						altAnim: altAnim
					};
					convertedSections.push(playerSection);
					
					// Convert opponent notes (4-7) to vanilla (0-3)
					var convertedOpponentNotes:Array<Dynamic> = [];
					for (note in opponentNotes)
					{
						if (Std.is(note, Array) && note.length >= 2)
						{
							var time:Float = note[0];
							var noteType:Int = Std.int(note[1]);
							var holdLength:Float = note.length > 2 ? note[2] : 0;
							
							var vanillaNoteType:Int = noteType - 4;  // 4->0, 5->1, 6->2, 7->3
							convertedOpponentNotes.push([time, vanillaNoteType, holdLength]);
						}
					}
					
					// Opponent section second (mustHitSection=false)
					var opponentSection:SwagSection = {
						sectionNotes: convertedOpponentNotes,
						lengthInSteps: lengthInSteps,
						typeOfSection: typeOfSection,
						mustHitSection: false,
						bpm: bpm,
						changeBPM: changeBPM,
						altAnim: altAnim
					};
					convertedSections.push(opponentSection);
				}
				// If only player notes (0-3)
				else if (playerNotes.length > 0)
				{
					var playerSection:SwagSection = {
						sectionNotes: playerNotes,
						lengthInSteps: lengthInSteps,
						typeOfSection: typeOfSection,
						mustHitSection: true,
						bpm: bpm,
						changeBPM: changeBPM,
						altAnim: altAnim
					};
					convertedSections.push(playerSection);
				}
				// If only opponent notes (4-7)
				else if (opponentNotes.length > 0)
				{
					// Convert opponent notes (4-7) to vanilla (0-3)
					var convertedOpponentNotes:Array<Dynamic> = [];
					for (note in opponentNotes)
					{
						if (Std.is(note, Array) && note.length >= 2)
						{
							var time:Float = note[0];
							var noteType:Int = Std.int(note[1]);
							var holdLength:Float = note.length > 2 ? note[2] : 0;
							
							var vanillaNoteType:Int = noteType - 4;
							convertedOpponentNotes.push([time, vanillaNoteType, holdLength]);
						}
					}
					
					var opponentSection:SwagSection = {
						sectionNotes: convertedOpponentNotes,
						lengthInSteps: lengthInSteps,
						typeOfSection: typeOfSection,
						mustHitSection: false,
						bpm: bpm,
						changeBPM: changeBPM,
						altAnim: altAnim
					};
					convertedSections.push(opponentSection);
				}
				// Empty section
				else
				{
					var emptySection:SwagSection = {
						sectionNotes: [],
						lengthInSteps: lengthInSteps,
						typeOfSection: typeOfSection,
						mustHitSection: true,
						bpm: bpm,
						changeBPM: changeBPM,
						altAnim: altAnim
					};
					convertedSections.push(emptySection);
				}
			}
		}

		return convertedSections;
	}

	/**
	 * Convert note array format from vanilla format
	 * (Psych conversion now handled in convertSections)
	 */
	private static function convertNotes(notes:Array<Dynamic>, isPsychFormat:Bool):Array<Dynamic>
	{
		// For vanilla format, return as-is
		if (!isPsychFormat)
		{
			return notes;
		}

		// Psych conversion is now handled in convertSections
		// This function kept for compatibility
		return notes;
	}

	/**
	 * Parse JSON string into SwagSong
	 * Now handles pre-normalized data
	 */
	public static function parseJSONshit(rawJson:String):SwagSong
	{
		var swagShit:SwagSong = cast Json.parse(rawJson).song;
		
		// validScore should always be set by normalizeJsonFormat
		// but ensure it's true if somehow not set
		swagShit.validScore = true;
		
		return swagShit;
	}
}
