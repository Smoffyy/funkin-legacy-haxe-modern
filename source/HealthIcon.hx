package;

import flixel.FlxSprite;
import flixel.util.FlxColor;

using StringTools;

class HealthIcon extends FlxSprite
{
	/**
	 * Used for FreeplayState! If you use it elsewhere, prob gonna annoying
	 */
	public var sprTracker:FlxSprite;

	var char:String = '';
	var isPlayer:Bool = false;
	
	public var iconColor:FlxColor = 0xFF66FF33;

	public function new(char:String = 'bf', isPlayer:Bool = false)
	{
		super();

		this.isPlayer = isPlayer;

		changeIcon(char);
		antialiasing = true;
		scrollFactor.set();
	}

	public var isOldIcon:Bool = false;

	public function swapOldIcon():Void
	{
		isOldIcon = !isOldIcon;

		if (isOldIcon)
			changeIcon('bf-old');
		else
			changeIcon(PlayState.SONG.player1);
	}

	public function changeIcon(newChar:String):Void
	{
		if (newChar != 'bf-pixel' && newChar != 'bf-old')
			newChar = newChar.split('-')[0].trim();

		if (newChar != char)
		{
			if (animation.getByName(newChar) == null)
			{
				loadGraphic(Paths.image('icons/icon-' + newChar), true, 150, 150);
				animation.add(newChar, [0, 1], 0, false, isPlayer);
			}
			animation.play(newChar);
			char = newChar;
			
			// Extract dominant color from the icon
			extractIconColor();
		}
	}
	
	function extractIconColor():Void
	{
		if (pixels == null)
		{
			iconColor = 0xFF66FF33; // Default color
			return;
		}
		
		// Sample pixels from the icon to find the dominant color
		var colorMap:Map<Int, Int> = new Map<Int, Int>();
		var mostCommonColor:Int = 0;
		var highestCount:Int = 0;
		
		// Sample every 4th pixel for performance (icons are 150x150)
		for (x in 0...Std.int(frameWidth))
		{
			for (y in 0...Std.int(frameHeight))
			{
				if (x % 4 == 0 && y % 4 == 0) // Sample 1/16th of pixels
				{
					var pixel:Int = pixels.getPixel32(x, y);
					var alpha:Int = (pixel >> 24) & 0xFF;
					
					// Skip transparent pixels
					if (alpha < 128)
						continue;
					
					// Skip very dark or very light colors
					var color:FlxColor = pixel;
					var brightness:Float = (color.red + color.green + color.blue) / 3;
					if (brightness < 50 || brightness > 230)
						continue;
					
					// Count this color
					if (!colorMap.exists(pixel))
						colorMap.set(pixel, 0);
					
					colorMap.set(pixel, colorMap.get(pixel) + 1);
					
					if (colorMap.get(pixel) > highestCount)
					{
						highestCount = colorMap.get(pixel);
						mostCommonColor = pixel;
					}
				}
			}
		}
		
		// If we found a good color, use it. Otherwise use default
		if (highestCount > 0)
			iconColor = mostCommonColor;
		else
			iconColor = 0xFF66FF33; // Default green
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 10, sprTracker.y - 30);
	}
}
