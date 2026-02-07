package;

import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.sound.FlxSound;
import haxe.Json;
import lime.utils.Assets;
import openfl.display.BitmapData;
import openfl.media.Sound;

using StringTools;

class AssetCacheManager
{
	private static var songJsonCache:Map<String, Dynamic> = new Map<String, Dynamic>();
	private static var soundCache:Map<String, Bool> = new Map<String, Bool>();
	private static var atlasCache:Map<String, FlxAtlasFrames> = new Map<String, FlxAtlasFrames>();
	private static var characterAnimCache:Map<String, FlxAtlasFrames> = new Map<String, FlxAtlasFrames>();
	private static var cacheStats:Map<String, Int> = new Map<String, Int>();
	
	public static function initialize():Void
	{
		trace("[AssetCacheManager] Initializing cache system...");
		clearAllCaches();
	}
	
	/**
	 * Called from Song.loadFromJson() to cache parsed data
	 */
	
	/**
	 * Cache a song JSON that was successfully loaded
	 * Called AFTER Song.loadFromJson parses the JSON
	 */
	public static function cacheSongJson(key:String, jsonData:Dynamic):Void
	{
		if (jsonData != null)
		{
			songJsonCache.set(key, jsonData);
			incrementCacheStat("songJson_cached");
		}
	}
	
	/**
	 * Get cached song JSON if available
	 */
	public static function getCachedSongJson(key:String):Dynamic
	{
		if (songJsonCache.exists(key))
		{
			incrementCacheStat("songJson_hits");
			return songJsonCache.get(key);
		}
		return null;
	}
	
	
	/**
	 * Cache a sound asset using FlxG.sound
	 */
	public static function getCachedSound(path:String):Bool
	{
		if (soundCache.exists(path))
		{
			incrementCacheStat("sound_hits");
			return true;
		}
		
		try
		{
			FlxG.sound.cache(path);
			soundCache.set(path, true);
			incrementCacheStat("sound_cached");
			return true;
		}
		catch (e:Dynamic)
		{
			return false;
		}
	}
	
	public static function preCacheSongAudio(songName:String, ?needsVoices:Bool = true):Void
	{
		try
		{
			var instPath:String = Paths.inst(songName);
			var vocalPath:String = Paths.voices(songName);
			
			// Cache instrumental
			FlxG.sound.cache(instPath);
			soundCache.set(instPath, true);
			
			// Cache vocals if needed
			if (needsVoices)
			{
				FlxG.sound.cache(vocalPath);
				soundCache.set(vocalPath, true);
			}
			
			incrementCacheStat("songAudio_preCached");
		}
		catch (e:Dynamic)
		{
			// Silently fail
		}
	}
	
	public static function getCachedAtlas(assetKey:String):FlxAtlasFrames
	{
		if (atlasCache.exists(assetKey))
		{
			incrementCacheStat("atlas_hits");
			return atlasCache.get(assetKey);
		}
		
		try
		{
			var atlas:FlxAtlasFrames = Paths.getSparrowAtlas(assetKey);
			atlasCache.set(assetKey, atlas);
			incrementCacheStat("atlas_cached");
			return atlas;
		}
		catch (e:Dynamic)
		{
			return null;
		}
	}
	
	/**
	 * Pre-cache character atlas frames
	 */
	public static function preCacheCharacterAssets(character:String):Void
	{
		try
		{
			var charKey:String = character.toLowerCase();
			var atlas:FlxAtlasFrames = getCachedAtlas(charKey);
			if (atlas != null)
			{
				characterAnimCache.set(charKey, atlas);
			}
			incrementCacheStat("character_preCached");
		}
		catch (e:Dynamic)
		{
			// Silently fail
		}
	}
	
	public static function preCacheCharacters(characters:Array<String>):Void
	{
		for (char in characters)
		{
			preCacheCharacterAssets(char);
		}
	}
	
	/**
	 * Pre-cache all stage-related assets
	 */
	public static function preCacheStageAssets(stage:String):Void
	{
		try
		{
			switch (stage.toLowerCase())
			{
				case 'spooky':
					getCachedAtlas('halloween_bg');
				case 'philly':
					getCachedAtlas('philly/win');
				case 'limo':
					getCachedAtlas('limo/bgLimo');
				case 'mall':
					getCachedAtlas('christmas/bgWalls');
				case 'school':
					getCachedAtlas('school_background');
					getCachedAtlas('schoolEventsKids');
				case 'tank':
					getCachedAtlas('tankRun');
					getCachedAtlas('tankman_tilemap');
			}
			incrementCacheStat("stage_assets_preCached");
		}
		catch (e:Dynamic)
		{
			// Silently fail
		}
	}
	
	public static function clearAllCaches():Void
	{
		songJsonCache.clear();
		soundCache.clear();
		atlasCache.clear();
		characterAnimCache.clear();
		
		trace("[AssetCacheManager] All caches cleared");
	}
	
	public static function clearSoundCache():Void
	{
		soundCache.clear();
		trace("[AssetCacheManager] Sound cache cleared");
	}
	
	public static function clearBitmapCache():Void
	{
		atlasCache.clear();
		trace("[AssetCacheManager] Atlas cache cleared");
	}
	
	public static function printCacheStats():Void
	{
		var jsonCount = 0;
		var atlasCount = 0;
		var soundCount = 0;
		
		for (key in songJsonCache.keys())
			jsonCount++;
		for (key in atlasCache.keys())
			atlasCount++;
		for (key in soundCache.keys())
			soundCount++;
		
		trace("========== CACHE STATISTICS ==========");
		trace("Song JSON cached: " + jsonCount);
		trace("Sounds cached: " + soundCount);
		trace("Atlases cached: " + atlasCount);
		trace("Characters cached: " + Lambda.count(characterAnimCache));
		
		trace("\n--- Hit/Cached Stats ---");
		for (key in cacheStats.keys())
		{
			trace(key + ": " + cacheStats.get(key));
		}
		trace("======================================");
	}
	
	/**
	 * Get total cache size estimate in MB
	 */
	public static function estimateCacheSize():Float
	{
		var jsonCount = 0;
		var atlasCount = 0;
		var soundCount = 0;
		
		for (key in songJsonCache.keys())
			jsonCount++;
		for (key in atlasCache.keys())
			atlasCount++;
		for (key in soundCache.keys())
			soundCount++;
		
		// Estimate: each sound ~2MB, atlas ~1MB, JSON ~0.1MB
		var soundSize:Float = soundCount * 2.0;
		var atlasSize:Float = atlasCount * 1.0;
		var jsonSize:Float = jsonCount * 0.1;
		
		return soundSize + atlasSize + jsonSize;
	}
	
	/**
	 * Pre-cache a complete week/set of songs
	 * NOTE: Only caches audio and characters, not JSON (which loads dynamically)
	 */
	public static function preloadWeek(songNames:Array<String>, characters:Array<String>, ?stageName:String):Void
	{
		trace("[AssetCacheManager] Pre-loading week: " + songNames.length + " songs");
		
		// Pre-cache all song audio
		for (songName in songNames)
		{
			preCacheSongAudio(songName);
		}
		
		// Pre-cache all characters
		preCacheCharacters(characters);
		
		// Pre-cache stage if provided
		if (stageName != null)
		{
			preCacheStageAssets(stageName);
		}
		
		trace("[AssetCacheManager] Week pre-load complete!");
	}
	
	private static function incrementCacheStat(statKey:String):Void
	{
		if (!cacheStats.exists(statKey))
		{
			cacheStats.set(statKey, 0);
		}
		cacheStats.set(statKey, cacheStats.get(statKey) + 1);
	}
}
