package;

#if discord_rpc
import Discord.DiscordClient;
#end
import flash.text.TextField;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import lime.utils.Assets as LimeAssets;
import openfl.utils.Assets;
import openfl.media.Sound;

#if sys
import sys.thread.Thread;
#end

using StringTools;

class FreeplayState extends MusicBeatState
{
    var songs:Array<SongMetadata> = [];

    static var lastSelectedSong:Int = 0;
    static var lastDifficulty:Int = 1;

    var curSelected:Int = 0;
    var holdScrollTimer:Float = 0;
    var holdScrollDelay:Float = 0.2;
    var holdScrollInterval:Float = 0.08;
    var curDifficulty:Int = 1;

    var scoreText:FlxText;
    var diffText:FlxText;
    var lerpScore:Float = 0;
    var intendedScore:Int = 0;

    var coolColors:Array<Int> = [
        0xff9271fd,
        0xff9271fd,
        0xff223344,
        0xFF941653,
        0xFFfc96d7,
        0xFFa0d1ff,
        0xffff78bf,
        0xfff6b604
    ];

    private var grpSongs:FlxTypedGroup<Alphabet>;
    private var curPlaying:Bool = false;

    private var iconArray:Array<HealthIcon> = [];
    var bg:FlxSprite;
    var scoreBG:FlxSprite;
    
    // Cache preload tracking
    private var preloadingQueue:Array<String> = [];
    private var currentPreloadIndex:Int = 0;
    private var isPreloading:Bool = false;

    private var _pendingSound:Sound = null;
    private var _pendingSeekMs:Float = 0;

    override function create()
    {
        #if discord_rpc
        DiscordClient.changePresence("In the Menus", null);
        #end

        var isDebug:Bool = false;

        #if debug
        isDebug = true;
        addSong('Test', 1, 'bf-pixel');
        #end

        var initSonglist = CoolUtil.coolTextFile(Paths.txt('freeplaySonglist'));

        for (i in 0...initSonglist.length)
        {
            songs.push(new SongMetadata(initSonglist[i], 1, 'gf'));
        }

        if (FlxG.sound.music != null)
        {
            if (!FlxG.sound.music.playing)
                FlxG.sound.playMusic(Paths.music('freakyMenu'));
        }

        if (StoryMenuState.weekUnlocked[2] || isDebug)
            addWeek(['Bopeebo', 'Fresh', 'Dadbattle'], 1, ['dad']);

        if (StoryMenuState.weekUnlocked[2] || isDebug)
            addWeek(['Spookeez', 'South', 'Monster'], 2, ['spooky', 'spooky', 'monster']);

        if (StoryMenuState.weekUnlocked[3] || isDebug)
            addWeek(['Pico', 'Philly', 'Blammed'], 3, ['pico']);

        if (StoryMenuState.weekUnlocked[4] || isDebug)
            addWeek(['Satin-Panties', 'High', 'Milf'], 4, ['mom']);

        if (StoryMenuState.weekUnlocked[5] || isDebug)
            addWeek(['Cocoa', 'Eggnog', 'Winter-Horrorland'], 5, ['parents-christmas', 'parents-christmas', 'monster-christmas']);

        if (StoryMenuState.weekUnlocked[6] || isDebug)
            addWeek(['Senpai', 'Roses', 'Thorns'], 6, ['senpai', 'senpai', 'spirit']);

        if (StoryMenuState.weekUnlocked[7] || isDebug)
            addWeek(['Ugh', 'Guns', 'Stress'], 7, ['tankman']);

        bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
        add(bg);

        grpSongs = new FlxTypedGroup<Alphabet>();
        add(grpSongs);

        for (i in 0...songs.length)
        {
            var songText:Alphabet = new Alphabet(0, (70 * i) + 30, songs[i].songName, true, false);
            songText.isMenuItem = true;
            songText.targetY = i;
            grpSongs.add(songText);

            var icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
            icon.sprTracker = songText;

            iconArray.push(icon);
            add(icon);
        }

        scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
        scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);

        scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 66, 0x99000000);
        scoreBG.antialiasing = false;
        add(scoreBG);

        diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "", 24);
        diffText.font = scoreText.font;
        add(diffText);

        add(scoreText);

        curSelected = lastSelectedSong;
        curDifficulty = lastDifficulty;
        changeSelection();
        changeDiff();
        
        // Initialize cache manager
        AssetCacheManager.initialize();

        super.create();
    }

    public function addSong(songName:String, weekNum:Int, songCharacter:String)
    {
        songs.push(new SongMetadata(songName, weekNum, songCharacter));
    }

    public function addWeek(songs:Array<String>, weekNum:Int, ?songCharacters:Array<String>)
    {
        if (songCharacters == null)
            songCharacters = ['bf'];

        var num:Int = 0;
        for (song in songs)
        {
            addSong(song, weekNum, songCharacters[num]);

            if (songCharacters.length != 1)
                num++;
        }
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (_pendingSound != null)
        {
            var snd = _pendingSound;
            var seekMs = _pendingSeekMs;
            _pendingSound = null;
            _pendingSeekMs = 0;
            FlxG.sound.playMusic(snd, 0);
            if (seekMs > 0 && FlxG.sound.music != null)
            {
                var maxMs:Float = FlxG.sound.music.length - 100;
                FlxG.sound.music.time = Math.min(seekMs, maxMs > 0 ? maxMs : 0);
            }
        }

        if (FlxG.sound.music != null)
        {
            if (FlxG.sound.music.volume < 0.7)
            {
                FlxG.sound.music.volume += 0.5 * FlxG.elapsed;
            }
        }

        lerpScore = CoolUtil.coolLerp(lerpScore, intendedScore, 0.4);
        bg.color = FlxColor.interpolate(bg.color, coolColors[songs[curSelected].week % coolColors.length], CoolUtil.camLerpShit(0.045));

        scoreText.text = "PERSONAL BEST:" + Math.round(lerpScore);

        positionHighscore();

        var upP = controls.UI_UP_P;
        var downP = controls.UI_DOWN_P;
        var upH = controls.UI_UP;
        var downH = controls.UI_DOWN;
        var accepted = controls.ACCEPT;

        if (upP)
            changeSelection(-1);
        if (downP)
            changeSelection(1);

        if (upH || downH)
        {
            holdScrollTimer += elapsed;
            if (upP || downP)
                holdScrollTimer = -holdScrollDelay;
            if (holdScrollTimer >= holdScrollInterval)
            {
                holdScrollTimer = 0;
                if (upH) changeSelection(-1);
                if (downH) changeSelection(1);
            }
        }
        else
            holdScrollTimer = 0;

        if (FlxG.mouse.wheel != 0)
            changeSelection(-Math.round(FlxG.mouse.wheel / 4));

        if (controls.UI_LEFT_P)
            changeDiff(-1);
        if (controls.UI_RIGHT_P)
            changeDiff(1);

        if (controls.BACK)
        {
            FlxG.sound.play(Paths.sound('cancelMenu'));
            FlxG.switchState(()->new MainMenuState());
        }

        if (accepted)
        {
            lastSelectedSong = curSelected;
            lastDifficulty = curDifficulty;

            var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
            
            // Load song - will be automatically cached by Song.loadFromJson()
            PlayState.SONG = Song.loadFromJson(poop, songs[curSelected].songName.toLowerCase());
            PlayState.isStoryMode = false;
            PlayState.storyDifficulty = curDifficulty;

            PlayState.storyWeek = songs[curSelected].week;
            
            // Pre-cache song audio immediately before playing
            AssetCacheManager.preCacheSongAudio(songs[curSelected].songName, PlayState.SONG.needsVoices, curDifficulty);
            
            // Pre-cache characters
            AssetCacheManager.preCacheCharacters([PlayState.SONG.player1, PlayState.SONG.player2]);
            
            LoadingState.loadAndSwitchState(()->new PlayState());
        }
    }

    function changeDiff(change:Int = 0)
    {
        curDifficulty += change;

        if (curDifficulty < 0)
            curDifficulty = 4;
        if (curDifficulty > 4)
            curDifficulty = 0;

        intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);

        PlayState.storyDifficulty = curDifficulty;

        diffText.text = "< " + CoolUtil.difficultyString() + " >";
        positionHighscore();

        var seekMs:Float = (FlxG.sound.music != null && FlxG.sound.music.playing) ? FlxG.sound.music.time : 0;
        playPreview(seekMs);
    }

    /**
     * Play a preview of the currently selected song at the current difficulty.
     *
     * Priority:
     *   1. If a .fnfc exists for this song → extract the correct variation's
     *      instrumental to fnfc-temp and play via Sound.fromFile.
     *      Works for ALL difficulties including expert (erect) and nightmare (night).
     *   2. Otherwise → play from the songs asset library (requires PRELOAD_ALL).
     *
     * Runs extraction + loading on a background thread to avoid UI stutter.
     * Guards against stale results: if the user scrolls or changes difficulty
     * before loading finishes, the result is silently discarded.
     */
    function playPreview(seekMs:Float = 0):Void
    {
        var songName:String = songs[curSelected].songName;
        var songId:String   = songName.toLowerCase();
        var diff:Int        = curDifficulty;

        #if sys
        sys.thread.Thread.create(function()
        {
            try
            {
                var instSound:Sound = null;

                if (FNFCLoader.exists(songId))
                {
                    // FNFC path — extract preview inst to temp dir, load from filesystem
                    var path:String = FNFCLoader.getPreviewInstPath(songId, diff);
                    if (path == null) return;
                    instSound = Sound.fromFile(path);
                }
                else
                {
                    #if PRELOAD_ALL
                    // Legacy path — load from OpenFL asset library
                    instSound = Assets.getSound(Paths.inst(songName, diff));
                    #else
                    return; // No preloaded assets available, skip preview
                    #end
                }

                if (instSound == null) return;

                // Discard result if user has already moved on
                if (songs[curSelected] == null
                    || songs[curSelected].songName != songName
                    || curDifficulty != diff)
                    return;

                _pendingSeekMs = seekMs;
                _pendingSound = instSound;
            }
            catch (e:Dynamic)
            {
                trace('[FreeplayState] Preview error for "$songName" diff=$diff: $e');
            }
        });
        #else
        // Non-sys target: FNFC not supported, fall back to asset library path
        #if PRELOAD_ALL
        if (!FNFCLoader.exists(songId))
        {
            FlxG.sound.playMusic(Paths.inst(songName, diff), 0);
            if (seekMs > 0 && FlxG.sound.music != null)
                FlxG.sound.music.time = seekMs;
        }
        #end
        #end
    }

    function changeSelection(change:Int = 0)
    {
        NGio.logEvent('Fresh');
        FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

        curSelected += change;

        if (curSelected < 0)
            curSelected = songs.length - 1;
        if (curSelected >= songs.length)
            curSelected = 0;

        intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);

        playPreview(0);

        var bullShit:Int = 0;

        for (i in 0...iconArray.length)
        {
            iconArray[i].alpha = 0.6;
        }

        iconArray[curSelected].alpha = 1;

        for (item in grpSongs.members)
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

    function positionHighscore()
    {
        scoreText.x = FlxG.width - scoreText.width - 6;
        scoreBG.scale.x = FlxG.width - scoreText.x + 6;
        scoreBG.x = FlxG.width - scoreBG.scale.x / 2;

        diffText.x = Std.int(scoreBG.x + scoreBG.width / 2);
        diffText.x -= (diffText.width / 2);
    }
}

class SongMetadata
{
    public var songName:String = "";
    public var week:Int = 0;
    public var songCharacter:String = "";

    public function new(song:String, week:Int, songCharacter:String)
    {
        this.songName = song;
        this.week = week;
        this.songCharacter = songCharacter;
    }
}
