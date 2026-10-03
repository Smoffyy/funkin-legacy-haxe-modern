package ui;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import ui.AtlasText.AtlasFont;
import ui.TextMenuList.TextMenuItem;

class PreferencesMenu extends ui.OptionsState.Page
{
	public static var preferences:Map<String, Dynamic> = new Map();

	static inline var UNLIMITED_FRAMERATE:Int = 999;

	var items:TextMenuList;

	var checkboxes:Array<CheckboxThingie> = [];
	var menuCamera:FlxCamera;
	var camFollow:FlxObject;

	public function new()
	{
		super();

		menuCamera = new SwagCamera();
		FlxG.cameras.add(menuCamera, false);
		menuCamera.bgColor = 0x0;
		camera = menuCamera;

		add(items = new TextMenuList());

		createPrefItem('naughtyness', 'censor-naughty', true);
		createPrefItem('downscroll', 'downscroll', false);
		createPrefItem('flashing menu', 'flashing-menu', true);
		createPrefItem('Camera Zooming on Beat', 'camera-zoom', true);
		createPrefItem('FPS Counter', 'fps-counter', true);
		createPrefItem('Auto Pause', 'auto-pause', false);
		createPrefItem('Opponent Strums', 'opponent-strums', false);
		createPrefItem('Ghost Taps', 'ghost-tapping', false);

		camFollow = new FlxObject(FlxG.width / 2, 0, 140, 70);
		if (items != null)
			camFollow.y = items.selectedItem.y;

		menuCamera.follow(camFollow, null, 0.06);
		var margin = 160;
		menuCamera.deadzone.set(0, margin, menuCamera.width, 40);
		menuCamera.minScrollY = 0;

		items.onChange.add(function(selected)
		{
			camFollow.y = selected.y;
		});
	}

	public static function getPref(pref:String):Dynamic
	{
		return preferences.get(pref);
	}

	// easy shorthand?
	public static function setPref(pref:String, value:Dynamic):Void
	{
		preferences.set(pref, value);
		savePrefs();
	}

	// Stored as a plain anonymous object (not a Haxe Map) since that's what
	// FlxSave's serializer reliably round-trips on this target.
	static function savePrefs():Void
	{
		if (FlxG.save.data == null)
			return;

		var stored:Dynamic = {};
		for (key in preferences.keys())
			Reflect.setField(stored, key, preferences.get(key));

		FlxG.save.data.preferences = stored;
		FlxG.save.flush();
	}

	static function loadPrefs():Void
	{
		if (FlxG.save.data == null || FlxG.save.data.preferences == null)
			return;

		try
		{
			for (key in Reflect.fields(FlxG.save.data.preferences))
				preferences.set(key, Reflect.field(FlxG.save.data.preferences, key));
		}
		catch (e:Dynamic)
		{
			// Corrupt or old-format save data, fall back to defaults instead of crashing.
			preferences = new Map();
		}
	}

	public static function initPrefs():Void
	{
		loadPrefs();
		preferences.remove('framerate');

		preferenceCheck('censor-naughty', true);
		preferenceCheck('downscroll', false);
		preferenceCheck('flashing-menu', true);
		preferenceCheck('camera-zoom', true);
		preferenceCheck('fps-counter', true);
		preferenceCheck('auto-pause', false);
		preferenceCheck('opponent-strums', false);
		preferenceCheck('ghost-tapping', false);
		preferenceCheck('master-volume', 1);

		#if muted
		setPref('master-volume', 0);
		FlxG.sound.muted = true;
		#end

		if (!getPref('fps-counter'))
			FlxG.stage.removeChild(Main.fpsCounter);

		FlxG.autoPause = getPref('auto-pause');

		applyFramerate();
	}

