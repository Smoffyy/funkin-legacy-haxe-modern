package ui;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxSignal;

// typedef OptionsState = OptionsMenu_old;
// class OptionsState_new extends MusicBeatState
class OptionsState extends MusicBeatState
{
	var pages = new Map<PageName, Page>();
	var currentName:PageName = Options;
	var currentPage(get, never):Page;

	inline function get_currentPage()
		return pages[currentName];

	override function create()
	{
		var menuBG = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		menuBG.color = 0xFFea71fd;
		menuBG.setGraphicSize(Std.int(menuBG.width * 1.1));
		menuBG.updateHitbox();
		menuBG.screenCenter();
		menuBG.scrollFactor.set(0, 0);
		add(menuBG);

		var options = addPage(Options, new OptionsMenu(false));
		var preferences = addPage(Preferences, new PreferencesMenu());
		var qolPreferences = addPage(QOLPreferences, new QOLPreferencesMenu());
		var controls = addPage(Controls, new ControlsMenu());
		// var colors = addPage(Colors, new ColorsMenu());

		#if cpp
		var mods = addPage(Mods, new ModMenu());
		#end
		var changelog = addPage(Changelog, new ChangelogPage());

		if (options.hasMultipleOptions())
		{
			options.onExit.add(exitToMainMenu);
			controls.onExit.add(switchPage.bind(Options));
			// colors.onExit.add(switchPage.bind(Options));
			preferences.onExit.add(switchPage.bind(Options));
			qolPreferences.onExit.add(switchPage.bind(Options));

			#if cpp
			mods.onExit.add(switchPage.bind(Options));
			#end
			changelog.onExit.add(switchPage.bind(Options));
		}
		else
		{
			// No need to show Options page
			controls.onExit.add(exitToMainMenu);
			setPage(Controls);
		}

		currentPage.enabled = true;
		super.create();
	}

	function addPage<T:Page>(name:PageName, page:T)
	{
		page.onSwitch.add(switchPage);
		pages[name] = page;
		add(page);
		page.exists = currentName == name;
		return page;
	}

	function setPage(name:PageName)
	{
		if (pages.exists(currentName))
			currentPage.exists = false;

		currentName = name;

		if (pages.exists(currentName))
			currentPage.exists = true;
	}

	override function finishTransIn()
	{
		super.finishTransIn();

		currentPage.enabled = true;
	}

	function switchPage(name:PageName)
	{
		// Todo animate?
		setPage(name);
	}

	function exitToMainMenu()
	{
		currentPage.enabled = false;
		// Todo animate?
		FlxG.switchState(()->new MainMenuState());
	}
}

class Page extends FlxGroup
{
	public var onSwitch(default, null) = new FlxTypedSignal<PageName->Void>();
	public var onExit(default, null) = new FlxSignal();

	public var enabled(default, set) = true;
	public var canExit = true;

	var controls(get, never):Controls;

	inline function get_controls()
		return PlayerSettings.player1.controls;

	var subState:FlxSubState;

	inline function switchPage(name:PageName)
	{
		onSwitch.dispatch(name);
	}

	inline function exit()
	{
		onExit.dispatch();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (enabled)
			updateEnabled(elapsed);
	}

	function updateEnabled(elapsed:Float)
	{
		if (canExit && controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			exit();
		}
	}

	function set_enabled(value:Bool)
	{
		return this.enabled = value;
	}

	function openPrompt(prompt:Prompt, onClose:Void->Void)
	{
		enabled = false;
		prompt.closeCallback = function()
		{
			enabled = true;
			if (onClose != null)
				onClose();
		}

		FlxG.state.openSubState(prompt);
	}

	override function destroy()
	{
		super.destroy();
		onSwitch.removeAll();
	}
}

class OptionsMenu extends Page
{
	var items:TextMenuList;

	public function new(showDonate:Bool)
	{
		super();

		add(items = new TextMenuList());
		createItem('preferences', function() switchPage(Preferences));
		createItem('quality of life prefs', function() switchPage(QOLPreferences));
		createItem("controls", function() switchPage(Controls));
		// createItem('colors', function() switchPage(Colors));
		#if cpp
		createItem('mods', function() switchPage(Mods));
		#end
		createItem('changelog', function() switchPage(Changelog));

		#if CAN_OPEN_LINKS
		if (showDonate)
		{
			var hasPopupBlocker = #if web true #else false #end;
			createItem('donate', selectDonate, hasPopupBlocker);
		}
		#end
		#if newgrounds
		if (NGio.isLoggedIn)
			createItem("logout", selectLogout);
		else
			createItem("login", selectLogin);
		#end
		createItem("exit", exit);
	}

