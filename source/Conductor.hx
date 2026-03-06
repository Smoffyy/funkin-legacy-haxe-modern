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
	public static var crochet:Float = ((60 / bpm) * 1000); // beats in milliseconds
	public static var stepCrochet:Float = crochet / 4; // steps in milliseconds
	public static var songPosition:Float;
	public static var lastSongPos:Float;
	public static var offset:Float = 0;

	public static var safeFrames:Int = 10;
	public static var safeZoneOffset:Float = (safeFrames / 60) * 1000;

	public static var bpmChangeMap:Array<BPMChangeEvent> = [];

	// Interpolation variables
	private static var lastAudioTime:Float = 0;
	private static var lastFrameTime:Float = 0;
	private static var interpolationStarted:Bool = false;
	
	// Cache for BPM maps
	private static var bpmMapCache:Map<String, Array<BPMChangeEvent>> = new Map<String, Array<BPMChangeEvent>>();

	public function new()
	{
	}

	/**
	 * Reset all timing variables - MUST be called when starting a new song
	 */
	public static function reset():Void
	{
		lastAudioTime = 0;
		lastFrameTime = 0;
		lastSongPos = 0;
		songPosition = 0;
		interpolationStarted = false;
	}

	public static function resetInterpolation():Void
	{
		lastAudioTime = 0;
		lastFrameTime = 0;
		interpolationStarted = false;
	}

	public static function getInterpolatedPosition():Float
	{
		// Check if interpolation is enabled in preferences
		if (!ui.PreferencesMenu.getPref('interpolation'))
		{
			// Interpolation disabled - return songPosition directly
			return songPosition;
		}
		
		// Interpolation enabled - use high FPS interpolation
		// Safety check: if music exists and is playing
		if (FlxG.sound.music != null && FlxG.sound.music.playing)
		{
			var currentMusicTime:Float = FlxG.sound.music.time;
			var currentTimer:Float = Lib.getTimer();
			
			// Sync audio anchor whenever the audio clock ticks forward
			if (!interpolationStarted || currentMusicTime != lastAudioTime)
			{
				lastAudioTime = currentMusicTime;
				lastFrameTime = currentTimer;
				interpolationStarted = true;
				return currentMusicTime;
			}
			
			var timeSinceLastUpdate:Float = currentTimer - lastFrameTime;
			
			// Sanity clamp: never extrapolate more than one audio callback period (~22ms)
			if (timeSinceLastUpdate < 0 || timeSinceLastUpdate > 22)
				timeSinceLastUpdate = 0;
			
			var interpolatedPos:Float = lastAudioTime + timeSinceLastUpdate;
			
			// Hard resync if we drift more than 50ms from real audio time
			if (Math.abs(interpolatedPos - currentMusicTime) > 50)
			{
				lastAudioTime = currentMusicTime;
				lastFrameTime = currentTimer;
				return currentMusicTime;
			}
			
			return interpolatedPos;
		}
		else
		{
			// Music is not playing - reset interpolation state
			resetInterpolation();
		}
		
		// Fallback to songPosition when music isn't playing
		return songPosition;
	}

	public static function mapBPMChanges(song:SwagSong)
	{
		// Check cache first
		var cacheKey:String = song.song.toLowerCase();
		if (bpmMapCache.exists(cacheKey))
		{
			bpmChangeMap = bpmMapCache.get(cacheKey).copy();
			trace("[Conductor] Loaded BPM map from cache for: " + song.song);
			return;
		}
		
		bpmChangeMap = [];

		var curBPM:Float = song.bpm;
		var totalSteps:Int = 0;
		var totalPos:Float = 0;
		for (i in 0...song.notes.length)
		{
			if(song.notes[i].changeBPM && song.notes[i].bpm != curBPM)
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
		
		// Cache the BPM map
		bpmMapCache.set(cacheKey, bpmChangeMap.copy());
		
		trace("[Conductor] Mapped BPM changes for: " + song.song);
	}

	/**
	 * Change current BPM and update timing variables
	 */
	public static function changeBPM(newBpm:Float)
	{
		bpm = newBpm;

		crochet = ((60 / bpm) * 1000);
		stepCrochet = crochet / 4;
	}
	
	/**
	 * Clear BPM cache (use when switching songs)
	 */
	public static function clearBPMCache():Void
	{
		bpmMapCache.clear();
		trace("[Conductor] BPM cache cleared");
	}
}
