package;

import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.FlxG;
import flixel.util.FlxTimer;

class CreditsDisplay
{
	public var bg:FlxSprite;
	public var titleText:FlxText;
	public var charterText:FlxText;
	public var artistText:FlxText;
	public var difficultyText:FlxText;

	public function new(charter:String, artist:String, difficulty:String)
	{
		// Background
		bg = new FlxSprite(0, 0);
		bg.makeGraphic(400, 180, 0xFF000000);
		bg.alpha = 0.8;
		bg.screenCenter();
		bg.y = FlxG.height * 0.20;

		// Title
		titleText = new FlxText(0, 0, 400, "SONG CREDITS", 24);
		titleText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		titleText.borderSize = 2;
		titleText.x = bg.x;
		titleText.y = bg.y + 10;

		// Charter
		charterText = new FlxText(0, 0, 400, "Charter: " + (charter != "" ? charter : "Unknown"), 16);
		charterText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		charterText.borderSize = 1;
		charterText.x = bg.x;
		charterText.y = bg.y + 50;

		// Artist
		artistText = new FlxText(0, 0, 400, "Artist: " + (artist != "" ? artist : "Unknown"), 16);
		artistText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		artistText.borderSize = 1;
		artistText.x = bg.x;
		artistText.y = bg.y + 75;

		// Difficulty
		difficultyText = new FlxText(0, 0, 400, "Difficulty: " + difficulty, 14);
		difficultyText.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.YELLOW, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		difficultyText.borderSize = 1;
		difficultyText.x = bg.x;
		difficultyText.y = bg.y + 110;
	}

	public function show(displayTime:Float = 3.0):Void
	{
		// Fade in
		bg.alpha = 0;
		titleText.alpha = 0;
		charterText.alpha = 0;
		artistText.alpha = 0;
		difficultyText.alpha = 0;

		FlxTween.tween(bg, {alpha: 0.8}, 0.5, {ease: FlxEase.quadOut});
		FlxTween.tween(titleText, {alpha: 1}, 0.5, {ease: FlxEase.quadOut});
		FlxTween.tween(charterText, {alpha: 1}, 0.5, {ease: FlxEase.quadOut});
		FlxTween.tween(artistText, {alpha: 1}, 0.5, {ease: FlxEase.quadOut});
		FlxTween.tween(difficultyText, {alpha: 1}, 0.5, {ease: FlxEase.quadOut});

		// Fade out after displayTime
		new FlxTimer().start(displayTime, function(tmr:FlxTimer)
		{
			FlxTween.tween(bg, {alpha: 0}, 0.5, {ease: FlxEase.quadIn});
			FlxTween.tween(titleText, {alpha: 0}, 0.5, {ease: FlxEase.quadIn});
			FlxTween.tween(charterText, {alpha: 0}, 0.5, {ease: FlxEase.quadIn});
			FlxTween.tween(artistText, {alpha: 0}, 0.5, {ease: FlxEase.quadIn});
			FlxTween.tween(difficultyText, {alpha: 0}, 0.5, {ease: FlxEase.quadIn});
		});
	}
}
