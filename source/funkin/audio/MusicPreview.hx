package funkin.audio;

import flixel.FlxG;
import flixel.sound.FlxSound;
import openfl.media.Sound;

/**
 * Crossfading preview player for menus.
 *
 * Scrolling through freeplay used to stop the music, decode the next instrumental and
 * start it again, which both cut the audio and hitched the frame. Here the request is
 * debounced, the decode result is cached, and the outgoing track fades out underneath
 * the incoming one so skipping through songs stays continuous.
 */
class MusicPreview
{
	public var volume:Float = 0.7;

	var fadeTime:Float;
	var debounce:Float;

	var currentKey:String;
	var current:FlxSound;
	var retiring:Array<FlxSound> = [];

	var pendingKey:String;
	var pendingKeepPosition:Bool = false;
	var pendingTimer:Float = -1;
	var generation:Int = 0;

	public function new(fadeTime:Float = 0.4, debounce:Float = 0.12)
	{
		this.fadeTime = fadeTime;
		this.debounce = debounce;
	}

	/**
	 * Queues a track. Nothing is loaded until the selection has settled for `debounce`
	 * seconds, so holding a direction through ten songs only ever loads the last one.
	 *
	 * `keepPosition` starts the incoming track at the outgoing one's playhead instead of
	 * from the beginning, which is what makes switching between variations of the same
	 * song sound like one continuous take rather than a restart.
	 */
	public function request(key:String, keepPosition:Bool = false):Void
	{
		if (key == null || key == currentKey)
		{
			pendingKey = null;
			pendingTimer = -1;
			return;
		}

		pendingKey = key;
		pendingKeepPosition = keepPosition;
		pendingTimer = debounce;
	}

	public function update(elapsed:Float):Void
	{
		if (pendingTimer >= 0)
		{
			pendingTimer -= elapsed;
			if (pendingTimer < 0)
			{
				var key = pendingKey;
				pendingKey = null;
				load(key, pendingKeepPosition);
			}
		}

		var index = retiring.length;
		while (index-- > 0)
		{
			var sound = retiring[index];
			if (!sound.playing || sound.volume <= 0)
			{
				retiring.splice(index, 1);
				discard(sound);
			}
		}
	}

	public function stop(fade:Bool = true):Void
	{
		pendingKey = null;
		pendingTimer = -1;
		currentKey = null;
		generation++;

		if (current == null)
			return;

		retire(current, fade);
		current = null;
	}

	public function destroy():Void
	{
		stop(false);

		for (sound in retiring)
			discard(sound);

		retiring = [];
	}

	function load(key:String, keepPosition:Bool):Void
	{
		if (key == null || key == currentKey)
			return;

		currentKey = key;
		var token = ++generation;

		// Always go through the background loader. Opening a track costs a frame or more,
		// and doing that inline is what made scrolling the song list stutter.
		AudioCache.loadAsync(key, function(sound:Sound) start(sound, token, keepPosition));
	}

	function start(sound:Sound, token:Int, keepPosition:Bool):Void
	{
		// The player scrolled on while this was loading, so throw the result away.
		if (token != generation || sound == null)
			return;

		// Read the playhead before the outgoing track is handed over to the fade.
		var startTime:Float = (keepPosition && current != null) ? current.time : 0;

		if (current != null)
		{
			retire(current, true);
			current = null;
		}

		var next = new FlxSound().loadEmbedded(sound, true);

		// Variations of a song differ in length, so a position past the end of the incoming
		// track would silently refuse to play.
		if (next.length > 0 && startTime >= next.length)
			startTime = 0;

		next.volume = 0;
		FlxG.sound.list.add(next);
		next.play(false, startTime);
		next.fadeIn(fadeTime, 0, volume);

		current = next;
	}

	function retire(sound:FlxSound, fade:Bool):Void
	{
		if (fade && sound.playing)
		{
			sound.fadeOut(fadeTime, 0);
			retiring.push(sound);
			return;
		}

		discard(sound);
	}

	function discard(sound:FlxSound):Void
	{
		if (sound.fadeTween != null)
			sound.fadeTween.cancel();

		sound.stop();
		FlxG.sound.list.remove(sound, true);
		sound.destroy();
	}
}