	/**
	 * Runs the update and draw loops at the same, effectively uncapped rate, so gameplay logic
	 * (note scrolling, sustains, Conductor timing) advances in lockstep with what's drawn,
	 * instead of judder from update/draw running at different rates.
	 *
	 * Also disables flixel's fixed timestep. With it on, `FlxG.elapsed` is a fixed
	 * `1 / updateFramerate` per update call, and if the actual machine can't sustain
	 * that many update calls a second (a GC hitch on a note hit, an uncapped framerate
	 * the hardware can't hit, etc), flixel's catch-up accumulator gets clamped and never
	 * recovers the lost time - so the whole game (notes, tweens, transitions) permanently
	 * slows to whatever the real update rate ends up being. Variable timestep just uses
	 * real measured elapsed time each frame, so it can't get stuck like that.
	 */
	public static function applyFramerate():Void
	{
		FlxG.fixedTimestep = false;
		FlxG.updateFramerate = UNLIMITED_FRAMERATE;
		FlxG.drawFramerate = UNLIMITED_FRAMERATE;
	}

	private function createPrefItem(prefName:String, prefString:String, prefValue:Dynamic):Void
	{
		items.createItem(120, (120 * items.length) + 30, prefName, AtlasFont.Bold, function()
		{
			preferenceCheck(prefString, prefValue);

			switch (Type.typeof(prefValue).getName())
			{
				case 'TBool':
					prefToggle(prefString);

				default:
					trace('swag');
			}
		});

		switch (Type.typeof(prefValue).getName())
		{
			case 'TBool':
				createCheckbox(prefString);

			default:
				trace('swag');
		}

		trace(Type.typeof(prefValue).getName());
	}

	function createCheckbox(prefString:String)
	{
		var checkbox:CheckboxThingie = new CheckboxThingie(0, 120 * (items.length - 1), preferences.get(prefString));
		checkboxes.push(checkbox);
		add(checkbox);
	}

	/**
	 * Assumes that the preference has already been checked/set?
	 */
	private function prefToggle(prefName:String)
	{
		var daSwap:Bool = preferences.get(prefName);
		daSwap = !daSwap;
		setPref(prefName, daSwap);
		checkboxes[items.selectedIndex].daValue = daSwap;
		trace('toggled? ' + preferences.get(prefName));

		switch (prefName)
		{
			case 'fps-counter':
				if (getPref('fps-counter'))
					FlxG.stage.addChild(Main.fpsCounter);
				else
					FlxG.stage.removeChild(Main.fpsCounter);
			case 'auto-pause':
				FlxG.autoPause = getPref('auto-pause');
			case 'downscroll':
				// The playfield is already built, so move it instead of making the player restart.
				if (Std.isOfType(FlxG.state, PlayState))
					cast(FlxG.state, PlayState).applyScrollDirection();
		}
	}

	override function destroy():Void
	{
		// This page owns its camera, and it is shown from the pause menu as well as from
		// the options state, so it has to clean up after itself either way.
		if (menuCamera != null)
		{
			FlxG.cameras.remove(menuCamera);
			menuCamera = null;
		}

		super.destroy();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		// menuCamera.followLerp = CoolUtil.camLerpShit(0.05);

		items.forEach(function(daItem:TextMenuItem)
		{
			if (items.selectedItem == daItem)
				daItem.x = 150;
			else
				daItem.x = 120;
		});
	}

	private static function preferenceCheck(prefString:String, prefValue:Dynamic):Void
	{
		if (preferences.get(prefString) == null)
		{
			preferences.set(prefString, prefValue);
			trace('set preference!');
		}
		else
		{
			trace('found preference: ' + preferences.get(prefString));
		}
	}
}

class CheckboxThingie extends FlxSprite
{
	public var daValue(default, set):Bool;

	public function new(x:Float, y:Float, daValue:Bool = false)
	{
		super(x, y);

		frames = Paths.getSparrowAtlas('checkboxThingie');
		animation.addByPrefix('static', 'Check Box unselected', 24, false);
		animation.addByPrefix('checked', 'Check Box selecting animation', 24, false);

		antialiasing = true;

		setGraphicSize(Std.int(width * 0.7));
		updateHitbox();

		this.daValue = daValue;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		switch (animation.curAnim.name)
		{
			case 'static':
				offset.set();
			case 'checked':
				offset.set(17, 70);
		}
	}

	function set_daValue(value:Bool):Bool
	{
		if (value)
			animation.play('checked', true);
		else
			animation.play('static');

		return value;
	}
}
