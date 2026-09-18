package;

import Section.SwagSection;
import haxe.Json;
import haxe.format.JsonParser;
import lime.utils.Assets;

using StringTools;

typedef SwagEvent =
{
	var time:Float;
	var kind:String;
	var value:Dynamic;
}

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

	/**
	 * Everything below is only populated for songs loaded out of a `.fnfc` bundle.
	 * Legacy charts leave them null and the engine keeps its original behaviour.
	 */
	@:optional var gfVersion:String;

	@:optional var stage:String;
	@:optional var events:Array<SwagEvent>;
	@:optional var modernId:String;
	@:optional var variation:String;
	@:optional var difficultyId:String;
	@:optional var instPath:String;
	@:optional var vocalPaths:Array<String>;
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

	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		var rawJson = Assets.getText(Paths.json(folder.toLowerCase() + '/' + jsonInput.toLowerCase())).trim();

		while (!rawJson.endsWith("}"))
		{
			rawJson = rawJson.substr(0, rawJson.length - 1);
			// LOL GOING THROUGH THE BULLSHIT TO CLEAN IDK WHATS STRANGE
		}

		return parseJSONshit(rawJson);
	}

	public static function parseJSONshit(rawJson:String):SwagSong
	{
		var swagShit:SwagSong = cast Json.parse(rawJson).song;
		swagShit.validScore = true;
		return swagShit;
	}

	public static inline function isModern(song:SwagSong):Bool
	{
		return song != null && song.modernId != null;
	}

	/**
	 * Lookup id for a song, which is the bundle id for modern songs and the lowercased
	 * title for legacy ones.
	 */
	public static inline function idOf(song:SwagSong):String
	{
		return song == null ? null : (song.modernId != null ? song.modernId : song.song.toLowerCase());
	}
}
