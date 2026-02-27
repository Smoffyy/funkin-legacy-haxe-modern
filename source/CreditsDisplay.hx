package;

import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.FlxG;
import flixel.util.FlxTimer;
import flixel.util.FlxGradient;

class CreditsDisplay
{
	public var bg:FlxSprite;
	public var titleText:FlxText;
	public var charterText:FlxText;
	public var artistText:FlxText;
	public var difficultyText:FlxText;
	public var accentBar:FlxSprite;
	
	private var pulseTween:FlxTween;

	public function new(charter:String, artist:String, difficulty:String)
	{
		// 1. Color Selection
		var diffColor:FlxColor = FlxColor.WHITE;
		var displayDiff = difficulty.toUpperCase();
		
		switch(displayDiff) {
			case "EASY": diffColor = 0xFF00FF00;
			case "NORMAL": diffColor = 0xFFFFFF00;
			case "HARD": diffColor = 0xFFFF0000;
			case "EXPERT": diffColor = 0xFFA858F7;
			default: diffColor = 0xFFFFFFFF;
		}

		bg = FlxGradient.createGradientFlxSprite(450, 155, [0x00000000, 0xFF000000], 1, 0);
		bg.x = FlxG.width; // Start off-screen to the right
		bg.y = FlxG.height * 0.72;
		bg.alpha = 0;

		accentBar = new FlxSprite(bg.x + 444, bg.y);
		accentBar.makeGraphic(6, 155, diffColor);

		titleText = new FlxText(bg.x + 25, bg.y + 15, 400, "NOW PLAYING", 18);
		titleText.setFormat(Paths.font("vcr.ttf"), 18, diffColor, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		
		charterText = new FlxText(bg.x + 25, bg.y + 45, 400, "Chart: " + (charter != "" ? charter : "Unknown"), 16);
		charterText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

		artistText = new FlxText(bg.x + 25, bg.y + 70, 400, "Music: " + (artist != "" ? artist : "Unknown"), 16);
		artistText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);

		difficultyText = new FlxText(bg.x + 25, bg.y + 105, 400, displayDiff + " «", 24);
		difficultyText.setFormat(Paths.font("vcr.ttf"), 24, diffColor, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		difficultyText.borderSize = 2;
	}

	public function show(displayTime:Float = 3.0):Void
	{
		var group:Array<FlxSprite> = [bg, accentBar, titleText, charterText, artistText, difficultyText];

		for (obj in group) {
			FlxTween.tween(obj, {x: obj.x - 450, alpha: (obj == bg ? 0.7 : 1)}, 0.8, {ease: FlxEase.elasticOut});
		}

		pulseTween = FlxTween.tween(difficultyText.scale, {x: 1.1, y: 1.1}, 0.5, {
			type: PINGPONG, 
			ease: FlxEase.sineInOut
		});

		new FlxTimer().start(displayTime, function(tmr:FlxTimer)
		{
			if (pulseTween != null) pulseTween.cancel();
			
			for (obj in group) {
				FlxTween.tween(obj, {x: obj.x + 450, alpha: 0}, 0.6, {ease: FlxEase.backIn});
			}
		});
	}
}