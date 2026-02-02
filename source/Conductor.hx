package;

import Song.SwagSong;
import flixel.FlxG;
import openfl.Lib;

/**
 * ...
 * @author
 */

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
	private static var interpolationStarted:Bool = false; // Track if interpolation has been initialized

	public function new()
	{
	}

	// Reset all timing variables - MUST be called when starting a new song
	public static function reset():Void
	{
		lastAudioTime = 0;
		lastFrameTime = 0;
		lastSongPos = 0;
		songPosition = 0;
		interpolationStarted = false; // Reset interpolation flag
	}

	 // Get interpolated song position for smooth note movement at any FPS
	 // COMPLETELY REWRITTEN for robustness

	public static function getInterpolatedPosition():Float
	{
		// Safety check: if music exists and is playing
		if (FlxG.sound.music != null && FlxG.sound.music.playing)
		{
			var currentMusicTime:Float = FlxG.sound.music.time;
			var currentTimer:Float = Lib.getTimer();
			
			// Initialize interpolation on first music update
			if (!interpolationStarted || currentMusicTime != lastAudioTime)
			{
				lastAudioTime = currentMusicTime;
				lastFrameTime = currentTimer;
				interpolationStarted = true;
				return currentMusicTime; // Return actual music time on initialization
			}
			
			// Calculate time elapsed since last audio update
			var timeSinceLastUpdate:Float = currentTimer - lastFrameTime;
			
			// Safety check: if too much time has passed, something went wrong - resync
			if (timeSinceLastUpdate > 100) // More than 100ms is suspicious
			{
				lastAudioTime = currentMusicTime;
				lastFrameTime = currentTimer;
				return currentMusicTime;
			}
			
			// Return interpolated position
			return lastAudioTime + timeSinceLastUpdate;
		}
		
		// Fallback to songPosition when music isn't playing
		return songPosition;
	}

	public static function mapBPMChanges(song:SwagSong)
	{
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
		trace("new BPM map BUDDY " + bpmChangeMap);
	}

	public static function changeBPM(newBpm:Float)
	{
		bpm = newBpm;

		crochet = ((60 / bpm) * 1000);
		stepCrochet = crochet / 4;
	}
}