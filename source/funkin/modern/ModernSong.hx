package funkin.modern;

import funkin.modern.ModernSongData;

using StringTools;

/**
 * A (variation, difficulty) pair, which is what the legacy engine thinks of as "a difficulty".
 */
typedef ModernDifficulty =
{
	var variation:String;
	var difficulty:String;
	var displayName:String;
}

/**
 * One `<variation>` of a song: its metadata and its chart.
 */
class ModernVariation
{
	public var id:String;
	public var metadata:ModernMetadata;
	public var chart:ModernChart;

	public function new(id:String, metadata:ModernMetadata, chart:ModernChart)
	{
		this.id = id;
		this.metadata = metadata;
		this.chart = chart;
	}
}

/**
 * A song loaded out of a `.fnfc` bundle, with every variation it ships.
 */
class ModernSong
{
	public static inline var DEFAULT_VARIATION:String = 'default';

	public var id:String;
	public var directory:String;
	public var variations:Map<String, ModernVariation> = new Map();
	public var variationOrder:Array<String> = [];

	var difficultyCache:Array<ModernDifficulty>;

	public function new(id:String, directory:String)
	{
		this.id = id;
		this.directory = directory;
	}

	public function addVariation(variation:ModernVariation):Void
	{
		if (!variations.exists(variation.id))
		{
			if (variation.id == DEFAULT_VARIATION)
				variationOrder.unshift(variation.id);
			else
				variationOrder.push(variation.id);
		}

		variations.set(variation.id, variation);
		difficultyCache = null;
	}

	public function get(variation:String):ModernVariation
	{
		return variations.get(variation);
	}

	public var songName(get, never):String;

	function get_songName():String
	{
		var base = variations.get(DEFAULT_VARIATION);
		if (base == null && variationOrder.length > 0)
			base = variations.get(variationOrder[0]);

		return base == null ? id : base.metadata.songName;
	}

	/**
	 * Every playable (variation, difficulty) pair, flattened into the single list the
	 * legacy difficulty selector cycles through. The default variation comes first so
	 * indices 0/1/2 stay EASY/NORMAL/HARD, which keeps saved highscores meaningful.
	 */
	public function listDifficulties():Array<ModernDifficulty>
	{
		if (difficultyCache != null)
			return difficultyCache;

		difficultyCache = [];
		var seen:Map<String, Bool> = new Map();

		for (variationId in variationOrder)
		{
			var variation = variations.get(variationId);
			if (variation == null || variation.metadata.playData.difficulties == null)
				continue;

			for (difficulty in variation.metadata.playData.difficulties)
			{
				var display = difficulty.toUpperCase();
				if (variationId != DEFAULT_VARIATION && seen.exists(display))
					display = display + ' (' + variationId.toUpperCase() + ')';

				if (seen.exists(display))
					continue;

				seen.set(display, true);
				difficultyCache.push({variation: variationId, difficulty: difficulty, displayName: display});
			}
		}

		return difficultyCache;
	}

	public function findDifficulty(variation:String, difficulty:String):Int
	{
		var list = listDifficulties();
		for (i in 0...list.length)
		{
			if (list[i].variation == variation && list[i].difficulty == difficulty)
				return i;
		}

		return -1;
	}
}
