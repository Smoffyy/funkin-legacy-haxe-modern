package;

import flixel.FlxG;
import flixel.util.FlxSignal;
import flixel.util.FlxTimer;

/**
 * MADE BY GEOKURELI THE LEGENED GOD HERO MVP
 * NOTE: Newgrounds integration is completely disabled.
 * All methods are stubs that do nothing.
 */
class NGio
{
	/**
	 * True, if the saved sessionId was used in the initial login, and failed to connect.
	 * Used in MainMenuState to show a popup to establish a new connection
	 */
	public static var savedSessionFailed(default, null):Bool = false;
	public static var scoreboardsLoaded:Bool = false;
	public static var isLoggedIn(get, never):Bool;
	inline static function get_isLoggedIn()
	{
		return false;
	}

	public static var scoreboardArray:Array<Dynamic> = [];
	public static var ngDataLoaded(default, null):FlxSignal = new FlxSignal();
	public static var ngScoresLoaded(default, null):FlxSignal = new FlxSignal();
	public static var GAME_VER:String = "N/A";
	
	static public function checkVersion(callback:String->Void)
	{
		trace('Newgrounds disabled - skipping version check');
		if (callback != null)
			callback(GAME_VER);
	}

	static public function init()
	{
		trace("Newgrounds integration disabled");
	}
	
	static public function login(?popupLauncher:(Void->Void)->Void, onComplete:Null<ConnectionResult->Void>)
	{
		trace("Newgrounds login disabled");
		if (onComplete != null)
			onComplete(Fail("Newgrounds disabled"));
	}
	
	inline static public function cancelLogin():Void {}
	
	static public function logout() {}

	static public function logEvent(event:String)
	{
		#if debug trace('event:$event - not logged, Newgrounds disabled'); #end
	}

	static public function unlockMedal(id:Int)
	{
		#if debug trace('medal:$id - not unlocked, Newgrounds disabled'); #end
	}

	static public function postScore(score:Int = 0, song:String)
	{
		#if debug trace('Song:$song, Score:$score - not posted, Newgrounds disabled'); #end
	}
}

enum ConnectionResult
{
	/** Log in successful */
	Success;
	/** Could not login */
	Fail(msg:String);
	/** User cancelled the login */
	Cancelled;
}
