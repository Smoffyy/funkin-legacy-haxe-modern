package funkin.audio;

import flixel.sound.FlxSound;
import lime.app.Future;
import openfl.media.Sound;
import openfl.utils.Assets as OpenFlAssets;

/**
 * Loads and keeps audio, whether it came from the asset libraries (legacy songs) or from
 * a file on disk (modern bundles, which are unpacked outside the asset system).
 *
 * Handing back the same `Sound` for a key means the second visit to a song, and every
 * freeplay preview after the first, costs nothing.
 *
 * Opening a track is slow enough to drop a frame, so menus go through `loadAsync`, which
 * does the work on a background thread. `resolve` is the blocking version and is only for
 * places that already have the player waiting, like starting a song.
 */
class AudioCache
{
	static var sounds:Map<String, Sound> = new Map();
	static var pending:Map<String, Array<Sound->Void>> = new Map();

	/**
	 * Blocks until the track is ready. Never throws, so a bundle missing a file degrades
	 * to silence instead of a crash.
	 */
	public static function resolve(key:String):Sound
	{
		if (key == null)
			return null;

		if (sounds.exists(key))
			return sounds.get(key);

		var sound = isAssetId(key) ? loadAsset(key) : loadFile(key);
		sounds.set(key, sound);

		return sound;
	}

	/**
	 * Loads off the main thread and calls back once the track is ready, immediately if it
	 * already is. Several requests for the same key share one load.
	 *
	 * Without a worker thread (or a path the loader can reach) this falls back to loading
	 * inline, so the callback still always fires.
	 */
	public static function loadAsync(key:String, ?onReady:Sound->Void):Void
	{
		if (key == null)
			return;

		if (sounds.exists(key))
		{
			if (onReady != null)
				onReady(sounds.get(key));

			return;
		}

		if (pending.exists(key))
		{
			if (onReady != null)
				pending.get(key).push(onReady);

			return;
		}

		var path = physicalPath(key);

		if (path == null)
		{
			var sound = resolve(key);
			if (onReady != null)
				onReady(sound);

			return;
		}

		pending.set(key, onReady == null ? [] : [onReady]);

		// Reading and decoding the header is all that happens here, and it touches nothing
		// the main thread owns. lime dispatches the result back on the main thread.
		new Future<Sound>(function() return loadFile(path), true).onComplete(function(sound) finish(key, sound))
			.onError(function(_) finish(key, null));
	}

	public static function isReady(key:String):Bool
	{
		return key != null && sounds.exists(key);
	}

	public static function loadSound(key:String):FlxSound
	{
		var sound = resolve(key);
		return sound == null ? new FlxSound() : new FlxSound().loadEmbedded(sound);
	}

	public static function clear():Void
	{
		sounds = new Map();
		pending = new Map();
	}

	static function finish(key:String, sound:Sound):Void
	{
		sounds.set(key, sound);

		var waiting = pending.get(key);
		pending.remove(key);

		if (waiting != null)
			for (callback in waiting)
				callback(sound);
	}

	static inline function isAssetId(key:String):Bool
	{
		return OpenFlAssets.exists(key, SOUND) || OpenFlAssets.exists(key, MUSIC);
	}

	static function loadAsset(key:String):Sound
	{
		try
		{
			return OpenFlAssets.getSound(key);
		}
		catch (e:Dynamic)
		{
			trace('[audio] could not load asset ' + key + ': ' + e);
			return null;
		}
	}

	static function loadFile(path:String):Sound
	{
		#if sys
		try
		{
			if (sys.FileSystem.exists(path))
				return Sound.fromFile(path);
		}
		catch (e:Dynamic)
		{
			trace('[audio] could not load ' + path + ': ' + e);
		}
		#end

		return null;
	}

	/**
	 * The file a key ultimately reads from, which is what the background load needs.
	 * Null when the key isn't backed by a file this target can open directly.
	 */
	static function physicalPath(key:String):String
	{
		#if sys
		if (sys.FileSystem.exists(key))
			return key;

		var path = OpenFlAssets.getPath(key);
		if (path != null && sys.FileSystem.exists(path))
			return path;
		#end

		return null;
	}
}
