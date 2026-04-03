package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import shaderslmfao.ColorSwap;
import ui.PreferencesMenu;

using StringTools;

#if polymod
import polymod.format.ParseRules.TargetSignatureElement;
#end

class Note extends FlxSprite
{
	public var strumTime:Float = 0;

	public var mustPress:Bool = false;
	public var noteData:Int = 0;
	public var canBeHit:Bool = false;
	public var tooLate:Bool = false;
	public var wasGoodHit:Bool = false;

	public var canBeHitSnapshot:Bool = false;
	public var tooLateSnapshot:Bool = false;
	public var prevNote:Note;

	private var willMiss:Bool = false;

	public var altNote:Bool = false;
	public var invisNote:Bool = false;

	public var sustainLength:Float = 0;
	public var isSustainNote:Bool = false;

	public var colorSwap:ColorSwap;
	public var noteScore:Float = 1;

	public static var swagWidth:Float = 160 * 0.7;
	public static var PURP_NOTE:Int = 0;
	public static var GREEN_NOTE:Int = 2;
	public static var BLUE_NOTE:Int = 1;
	public static var RED_NOTE:Int = 3;

	public static var arrowColors:Array<Float> = [1, 1, 1, 1];

	// Cached once per song at Note construction time
	static var _isPixelStage:Bool = false;
	static var _lastStage:String = "";

	// Cached pref to avoid Map lookup every note update
	static var _downscroll:Bool = false;
	static var _prefsLoaded:Bool = false;

	public static function refreshStaticCache():Void
	{
		_lastStage = PlayState.curStage;
		_isPixelStage = _lastStage.startsWith("school");
		_downscroll = PreferencesMenu.getPref('downscroll');
		_prefsLoaded = true;
	}

	public function new(strumTime:Float, noteData:Int, ?prevNote:Note, ?sustainNote:Bool = false)
	{
		super();

		if (prevNote == null)
			prevNote = this;

		this.prevNote = prevNote;
		isSustainNote = sustainNote;

		y -= 2000;
		this.strumTime = strumTime;
		this.noteData = noteData;

		// Refresh static cache if stage changed
		if (!_prefsLoaded || _lastStage != PlayState.curStage)
			refreshStaticCache();

		if (_isPixelStage)
		{
			loadGraphic(Paths.image('weeb/pixelUI/arrows-pixels'), true, 17, 17);
			animation.add('greenScroll',  [6]);
			animation.add('redScroll',    [7]);
			animation.add('blueScroll',   [5]);
			animation.add('purpleScroll', [4]);

			if (isSustainNote)
			{
				loadGraphic(Paths.image('weeb/pixelUI/arrowEnds'), true, 7, 6);
				animation.add('purpleholdend', [4]);
				animation.add('greenholdend',  [6]);
				animation.add('redholdend',    [7]);
				animation.add('blueholdend',   [5]);
				animation.add('purplehold',    [0]);
				animation.add('greenhold',     [2]);
				animation.add('redhold',       [3]);
				animation.add('bluehold',      [1]);
			}

			setGraphicSize(Std.int(width * PlayState.daPixelZoom));
			updateHitbox();
		}
		else
		{
			frames = Paths.getSparrowAtlas('NOTE_assets');
			animation.addByPrefix('greenScroll',  'green instance');
			animation.addByPrefix('redScroll',    'red instance');
			animation.addByPrefix('blueScroll',   'blue instance');
			animation.addByPrefix('purpleScroll', 'purple instance');
			animation.addByPrefix('purpleholdend', 'purple end hold');
			animation.addByPrefix('greenholdend',  'green hold end');
			animation.addByPrefix('redholdend',    'red hold end');
			animation.addByPrefix('blueholdend',   'blue hold end');
			animation.addByPrefix('purplehold',    'purple hold piece');
			animation.addByPrefix('greenhold',     'green hold piece');
			animation.addByPrefix('redhold',       'red hold piece');
			animation.addByPrefix('bluehold',      'blue hold piece');

			setGraphicSize(Std.int(width * 0.7));
			updateHitbox();
			antialiasing = true;
		}

		colorSwap = new ColorSwap();
		shader = colorSwap.shader;
		updateColors();

		switch (noteData)
		{
			case 0: x += swagWidth * 0; animation.play('purpleScroll');
			case 1: x += swagWidth * 1; animation.play('blueScroll');
			case 2: x += swagWidth * 2; animation.play('greenScroll');
			case 3: x += swagWidth * 3; animation.play('redScroll');
		}

		if (isSustainNote && prevNote != null)
		{
			// noteScore * 0.2 was a no-op (result discarded) — removed
			alpha = 0.6;
			antialiasing = false;

			if (_downscroll)
				angle = 180;

			x += width / 2;

			switch (noteData)
			{
				case 2: animation.play('greenholdend');
				case 3: animation.play('redholdend');
				case 1: animation.play('blueholdend');
				case 0: animation.play('purpleholdend');
			}

			updateHitbox();
			x -= width / 2;

			if (_isPixelStage)
				x += 30;

			if (prevNote.isSustainNote)
			{
				switch (prevNote.noteData)
				{
					case 0: prevNote.animation.play('purplehold');
					case 1: prevNote.animation.play('bluehold');
					case 2: prevNote.animation.play('greenhold');
					case 3: prevNote.animation.play('redhold');
				}

				prevNote.scale.y *= Conductor.stepCrochet / 100 * 1.5 * PlayState.SONG.speed;
				prevNote.scale.y += 0.02;
				prevNote.updateHitbox();
			}
		}
	}

	public function updateColors():Void
	{
		colorSwap.update(arrowColors[noteData]);
	}

	public function desaturate():Void
	{
		this.color = 0xFFAAAAAA;
	}

	// Cached values to skip redundant property reads in hot update loop
	private var _safeZone:Float     = 0;
	private var _safeZoneHalf:Float = 0;

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (mustPress)
		{
			if (wasGoodHit)
			{
				canBeHit  = false;
				tooLate   = false;
				willMiss  = false;
			}
			else if (willMiss)
			{
				tooLate  = true;
				canBeHit = false;
			}
			else
			{
				var songPos:Float = Conductor.framePosition;
				// Cache safeZoneOffset locally once to avoid repeated property access
				var sz:Float = Conductor.safeZoneOffset;
				if (strumTime > songPos - sz)
				{
					canBeHit = (strumTime < songPos + sz * 0.5);
				}
				else
				{
					canBeHit = true;
					willMiss = true;
				}
			}
		}
		else
		{
			canBeHit = false;
			if (strumTime <= Conductor.framePosition)
				wasGoodHit = true;
		}

		if (tooLate && alpha > 0.3)
			alpha = 0.3;
	}
}
