package;

import Song.SwagSong;
import flixel.FlxG;

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

	// Raw audio position. Always equals FlxG.sound.music.time + offset.
	// Used for beat/step timing, resync checks, and vocal sync — must stay accurate.
	public static var songPosition:Float = 0;
	public static var lastSongPos:Float;
	public static var offset:Float = 0;

	// Accumulated elapsed time since the last audio driver update.
	// Resets to 0 whenever songPosition receives a new value from the audio driver.
	// This fills the sub-frame gap between audio ticks at high framerates.
	private static var songPositionDelta:Float = 0;
	private static var prevSongPosition:Float = -999999;

	public static var safeFrames:Int = 10;
	public static var safeZoneOffset:Float = (safeFrames / 60) * 1000;

	public static var bpmChangeMap:Array<BPMChangeEvent> = [];

	private static var bpmMapCache:Map<String, Array<BPMChangeEvent>> = new Map<String, Array<BPMChangeEvent>>();

	public function new() {}

	public static function reset():Void
	{
		songPosition = 0;
		lastSongPos = 0;
		songPositionDelta = 0;
		prevSongPosition = -999999;
	}

	public static function resetInterpolation():Void
	{
		songPositionDelta = 0;
		prevSongPosition = songPosition;
	}

	// No longer needed — kept so existing call sites compile.
	public static function refreshInterpolationPref():Void {}

	/**
	 * Called every frame from PlayState.update() while the song is playing.
	 * Sets songPosition to the raw audio time, then advances songPositionDelta
	 * by elapsed time. When a new audio sample arrives (songPosition changed),
	 * the delta resets to 0.
	 *
	 * This matches how the official engine's Conductor.update() works:
	 * songPosition = authoritative audio time,
	 * songPositionDelta = sub-frame elapsed accumulator,
	 * getTimeWithDelta() = songPosition + songPositionDelta for smooth rendering.
	 */
	public static function updateSongPosition(elapsed:Float, rawMusicTime:Float):Void
	{
		songPosition = rawMusicTime;

		if (prevSongPosition != songPosition)
		{
			// New audio sample arrived — reset the accumulator.
			songPositionDelta = 0;
			prevSongPosition = songPosition;
		}
		else
		{
			// Audio driver hasn't ticked yet this frame — keep counting forward.
			songPositionDelta += elapsed * 1000;
		}
	}

	/**
	 * Returns a sub-frame-accurate position for note rendering and hit detection.
	 * Equivalent to the official engine's Conductor.instance.getTimeWithDelta().
	 *
	 * Use this everywhere notes are positioned or hit windows are evaluated.
	 * Use songPosition for beat/step timing and resync checks.
	 */
	public static function getTimeWithDelta():Float
	{
		return songPosition + songPositionDelta;
	}

	// framePosition is a computed value — reads getTimeWithDelta().
	// All existing note rendering and hit-detection code that reads framePosition
	// continues to work without changes.
	public static var framePosition(get, never):Float;
	static inline function get_framePosition():Float return getTimeWithDelta();

	// Legacy alias — kept so any remaining call sites compile.
	public static inline function getInterpolatedPosition():Float
	{
		return getTimeWithDelta();
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
