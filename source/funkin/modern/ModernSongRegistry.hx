package funkin.modern;

import funkin.modern.ModernSong.ModernVariation;
import funkin.modern.ModernSongData;
import haxe.Json;

#if sys
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

/**
 * Discovers `.fnfc` bundles under `assets/modern-data` and exposes them to the rest of
 * the engine.
 *
 * A bundle is a zip, so it is unpacked once into a cache directory and re-used from
 * there afterwards; that keeps chart parsing cheap and lets the audio stream off disk
 * instead of being decoded into memory. When the folder is empty (or this target has no
 * filesystem) the registry stays empty and every caller falls through to legacy loading.
 */
class ModernSongRegistry
{
	public static inline var FOLDER:String = 'fnfc';

	static inline var CACHE_FOLDER:String = 'modern-cache';
	static inline var STAMP_FILE:String = '.fnfc-stamp';

	public static var initialized(default, null):Bool = false;

	static var songs:Map<String, ModernSong> = new Map();
	static var songIds:Array<String> = [];

	public static function init():Void
	{
		if (initialized)
			return;

		initialized = true;

		#if sys
		try
		{
			scan();
		}
		catch (e:Dynamic)
		{
			// A malformed bundle must never take the game down, just fall back to legacy.
			trace('[modern] failed to scan ' + FOLDER + ': ' + e);
			songs = new Map();
			songIds = [];
		}
		#end
	}

	public static function isEmpty():Bool
	{
		init();
		return songIds.length == 0;
	}

	public static function exists(songId:String):Bool
	{
		init();
		return songId != null && songs.exists(songId.toLowerCase());
	}

	public static function get(songId:String):ModernSong
	{
		init();
		return songId == null ? null : songs.get(songId.toLowerCase());
	}

	public static function ids():Array<String>
	{
		init();
		return songIds.copy();
	}

	#if sys
	static function scan():Void
	{
		songs = new Map();
		songIds = [];

		var root = rootPath();
		if (!FileSystem.exists(root) || !FileSystem.isDirectory(root))
			return;

		var seen:Map<String, Bool> = new Map();

		for (entry in FileSystem.readDirectory(root))
		{
			var entryPath = Path.join([root, entry]);
			if (entry.startsWith('.'))
				continue;

			var folder:String = entry;
			var bundle:String = null;

			if (FileSystem.isDirectory(entryPath))
				bundle = findBundle(entryPath);
			else if (entry.toLowerCase().endsWith('.fnfc'))
			{
				folder = Path.withoutExtension(entry);
				bundle = entryPath;
			}

			if (bundle == null || seen.exists(folder.toLowerCase()))
				continue;

			seen.set(folder.toLowerCase(), true);

			try
			{
				var song = load(folder, bundle);
				if (song != null && song.variationOrder.length > 0)
				{
					songs.set(song.id, song);
					songIds.push(song.id);
				}
			}
			catch (e:Dynamic)
			{
				trace('[modern] skipping ' + bundle + ': ' + e);
			}
		}

		songIds.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
	}

	static function rootPath():String
	{
		var beside = Path.join([Path.directory(Sys.programPath()), FOLDER]);
		return FileSystem.exists(beside) ? beside : FOLDER;
	}

	static function findBundle(folderPath:String):String
	{
		for (file in FileSystem.readDirectory(folderPath))
		{
			if (file.toLowerCase().endsWith('.fnfc'))
				return Path.join([folderPath, file]);
		}

		return null;
	}

	static function load(folder:String, bundlePath:String):ModernSong
	{
		var cacheDir = Path.join([cacheRoot(), folder]);
		var stamp = stampFor(bundlePath);

		if (readStamp(cacheDir) != stamp)
		{
			deleteRecursive(cacheDir);
			FnfcArchive.extractTo(bundlePath, cacheDir);
			File.saveContent(Path.join([cacheDir, STAMP_FILE]), stamp);
		}

		var songId = folder.toLowerCase();
		var manifestPath = Path.join([cacheDir, 'manifest.json']);
		if (FileSystem.exists(manifestPath))
		{
			var manifest:Dynamic = Json.parse(File.getContent(manifestPath));
			if (manifest != null && manifest.songId != null)
				songId = Std.string(manifest.songId).toLowerCase();
		}

		var song = new ModernSong(songId, cacheDir);

		for (file in FileSystem.readDirectory(cacheDir))
		{
			var variationId = variationFromMetadataFile(file);
			if (variationId == null)
				continue;

			var metadata:ModernMetadata = Json.parse(File.getContent(Path.join([cacheDir, file])));
			if (metadata == null || metadata.playData == null)
				continue;

			var chartPath = Path.join([cacheDir, file.replace('-metadata', '-chart')]);
			if (!FileSystem.exists(chartPath))
				continue;

			var chart:ModernChart = Json.parse(File.getContent(chartPath));
			if (chart == null || chart.notes == null)
				continue;

			song.addVariation(new ModernVariation(variationId, metadata, chart));
		}

		return song;
	}

