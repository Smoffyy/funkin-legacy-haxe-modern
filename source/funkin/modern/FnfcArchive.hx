package funkin.modern;

#if sys
import haxe.io.Bytes;
import haxe.io.Path;
import haxe.zip.Entry;
import haxe.zip.Reader;
import sys.FileSystem;
import sys.io.File;

using StringTools;

class FnfcArchive
{
	public static function extractTo(archivePath:String, destDir:String):Array<String>
	{
		var written:Array<String> = [];
		var input = File.read(archivePath, true);

		try
		{
			var entries:List<Entry> = Reader.readZip(input);
			input.close();

			ensureDir(destDir);

			for (entry in entries)
			{
				if (entry.fileName == null || entry.fileName.length == 0 || entry.fileName.endsWith('/'))
					continue;

				var target = Path.join([destDir, entry.fileName]);
				ensureDir(Path.directory(target));

				var data:Bytes = Reader.unzip(entry);
				if (data == null)
					continue;

				File.saveBytes(target, data);
				written.push(entry.fileName);
			}
		}
		catch (e:Dynamic)
		{
			try
				input.close()
			catch (_:Dynamic) {}
			throw e;
		}

		return written;
	}

	public static function ensureDir(dir:String):Void
	{
		if (dir == null || dir.length == 0 || FileSystem.exists(dir))
			return;

		FileSystem.createDirectory(dir);
	}
}
#end
