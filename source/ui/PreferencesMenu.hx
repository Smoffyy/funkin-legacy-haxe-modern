package ui;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.util.FlxColor;
import ui.AtlasText.AtlasFont;
import ui.TextMenuList.TextMenuItem;
import ui.CheckboxThingie;

class PreferencesMenu extends ui.OptionsState.Page
{
	public static var preferences:Map<String, Dynamic> = new Map();

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

		// Base game preferences only
		createPrefItem('naughtyness', 'censor-naughty', true);
		createPrefItem('downscroll', 'downscroll', false);
		createPrefItem('flashing menu', 'flashing-menu', false);
		createPrefItem('Camera Zooming on Beat', 'camera-zoom', true);
		createPrefItem('FPS Counter', 'fps-counter', true);
		createPrefItem('Auto Pause', 'auto-pause', false);
		createPrefItem('Note Splashes', 'note-splashes', false);

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

	public static function setPref(pref:String, value:Dynamic):Void
	{
		preferences.set(pref, value);
	}

	public static function savePrefs():Void
	{
		var obj:Dynamic = {};
		for (key in preferences.keys())
			Reflect.setField(obj, key, preferences.get(key));
		FlxG.save.data.preferences = obj;
		FlxG.save.flush();
	}

	public static function initPrefs():Void
	{
		// Load persisted prefs from disk before applying defaults
		if (FlxG.save != null && FlxG.save.data != null && FlxG.save.data.preferences != null)
		{
			var saved:Dynamic = FlxG.save.data.preferences;
			for (key in Reflect.fields(saved))
				preferences.set(key, Reflect.field(saved, key));
		}

		// Base game preferences
		preferenceCheck('censor-naughty', true);
		preferenceCheck('downscroll', false);
		preferenceCheck('flashing-menu', false);
		preferenceCheck('camera-zoom', true);
		preferenceCheck('fps-counter', true);
		preferenceCheck('auto-pause', false);
		preferenceCheck('master-volume', 1);
		preferenceCheck('note-splashes', true);

		// Quality of Life preferences
		preferenceCheck('framerate', 60);
		preferenceCheck('new-input', false);
		preferenceCheck('screen-shake-miss', false);
		preferenceCheck('health-bar-warning', false);
		preferenceCheck('arrow-wobble', false);
		preferenceCheck('new-ui', false);
		preferenceCheck('opponent-note-glow', false);
		preferenceCheck('hide-opponent', false);
		preferenceCheck('song-credits', false);

		#if muted
		setPref('master-volume', 0);
		FlxG.sound.muted = true;
		#end

		if (!getPref('fps-counter'))
			FlxG.stage.removeChild(Main.fpsCounter);

		FlxG.autoPause = getPref('auto-pause');

		Conductor.refreshInterpolationPref();
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
		}, true);

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

	private function prefToggle(prefName:String)
	{
		var daSwap:Bool = preferences.get(prefName);
		daSwap = !daSwap;
		preferences.set(prefName, daSwap);
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
		}
	}

	/**
	 * Sets both FlxG framerates in the correct order to avoid Flixel's internal
	 * warning. updateFramerate must always be >= drawFramerate.
	 * - Going UP:   set update first (new value won't be < old draw)
	 * - Going DOWN: set draw first  (new value won't be > old update)
	 */
	static function setFlxFramerate(fps:Int):Void
	{
		if (fps >= FlxG.updateFramerate)
		{
			FlxG.updateFramerate = fps;
			FlxG.drawFramerate = fps;
		}
		else
		{
			FlxG.drawFramerate = fps;
			FlxG.updateFramerate = fps;
		}
	}

	/**
	 * Applies a framerate for menu contexts. Caps at 360.
	 * Pass fps=0 to use the 360 cap (unlimited in menus).
	 */
	public static function applyFramerate(fps:Int):Void
	{
		var target:Int = (fps == 0) ? 360 : Std.int(Math.min(fps, 360));
		setFlxFramerate(target);
		openfl.Lib.application.window.frameRate = target;
		Conductor.refreshInterpolationPref();
		if (target <= 60)
			Conductor.resetInterpolation();
	}

	/**
	 * Applies the saved 'framerate' preference for gameplay.
	 * fps=0 means unlimited (999). Always syncs window.frameRate.
	 */
	public static function applyGameplayFramerate():Void
	{
		var fps:Int = Std.int(getPref('framerate'));
		var target:Int = (fps == 0) ? 999 : fps;
		setFlxFramerate(target);
		openfl.Lib.application.window.frameRate = target;
		Conductor.refreshInterpolationPref();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		items.forEach(function(daItem:TextMenuItem)
		{
			if (items.selectedItem == daItem)
				daItem.x = 150;
			else
				daItem.x = 120;
		});
	}

	public static function preferenceCheck(prefString:String, prefValue:Dynamic):Void
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