	/**
	 * `bopeebo-metadata.json` -> "default", `bopeebo-metadata-erect.json` -> "erect".
	 */
	static function variationFromMetadataFile(file:String):String
	{
		if (!file.endsWith('.json'))
			return null;

		var name = file.substr(0, file.length - 5);
		var marker = name.indexOf('-metadata');
		if (marker == -1)
			return null;

		var suffix = name.substr(marker + 9);
		if (suffix.length == 0)
			return ModernSong.DEFAULT_VARIATION;

		return suffix.startsWith('-') ? suffix.substr(1) : null;
	}

	static function cacheRoot():String
	{
		var root:String = CACHE_FOLDER;

		try
		{
			var storage = lime.system.System.applicationStorageDirectory;
			if (storage != null && storage.length > 0)
				root = Path.join([storage, CACHE_FOLDER]);
		}
		catch (_:Dynamic) {}

		if (!FileSystem.exists(root))
			FileSystem.createDirectory(root);

		return root;
	}

	static function stampFor(bundlePath:String):String
	{
		var stat = FileSystem.stat(bundlePath);
		return stat.size + ':' + stat.mtime.getTime();
	}

	static function readStamp(cacheDir:String):String
	{
		var path = Path.join([cacheDir, STAMP_FILE]);
		return FileSystem.exists(path) ? File.getContent(path) : null;
	}

	static function deleteRecursive(path:String):Void
	{
		if (!FileSystem.exists(path))
			return;

		if (!FileSystem.isDirectory(path))
		{
			FileSystem.deleteFile(path);
			return;
		}

		for (entry in FileSystem.readDirectory(path))
			deleteRecursive(Path.join([path, entry]));

		FileSystem.deleteDirectory(path);
	}

	static function audioPath(song:ModernSong, name:String):String
	{
		for (extension in ['ogg', 'mp3', 'wav'])
		{
			var path = Path.join([song.directory, name + '.' + extension]);
			if (FileSystem.exists(path))
				return path;
		}

		return null;
	}
	#end

	/**
	 * Absolute path of the instrumental for a variation, falling back to the base
	 * instrumental when the variation-specific one isn't in the bundle.
	 */
	public static function instrumentalPath(song:ModernSong, variationId:String):String
	{
		#if sys
		if (song == null)
			return null;

		var variation = song.get(variationId);
		var characters = variation == null ? null : variation.metadata.playData.characters;

		if (characters != null && characters.instrumental != null)
		{
			var path = audioPath(song, 'Inst-' + characters.instrumental);
			if (path != null)
				return path;
		}

		return audioPath(song, 'Inst');
		#else
		return null;
		#end
	}

	/**
	 * Every vocal track for a variation, opponent first. Missing tracks are dropped
	 * rather than treated as an error, so a bundle with no vocals still plays.
	 */
	public static function vocalPaths(song:ModernSong, variationId:String):Array<String>
	{
		var paths:Array<String> = [];

		#if sys
		if (song == null)
			return paths;

		var variation = song.get(variationId);
		if (variation == null || variation.metadata.playData.characters == null)
			return paths;

		var characters = variation.metadata.playData.characters;
		var wanted:Array<String> = [];

		pushAll(wanted, characters.opponentVocals, characters.opponent);
		pushAll(wanted, characters.playerVocals, characters.player);

		for (character in wanted)
		{
			var path = variationId == ModernSong.DEFAULT_VARIATION ? null : audioPath(song, 'Voices-' + character + '-' + variationId);
			if (path == null)
				path = audioPath(song, 'Voices-' + character);

			if (path != null && paths.indexOf(path) == -1)
				paths.push(path);
		}
		#end

		return paths;
	}

	static function pushAll(target:Array<String>, list:Array<String>, fallback:String):Void
	{
		if (list != null && list.length > 0)
		{
			for (item in list)
				if (item != null && target.indexOf(item) == -1)
					target.push(item);
		}
		else if (fallback != null && target.indexOf(fallback) == -1)
		{
			target.push(fallback);
		}
	}
}
