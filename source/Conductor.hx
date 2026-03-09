package;

import Song.SwagSong;
import flixel.FlxG;
import openfl.Lib;

typedef BPMChangeEvent =
{
	var stepTime:Int;
	var songTime:Float;
	var bpm:Float;
}

class Conductor
{
	public static var bpm:Float = 100;
	public static var crochet:Float = ((60 / bpm) * 1000);
	public static var stepCrochet:Float = crochet / 4;
	public static var songPosition:Float;
	public static var lastSongPos:Float;
	public static var offset:Float = 0;

	// Computed once per frame by PlayState, all per-note logic reads this
	public static var framePosition:Float = 0;

	public static var safeFrames:Int = 10;
	public static var safeZoneOffset:Float = (safeFrames / 60) * 1000;

	public static var bpmChangeMap:Array<BPMChangeEvent> = [];

	private static var lastAudioTime:Float = 0;
	private static var lastFrameTime:Float = 0;
	private static var interpolationStarted:Bool = false;

	// Cached so getPref isn't hit on every frame
	private static var _interpolationEnabled:Bool = true;

	private static var bpmMapCache:Map<String, Array<BPMChangeEvent>> = new Map<String, Array<BPMChangeEvent>>();

	public function new() {}

	public static function reset():Void
	{
		lastAudioTime = 0;
		lastFrameTime = 0;
		lastSongPos = 0;
		songPosition = 0;
		framePosition = 0;
		interpolationStarted = false;
		refreshInterpolationPref();
	}

	public static function resetInterpolation():Void
	{
		lastAudioTime = 0;
		lastFrameTime = 0;
		interpolationStarted = false;
	}

	// Call this whenever the framerate pref changes so the cache stays in sync
	public static function refreshInterpolationPref():Void
	{
		var fps:Int = ui.PreferencesMenu.getPref('framerate');
		_interpolationEnabled = (fps == 0 || fps > 60);
	}

	public static function getInterpolatedPosition():Float
	{
		if (!_interpolationEnabled)
			return songPosition;

		if (FlxG.sound.music != null && FlxG.sound.music.playing)
		{
			var currentMusicTime:Float = FlxG.sound.music.time;
			var currentTimer:Float = Lib.getTimer();

			if (!interpolationStarted || currentMusicTime != lastAudioTime)
			{
				lastAudioTime = currentMusicTime;
				lastFrameTime = currentTimer;
				interpolationStarted = true;
				return currentMusicTime;
			}

			var timeSinceLastUpdate:Float = currentTimer - lastFrameTime;

			if (timeSinceLastUpdate < 0 || timeSinceLastUpdate > 46)
				timeSinceLastUpdate = 0;

			var interpolatedPos:Float = lastAudioTime + timeSinceLastUpdate;

			if (Math.abs(interpolatedPos - currentMusicTime) > 75)
			{
				lastAudioTime = currentMusicTime;
				lastFrameTime = currentTimer;
				return currentMusicTime;
			}

			return interpolatedPos;
		}
		else
		{
			resetInterpolation();
		}

		return songPosition;
	}

	public static function mapBPMChanges(song:SwagSong)
	{
		var cacheKey:String = song.song.toLowerCase();
		if (bpmMapCache.exists(cacheKey))
		{
			bpmChangeMap = bpmMapCache.get(cacheKey).copy();
			return;
		}

		bpmChangeMap = [];

		var curBPM:Float = song.bpm;
		var totalSteps:Int = 0;
		var totalPos:Float = 0;
		for (i in 0...song.notes.length)
		{
			if (song.notes[i].changeBPM && song.notes[i].bpm != curBPM)
			{
				curBPM = song.notes[i].bpm;
				var event:BPMChangeEvent = {
					stepTime: totalSteps,
					songTime: totalPos,
					bpm: curBPM
				};
				bpmChangeMap.push(event);
			}

			var deltaSteps:Int = song.notes[i].lengthInSteps;
			totalSteps += deltaSteps;
			totalPos += ((60 / curBPM) * 1000 / 4) * deltaSteps;
		}

		bpmMapCache.set(cacheKey, bpmChangeMap.copy());
	}

	public static function changeBPM(newBpm:Float)
	{
		bpm = newBpm;
		crochet = ((60 / bpm) * 1000);
		stepCrochet = crochet / 4;
	}

	public static function clearBPMCache():Void
	{
		bpmMapCache.clear();
	}
}
