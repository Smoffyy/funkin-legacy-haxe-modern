package funkin.modern;

import flixel.tweens.FlxEase;

using StringTools;

/**
 * Translates modern (0.3+) asset ids into the ids this engine actually ships.
 *
 * Every lookup falls back to something that is guaranteed to exist, so a song that
 * references a stage, character or icon we don't have still boots instead of crashing.
 */
class ModernCompat
{
	public static inline var DEFAULT_STAGE:String = 'stage';

	static var STAGES:Map<String, String> = [
		'mainstage' => 'stage',
		'spookymansion' => 'spooky',
		'phillystreets' => 'philly',
		'phillyblazin' => 'philly',
		'limoride' => 'limo',
		'mallxmas' => 'mall',
		'mallevil' => 'mallEvil',
		'school' => 'school',
		'schoolevil' => 'schoolEvil',
		'tankmanbattlefield' => 'tank'
	];

	static var CHARACTERS:Map<String, String> = [
		'bf' => 'bf',
		'bf-christmas' => 'bf-christmas',
		'bf-car' => 'bf-car',
		'bf-pixel' => 'bf-pixel',
		'bf-holding-gf' => 'bf-holding-gf',
		'dad' => 'dad',
		'spooky' => 'spooky',
		'mom' => 'mom',
		'mom-car' => 'mom-car',
		'monster' => 'monster',
		'monster-christmas' => 'monster-christmas',
		'pico' => 'pico',
		'pico-player' => 'pico',
		'pico-playable' => 'pico',
		'pico-speaker' => 'pico-speaker',
		'senpai' => 'senpai',
		'senpai-angry' => 'senpai-angry',
		'spirit' => 'spirit',
		'parents-christmas' => 'parents-christmas',
		'tankman' => 'tankman',
		'gf' => 'gf',
		'gf-christmas' => 'gf-christmas',
		'gf-car' => 'gf-car',
		'gf-pixel' => 'gf-pixel',
		'gf-tankmen' => 'gf-tankmen',
		'nene' => 'gf'
	];

	static var ICONS:Map<String, String> = [
		'bf' => 'bf',
		'bf-pixel' => 'bf-pixel',
		'bf-old' => 'bf-old',
		'dad' => 'dad',
		'gf' => 'gf',
		'mom' => 'mom',
		'monster' => 'monster',
		'parents-christmas' => 'parents',
		'pico' => 'pico',
		'senpai' => 'senpai',
		'spirit' => 'spirit',
		'spooky' => 'spooky',
		'tankman' => 'tankman'
	];

	/**
	 * Modern stage id -> legacy stage id. Variant stages (`mainStageErect`, `spookyMansionErect`)
	 * have no art here, so they intentionally resolve to their plain counterpart.
	 */
	public static function stage(modernStage:String):String
	{
		if (modernStage == null)
			return DEFAULT_STAGE;

		var key = modernStage.toLowerCase();
		if (STAGES.exists(key))
			return STAGES.get(key);

		// Strip the known suffixes modern uses for re-skins of a stage we already have.
		for (suffix in ['erect', 'pico', 'dark', 'nightmare'])
		{
			if (key.endsWith(suffix))
			{
				var stripped = key.substr(0, key.length - suffix.length);
				if (STAGES.exists(stripped))
					return STAGES.get(stripped);
			}
		}

		return DEFAULT_STAGE;
	}

	/**
	 * Stage art is split across the week libraries, so a modern song has to point
	 * `Paths` at whichever week owns the stage it resolved to.
	 */
	public static function libraryForStage(legacyStage:String):String
	{
		return switch (legacyStage)
		{
			case 'spooky': 'week2';
			case 'philly': 'week3';
			case 'limo': 'week4';
			case 'mall' | 'mallEvil': 'week5';
			case 'school' | 'schoolEvil': 'week6';
			case 'tank': 'week7';
			default: 'shared';
		}
	}

	/**
	 * Modern character id -> legacy character id, falling back through the `-dark` / `-erect`
	 * style suffixes before settling on a sensible default for the slot.
	 */
	public static function character(modernCharacter:String, fallback:String):String
	{
		if (modernCharacter == null)
			return fallback;

		var key = modernCharacter.toLowerCase();
		if (CHARACTERS.exists(key))
			return CHARACTERS.get(key);

		// "spooky-dark" -> "spooky", "bf-dark-erect" -> "bf-dark" -> "bf"
		while (key.indexOf('-') != -1)
		{
			key = key.substr(0, key.lastIndexOf('-'));
			if (CHARACTERS.exists(key))
				return CHARACTERS.get(key);
		}

		return fallback;
	}

	public static function icon(character:String):String
	{
		if (character == null)
			return 'face';

		var key = character.toLowerCase();
		if (ICONS.exists(key))
			return ICONS.get(key);

		while (key.indexOf('-') != -1)
		{
			key = key.substr(0, key.lastIndexOf('-'));
			if (ICONS.exists(key))
				return ICONS.get(key);
		}

		return 'face';
	}

	/**
	 * `PlayAnimation` events address characters by slot name rather than by id.
	 */
	public static function animationTarget(target:String):String
	{
		if (target == null)
			return 'bf';

		return switch (target.toLowerCase())
		{
			case 'dad' | 'opponent': 'dad';
			case 'gf' | 'girlfriend': 'gf';
			default: 'bf';
		}
	}

	/**
	 * Resolves the modern ease name (`expoOut`, or `expo` + easeDir `Out`) to a flixel ease.
	 * `CLASSIC` and `INSTANT` have no tween at all and return null.
	 */
	public static function ease(name:String, ?direction:String):Float->Float
	{
		if (name == null)
			return FlxEase.linear;

		var key = name;
		if (direction != null && direction.length > 0)
			key += direction;

		switch (key.toUpperCase())
		{
			case 'CLASSIC' | 'INSTANT':
				return null;
			case 'LINEAR':
				return FlxEase.linear;
		}

		// FlxEase exposes every curve as a static field, so resolve by name and only
		// fall back to linear when the chart asks for something this flixel doesn't have.
		var resolved = Reflect.field(FlxEase, key);
		if (resolved == null)
			resolved = Reflect.field(FlxEase, key.charAt(0).toLowerCase() + key.substr(1));

		return Reflect.isFunction(resolved) ? cast resolved : FlxEase.linear;
	}
}
