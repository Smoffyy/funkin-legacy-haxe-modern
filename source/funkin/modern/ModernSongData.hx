package funkin.modern;

typedef ModernTimeChange =
{
	var t:Float;
	var bpm:Float;
	@:optional var b:Float;
	@:optional var n:Int;
	@:optional var d:Int;
	@:optional var bt:Array<Int>;
}

typedef ModernCharacters =
{
	@:optional var player:String;
	@:optional var girlfriend:String;
	@:optional var opponent:String;
	@:optional var instrumental:String;
	@:optional var altInstrumentals:Array<String>;
	@:optional var opponentVocals:Array<String>;
	@:optional var playerVocals:Array<String>;
}

typedef ModernPlayData =
{
	var difficulties:Array<String>;
	var characters:ModernCharacters;
	@:optional var songVariations:Array<String>;
	@:optional var stage:String;
	@:optional var noteStyle:String;
	@:optional var ratings:Dynamic;
	@:optional var album:String;
	@:optional var previewStart:Int;
	@:optional var previewEnd:Int;
}

typedef ModernMetadata =
{
	var songName:String;
	var playData:ModernPlayData;
	@:optional var version:String;
	@:optional var artist:String;
	@:optional var charter:String;
	@:optional var divisions:Int;
	@:optional var looped:Bool;
	@:optional var offsets:Dynamic;
	@:optional var timeChanges:Array<ModernTimeChange>;
	@:optional var generatedBy:String;
}

typedef ModernNote =
{
	var t:Float;
	var d:Int;
	@:optional var l:Float;
	@:optional var k:String;
}

typedef ModernEvent =
{
	var t:Float;
	var e:String;
	@:optional var v:Dynamic;
}

typedef ModernChart =
{
	var notes:Dynamic;
	@:optional var version:String;
	@:optional var scrollSpeed:Dynamic;
	@:optional var events:Array<ModernEvent>;
	@:optional var generatedBy:String;
}
