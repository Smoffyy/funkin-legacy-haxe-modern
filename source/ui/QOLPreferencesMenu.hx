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

class QOLPreferencesMenu extends ui.OptionsState.Page
{
	static final FPS_OPTIONS:Array<Int> = [30, 60, 75, 120, 144, 180, 240, 300, 360, 0];

	var items:TextMenuList;
	var checkboxes:Array<CheckboxThingie> = [];
	var menuCamera:FlxCamera;
	var camFollow:FlxObject;

	var fpsIndex:Int = 0;
	var fpsItemIndex:Int = -1;
	var fpsItem:TextMenuItem;
	var wasOnFpsItem:Bool = false;

	var inputHoldTimer:Float = 0;
	static inline final INPUT_REPEAT_DELAY:Float = 0.15;

	public function new()
	{
		super();

		menuCamera = new SwagCamera();
		FlxG.cameras.add(menuCamera, false);
		menuCamera.bgColor = 0x0;
		camera = menuCamera;

		add(items = new TextMenuList());

		createFramerateItem();
		createPrefItem("New Input (Ghost Tapping)", "new-input", false);
		createPrefItem('Improved Interface', 'new-ui', false);
		createPrefItem('Opponent Note Glow', 'opponent-note-glow', false);
		createPrefItem('Screen Shake on Miss', 'screen-shake-miss', false);
		createPrefItem('Health Bar Warning', 'health-bar-warning', false);
		createPrefItem('Arrow Wobble', 'arrow-wobble', false);
		createPrefItem('Hide Opp Arrows', 'hide-opponent', false);
		createPrefItem('Song Credits Display', 'song-credits', false);

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

	function createFramerateItem():Void
	{
		var savedFps:Int = Std.int(PreferencesMenu.getPref('framerate'));
		var savedIndex:Int = FPS_OPTIONS.indexOf(savedFps);
		fpsIndex = savedIndex < 0 ? 1 : savedIndex;

		fpsItemIndex = items.length;
		fpsItem = items.createItem(120, (120 * items.length) + 30, labelForIndex(fpsIndex), AtlasFont.Default, function() {}, true);

		checkboxes.push(null);
	}

	inline function labelForIndex(index:Int):String
	{
		var fps:Int = FPS_OPTIONS[index];
		return 'Framerate: ' + (fps == 0 ? 'Unlimited' : fps + ' FPS');
	}

	function commitFps():Void
	{
		var fps:Int = FPS_OPTIONS[fpsIndex];
		PreferencesMenu.setPref('framerate', fps);
		PreferencesMenu.applyFramerate(fps);
	}

	private function createPrefItem(prefName:String, prefString:String, prefValue:Dynamic):Void
	{
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
		}, true);

		switch (Type.typeof(prefValue).getName())
		{
			case 'TBool':
				createCheckbox(prefString);

			default:
				trace('swag');
		}
	}

	function createCheckbox(prefString:String)
	{
		var checkbox:CheckboxThingie = new CheckboxThingie(0, 120 * (items.length - 1), PreferencesMenu.preferences.get(prefString));
		checkboxes.push(checkbox);
		add(checkbox);
	}

	private function prefToggle(prefName:String)
	{
		var daSwap:Bool = PreferencesMenu.preferences.get(prefName);
		daSwap = !daSwap;
		PreferencesMenu.preferences.set(prefName, daSwap);
		var cb = checkboxes[items.selectedIndex];
		if (cb != null)
			cb.daValue = daSwap;
	}

	override function update(elapsed:Float)
	{
		var onFpsItem = enabled && items.selectedIndex == fpsItemIndex;

		// commit when navigating away from the fps row
		if (wasOnFpsItem && !onFpsItem)
			commitFps();
		wasOnFpsItem = onFpsItem;

		super.update(elapsed);

		if (onFpsItem)
		{
			var left = controls.UI_LEFT_P;
			var right = controls.UI_RIGHT_P;

			// accumulate hold time only while a direction is held; reset on release
			if (controls.UI_LEFT || controls.UI_RIGHT)
			{
				// reset on the initial press so the first repeat is delayed properly
				if (left || right)
					inputHoldTimer = 0;
				else
					inputHoldTimer += elapsed;

				if (!left && !right && inputHoldTimer >= INPUT_REPEAT_DELAY)
				{
					left = controls.UI_LEFT;
					right = controls.UI_RIGHT;
					inputHoldTimer = 0;
				}
			}
			else
			{
				inputHoldTimer = 0;
			}

			if (left)
			{
				fpsIndex = (fpsIndex - 1 + FPS_OPTIONS.length) % FPS_OPTIONS.length;
				fpsItem.label.text = labelForIndex(fpsIndex);
			}
			else if (right)
			{
				fpsIndex = (fpsIndex + 1) % FPS_OPTIONS.length;
				fpsItem.label.text = labelForIndex(fpsIndex);
			}
		}
		else
		{
			inputHoldTimer = 0;
		}

		items.forEach(function(daItem:TextMenuItem)
		{
			if (items.selectedItem == daItem)
				daItem.x = 150;
			else
				daItem.x = 120;
		});
	}

	/**
	 * Commit any pending fps change if the menu is closed while still on the fps row.
	 * Without this, pressing Back without navigating away would silently discard the change.
	 */
	override function destroy()
	{
		if (wasOnFpsItem)
			commitFps();
		super.destroy();
	}
}
