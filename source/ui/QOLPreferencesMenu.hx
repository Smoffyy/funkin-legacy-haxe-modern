package ui;

import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import ui.AtlasText.AtlasFont;
import ui.TextMenuList.TextMenuItem;
import ui.CheckboxThingie;

class QOLPreferencesMenu extends ui.OptionsState.Page
{
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

		// Quality of Life preferences
		createPrefItem("New Input (Ghost Tapping)", "new-input", false);
		createPrefItem('Screen Shake on Miss', 'screen-shake-miss', false);
		createPrefItem('Health Bar Warning', 'health-bar-warning', true);
		createPrefItem('Arrow Wobble', 'arrow-wobble', false);
		createPrefItem('Improved Interface', 'new-ui', false);
		createPrefItem('Interpolation (HIGH FPS)', 'interpolation', false);
		createPrefItem('Opponent Note Glow', 'opponent-note-glow', false);

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

	private function createPrefItem(prefName:String, prefString:String, prefValue:Dynamic):Void
	{
		// Pass fireInstantly: true directly to createItem for instant, non-blocking response
		items.createItem(120, (120 * items.length) + 30, prefName, AtlasFont.Bold, function()
		{
			PreferencesMenu.preferenceCheck(prefString, prefValue);

			switch (Type.typeof(prefValue).getName())
			{
				case 'TBool':
					prefToggle(prefString);

				default:
					trace('swag');
			}
		}, true); // fireInstantly = true

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
		var checkbox:CheckboxThingie = new CheckboxThingie(0, 120 * (items.length - 1), PreferencesMenu.preferences.get(prefString));
		checkboxes.push(checkbox);
		add(checkbox);
	}

	/**
	 * Assumes that the preference has already been checked/set?
	 */
	private function prefToggle(prefName:String)
	{
		var daSwap:Bool = PreferencesMenu.preferences.get(prefName);
		daSwap = !daSwap;
		PreferencesMenu.preferences.set(prefName, daSwap);
		checkboxes[items.selectedIndex].daValue = daSwap;
		trace('toggled? ' + PreferencesMenu.preferences.get(prefName));
		
		// Handle interpolation framerate change
		if (prefName == 'interpolation')
		{
			new FlxTimer().start(0.05, function(timer:FlxTimer)
			{
				if (PreferencesMenu.preferences.get('interpolation'))
				{
					FlxG.updateFramerate = 360;
					FlxG.drawFramerate = 360;
					trace('Framerate set to 360 FPS (High FPS mode)');
				}
				else
				{
					// Classic mode
					FlxG.updateFramerate = 60;
					FlxG.drawFramerate = 60;
					trace('Framerate set to 60 FPS (Classic mode)');
				}
			});
		}
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
}
