package;

import Controls.Control;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import funkin.data.SongCache;
import ui.PreferencesMenu;

class PauseSubState extends MusicBeatSubstate
{
	var grpMenuShit:FlxTypedGroup<Alphabet>;

	var pauseOG:Array<String> = [
		'Resume',
		'Restart Song',
		'Change Difficulty',
		'Options',
		'Toggle Practice Mode',
		'Exit to menu'
	];

	var menuItems:Array<String> = [];
	var curSelected:Int = 0;

	var pauseMusic:FlxSound;

	var practiceText:FlxText;

	/**
	 * The preferences page, shown in place of the pause menu so settings can be changed
	 * without dropping out of the song.
	 */
	var preferences:PreferencesMenu;

	/**
	 * The page asks to close from inside its own update, so the teardown waits for the
	 * next frame rather than destroying a group that is currently being iterated.
	 */
	var closingPreferences:Bool = false;

	public function new(x:Float, y:Float)
	{
		super();

		menuItems = pauseOG;

		pauseMusic = new FlxSound().loadEmbedded(Paths.music('breakfast'), true, true);
		pauseMusic.volume = 0;
		pauseMusic.play(false, FlxG.random.int(0, Std.int(pauseMusic.length / 2)));

		FlxG.sound.list.add(pauseMusic);

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		var levelInfo:FlxText = new FlxText(20, 15, 0, "", 32);
		levelInfo.text += PlayState.SONG.song;
		levelInfo.scrollFactor.set();
		levelInfo.setFormat(Paths.font("vcr.ttf"), 32);
		levelInfo.updateHitbox();
		add(levelInfo);

		var levelDifficulty:FlxText = new FlxText(20, 15 + 32, 0, "", 32);
		levelDifficulty.text += CoolUtil.difficultyString();
		levelDifficulty.scrollFactor.set();
		levelDifficulty.setFormat(Paths.font('vcr.ttf'), 32);
		levelDifficulty.updateHitbox();
		add(levelDifficulty);

		var deathCounter:FlxText = new FlxText(20, 15 + 64, 0, "", 32);
		deathCounter.text = "Blue balled: " + PlayState.deathCounter;
		deathCounter.scrollFactor.set();
		deathCounter.setFormat(Paths.font('vcr.ttf'), 32);
		deathCounter.updateHitbox();
		add(deathCounter);

		practiceText = new FlxText(20, 15 + 64 + 32, 0, "PRACTICE MODE", 32);
		practiceText.scrollFactor.set();
		practiceText.setFormat(Paths.font('vcr.ttf'), 32);
		practiceText.updateHitbox();
		practiceText.x = FlxG.width - (practiceText.width + 20);
		practiceText.visible = PlayState.practiceMode;
		add(practiceText);

		levelDifficulty.alpha = 0;
		levelInfo.alpha = 0;
		deathCounter.alpha = 0;

		levelInfo.x = FlxG.width - (levelInfo.width + 20);
		levelDifficulty.x = FlxG.width - (levelDifficulty.width + 20);
		deathCounter.x = FlxG.width - (deathCounter.width + 20);

		FlxTween.tween(bg, {alpha: 0.6}, 0.4, {ease: FlxEase.quartInOut});
		FlxTween.tween(levelInfo, {alpha: 1, y: 20}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.3});
		FlxTween.tween(levelDifficulty, {alpha: 1, y: levelDifficulty.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.5});
		FlxTween.tween(deathCounter, {alpha: 1, y: deathCounter.y + 5}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.7});

		grpMenuShit = new FlxTypedGroup<Alphabet>();
		add(grpMenuShit);

		regenMenu();
	}

	private function regenMenu():Void
	{
		while (grpMenuShit.members.length > 0)
		{
			grpMenuShit.remove(grpMenuShit.members[0], true);
		}

		for (i in 0...menuItems.length)
		{
			var songText:Alphabet = new Alphabet(0, (70 * i) + 30, menuItems[i], true, false);
			songText.isMenuItem = true;
			songText.targetY = i;
			grpMenuShit.add(songText);
		}

		curSelected = 0;
		changeSelection();
	}

	/**
	 * Swaps the pause menu out for the preferences page. Everything on it applies to the
	 * running song straight away, so nothing has to be restarted to take effect.
	 */
	function openPreferences():Void
	{
		grpMenuShit.visible = false;

		preferences = new PreferencesMenu();
		preferences.onExit.add(function() closingPreferences = true);
		add(preferences);
	}

	function closePreferences():Void
	{
		closingPreferences = false;

		if (preferences == null)
			return;

		remove(preferences, true);
		preferences.destroy();
		preferences = null;

		grpMenuShit.visible = true;
	}

	override function update(elapsed:Float)
	{
		if (pauseMusic.volume < 0.5)
			pauseMusic.volume += 0.01 * elapsed;

		if (closingPreferences)
			closePreferences();

		super.update(elapsed);

		if (preferences != null)
			return;

		var upP = controls.UI_UP_P;
		var downP = controls.UI_DOWN_P;
		var accepted = controls.ACCEPT;

		if (upP)
		{
			changeSelection(-1);
		}
		if (downP)
		{
			changeSelection(1);
		}

		if (accepted)
		{
			var daSelected:String = menuItems[curSelected];

			switch (daSelected)
			{
				case "Resume":
					close();

				case 'Options':
					openPreferences();

				case 'Toggle Practice Mode':
					PlayState.practiceMode = !PlayState.practiceMode;
					practiceText.visible = PlayState.practiceMode;

				case 'Change Difficulty':
					menuItems = CoolUtil.difficultyArray.concat(['BACK']);
					regenMenu();

				case 'BACK':
					menuItems = pauseOG;
					regenMenu();

				case "Restart Song":
					FlxG.resetState();

				case "Exit to menu":
					PlayState.seenCutscene = false;
					PlayState.deathCounter = 0;
					if (PlayState.isStoryMode)
						FlxG.switchState(() -> new StoryMenuState());
					else
						FlxG.switchState(() -> new FreeplayState());

				default:
					// Anything else in the list is a difficulty, and its index is the difficulty.
					var chart = SongCache.load(Song.idOf(PlayState.SONG), curSelected);
					if (chart != null)
					{
						PlayState.SONG = chart;
						PlayState.storyDifficulty = curSelected;
						FlxG.resetState();
					}
			}
		}
	}

	override function destroy()
	{
		closePreferences();
		pauseMusic.destroy();

		super.destroy();
	}

	function changeSelection(change:Int = 0):Void
	{
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curSelected += change;

		if (curSelected < 0)
			curSelected = menuItems.length - 1;
		if (curSelected >= menuItems.length)
			curSelected = 0;

		var bullShit:Int = 0;

		for (item in grpMenuShit.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;

			if (item.targetY == 0)
			{
				item.alpha = 1;
			}
		}
	}
}