	function createItem(name:String, callback:Void->Void, fireInstantly = false)
	{
		var item = items.createItem(0, 100 + items.length * 100, name, Bold, callback);
		item.fireInstantly = fireInstantly;
		item.screenCenter(X);
		return item;
	}

	override function set_enabled(value:Bool)
	{
		items.enabled = value;
		return super.set_enabled(value);
	}

	/**
	 * True if this page has multiple options, excluding the exit option.
	 * If false, there's no reason to ever show this page.
	 */
	public function hasMultipleOptions():Bool
	{
		return items.length > 2;
	}

	#if CAN_OPEN_LINKS
	function selectDonate()
	{
		#if linux
		Sys.command('/usr/bin/xdg-open', ["https://ninja-muffin24.itch.io/funkin", "&"]);
		#else
		FlxG.openURL('https://ninja-muffin24.itch.io/funkin');
		#end
	}
	#end

	#if newgrounds
	function selectLogin()
	{
		openNgPrompt(NgPrompt.showLogin());
	}

	function selectLogout()
	{
		openNgPrompt(NgPrompt.showLogout());
	}

	/**
	 * Calls openPrompt and redraws the login/logout button
	 * @param prompt 
	 * @param onClose 
	 */
	public function openNgPrompt(prompt:Prompt, ?onClose:Void->Void)
	{
		var onPromptClose = checkLoginStatus;
		if (onClose != null)
		{
			onPromptClose = function()
			{
				checkLoginStatus();
				onClose();
			}
		}

		openPrompt(prompt, onPromptClose);
	}

	function checkLoginStatus()
	{
		// this shit don't work!! wtf!!!!
		var prevLoggedIn = items.has("logout");
		if (prevLoggedIn && !NGio.isLoggedIn)
			items.resetItem("logout", "login", selectLogin);
		else if (!prevLoggedIn && NGio.isLoggedIn)
			items.resetItem("login", "logout", selectLogout);
	}
	#end
}

enum PageName
{
	Options;
	Controls;
	Colors;
	Mods;
	Preferences;
	QOLPreferences;
	Changelog;
}

class ChangelogPage extends Page
{
	var scrollText:FlxText;
	var bg:FlxSprite;
	var scrollY:Float = 0;
	var maxScroll:Float = 0;
	static inline final SCROLL_SPEED:Float = 500;
	static inline final PADDING:Float = 30;

	public function new()
	{
		super();

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xEE000000);
		bg.scrollFactor.set();
		add(bg);

		var title:FlxText = new FlxText(0, 14, FlxG.width, "CHANGELOG", 28);
		title.scrollFactor.set();
		title.setFormat("VCR OSD Mono", 28, 0xFFFFD700, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(title);

		var hint:FlxText = new FlxText(0, FlxG.height - 28, FlxG.width, "UP / DOWN to scroll    BACK to return", 14);
		hint.scrollFactor.set();
		hint.setFormat("VCR OSD Mono", 14, 0xFFAAAAAA, CENTER);
		add(hint);

		var body:String = readChangelog();

		scrollText = new FlxText(PADDING, 70, FlxG.width - PADDING * 2, body, 14);
		scrollText.setFormat("VCR OSD Mono", 14, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scrollText.scrollFactor.set();
		add(scrollText);

		maxScroll = Math.max(0, scrollText.height - (FlxG.height - 100));
	}

	function readChangelog():String
	{
		#if sys
		var paths:Array<String> = ["changelog.txt", "../changelog.txt"];
		for (p in paths)
		{
			if (sys.FileSystem.exists(p))
				return sys.io.File.getContent(p);
		}
		return "changelog.txt not found.\nMake sure it is in the same folder as the game executable.";
		#else
		return "Changelog is only available on desktop builds.";
		#end
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (!enabled) return;

		if (controls.UI_DOWN)
			scrollY = Math.min(scrollY + SCROLL_SPEED * elapsed, maxScroll);
		if (controls.UI_UP)
			scrollY = Math.max(scrollY - SCROLL_SPEED * elapsed, 0);

		scrollText.y = 70 - scrollY;
	}
}
