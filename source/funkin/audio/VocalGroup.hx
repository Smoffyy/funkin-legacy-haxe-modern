package funkin.audio;

import flixel.FlxG;
import flixel.sound.FlxSound;

/**
 * A set of vocal tracks driven as one.
 *
 * Legacy songs ship a single `Voices` file, modern bundles ship one per character, so
 * the playfield talks to this instead of a bare `FlxSound` and stays unaware of which
 * kind of song is running.
 */
class VocalGroup
{
	public var tracks(default, null):Array<FlxSound> = [];
	public var onComplete:Void->Void;

	public var volume(default, set):Float = 1;
	public var time(get, set):Float;
	public var length(get, never):Float;
	public var playing(get, never):Bool;

	public function new()
	{
	}

	public function add(sound:FlxSound):Void
	{
		if (sound == null)
			return;

		sound.volume = volume;
		sound.onComplete = trackComplete;

		tracks.push(sound);
		FlxG.sound.list.add(sound);
	}

	public function play(forceRestart:Bool = false, startTime:Float = 0):Void
	{
		for (track in tracks)
			track.play(forceRestart, startTime);
	}

	public function pause():Void
	{
		for (track in tracks)
			track.pause();
	}

	public function stop():Void
	{
		for (track in tracks)
			track.stop();
	}

	public function destroy():Void
	{
		for (track in tracks)
		{
			FlxG.sound.list.remove(track, true);
			track.destroy();
		}

		tracks = [];
	}

	function trackComplete():Void
	{
		// The longest track decides when the vocals are done.
		for (track in tracks)
			if (track.playing)
				return;

		if (onComplete != null)
			onComplete();
	}

	function set_volume(value:Float):Float
	{
		volume = value;

		for (track in tracks)
			track.volume = value;

		return value;
	}

	function get_time():Float
	{
		return tracks.length == 0 ? 0 : tracks[0].time;
	}

	function set_time(value:Float):Float
	{
		for (track in tracks)
			track.time = value;

		return value;
	}

	function get_length():Float
	{
		var longest:Float = 0;

		for (track in tracks)
			if (track.length > longest)
				longest = track.length;

		return longest;
	}

	function get_playing():Bool
	{
		for (track in tracks)
			if (track.playing)
				return true;

		return false;
	}
}
