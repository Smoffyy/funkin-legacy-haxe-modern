package funkin.data;

import Song.SwagSong;
import funkin.modern.ModernChartConverter;
import funkin.modern.ModernSong;
import funkin.modern.ModernSongRegistry;
import openfl.utils.Assets as OpenFlAssets;

using StringTools;

/**
 * Single entry point for "give me the chart for this song at this difficulty".
 *
 * Every chart it hands out is parsed once and kept, so re-entering a song, restarting
 * from the pause menu or switching difficulty mid-song never pays for parsing again.
 * A song with a `.fnfc` bundle resolves through the modern registry; everything else
 * falls through to the legacy `assets/preload/data` charts exactly as before.
 */
class SongCache
{
	static var LEGACY_DIFFICULTIES:Array<String> = ['EASY', 'NORMAL', 'HARD'];

	static var charts:Map<String, SwagSong> = new Map();
	static var queue:Array<{id:String, difficulty:Int}> = [];

	/**
	 * Display names of every difficulty the song offers, in selection order.
	 * Modern songs contribute one entry per (variation, difficulty) pair.
	 */
	public static function difficultiesFor(songId:String):Array<String>
	{
		var modern = ModernSongRegistry.get(songId);
		if (modern == null)
			return LEGACY_DIFFICULTIES.copy();

		var names:Array<String> = [];
		for (difficulty in modern.listDifficulties())
			names.push(difficulty.displayName);

		return names.length == 0 ? LEGACY_DIFFICULTIES.copy() : names;
	}

	/**
	 * Loads a chart, preferring the cached copy. Returns null only when neither a modern
	 * bundle nor a legacy chart exists for the song, so callers can refuse to start it.
	 */
	public static function load(songId:String, difficulty:Int):SwagSong
	{
		var key = songId.toLowerCase() + ':' + difficulty;
		if (charts.exists(key))
			return charts.get(key);

		var chart = build(songId, difficulty);
		if (chart != null)
			charts.set(key, chart);

		return chart;
	}

	/**
	 * Queues every chart of every song for parsing. Warming happens a slice at a time via
	 * `stepPreload`, so the menu stays responsive instead of stalling on entry.
	 */
	public static function queuePreload(songIds:Array<String>):Void
	{
		queue = [];

		for (songId in songIds)
		{
			var count = difficultiesFor(songId).length;
			for (difficulty in 0...count)
			{
				if (!charts.exists(songId.toLowerCase() + ':' + difficulty))
					queue.push({id: songId, difficulty: difficulty});
			}
		}
	}

	/**
	 * Parses queued charts until the time budget for this frame runs out.
	 */
	public static function stepPreload(budgetMs:Float = 4):Void
	{
		if (queue.length == 0)
			return;

		var deadline = haxe.Timer.stamp() + (budgetMs / 1000);

		while (queue.length > 0 && haxe.Timer.stamp() < deadline)
		{
			var next = queue.shift();

			try
			{
				load(next.id, next.difficulty);
			}
			catch (e:Dynamic)
			{
				// A song with no chart at that difficulty is normal, skip it quietly.
			}
		}
	}

	public static function clear():Void
	{
		charts = new Map();
		queue = [];
	}

	static function build(songId:String, difficulty:Int):SwagSong
	{
		var modern = ModernSongRegistry.get(songId);

		if (modern != null)
		{
			var chart = buildModern(modern, difficulty);
			if (chart != null)
				return chart;
		}

		return buildLegacy(songId, difficulty);
	}

	static function buildModern(modern:ModernSong, difficulty:Int):SwagSong
	{
		var difficulties = modern.listDifficulties();
		if (difficulties.length == 0)
			return null;

		var index = difficulty < 0 ? 0 : (difficulty >= difficulties.length ? difficulties.length - 1 : difficulty);

		try
		{
			return ModernChartConverter.convert(modern, difficulties[index]);
		}
		catch (e:Dynamic)
		{
			trace('[modern] failed to convert ' + modern.id + ': ' + e);
			return null;
		}
	}

	static function buildLegacy(songId:String, difficulty:Int):SwagSong
	{
		var folder = songId.toLowerCase();
		var file = folder + (difficulty == 0 ? '-easy' : (difficulty == 2 ? '-hard' : ''));

		if (!OpenFlAssets.exists(Paths.json(folder + '/' + file)))
		{
			// Fall back to NORMAL so a song that only ships one chart still plays.
			file = folder;
			if (!OpenFlAssets.exists(Paths.json(folder + '/' + file)))
				return null;
		}

		return Song.loadFromJson(file, folder);
	}
}
