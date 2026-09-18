package funkin.modern;

import Section.SwagSection;
import Song.SwagEvent;
import Song.SwagSong;
import funkin.modern.ModernSong.ModernDifficulty;
import funkin.modern.ModernSongData;

using StringTools;

/**
 * Converts a modern chart into the section-based `SwagSong` the engine plays.
 *
 * Modern charts are a flat note list with absolute strumline indices (0-3 player,
 * 4-7 opponent) and no sections at all. The legacy playfield still indexes sections by
 * `curStep / 16`, so sections are rebuilt here from the time changes, and each note's
 * data is re-encoded so it lands on the same strumline it was charted for.
 */
class ModernChartConverter
{
	static inline var STEPS_PER_SECTION:Int = 16;
	static inline var BEATS_PER_SECTION:Int = 4;
	static inline var DEFAULT_BPM:Float = 100;

	static inline function sectionLengthMs(bpm:Float):Float
	{
		return (60 / bpm) * 1000 * BEATS_PER_SECTION;
	}

	public static function convert(song:ModernSong, difficulty:ModernDifficulty):SwagSong
	{
		var variation = song.get(difficulty.variation);
		if (variation == null)
			return null;

		var metadata = variation.metadata;
		var chart = variation.chart;
		var playData = metadata.playData;
		var characters = playData.characters;

		var notes:Array<ModernNote> = cast Reflect.field(chart.notes, difficulty.difficulty);
		if (notes == null)
			notes = [];

		var events:Array<ModernEvent> = chart.events == null ? [] : chart.events.copy();
		events.sort(function(a, b) return a.t < b.t ? -1 : (a.t > b.t ? 1 : 0));

		var timeChanges = normalizeTimeChanges(metadata.timeChanges);
		var sections = buildSections(timeChanges, notes, events);

		placeNotes(sections, notes);

		var instrumental = ModernSongRegistry.instrumentalPath(song, difficulty.variation);
		if (instrumental == null)
			return null;

		var vocals = ModernSongRegistry.vocalPaths(song, difficulty.variation);

		var result:SwagSong = {
			song: metadata.songName,
			notes: sections,
			bpm: timeChanges[0].bpm,
			needsVoices: vocals.length > 0,
			speed: scrollSpeed(chart, difficulty.difficulty),
			player1: ModernCompat.character(characters == null ? null : characters.player, 'bf'),
			player2: ModernCompat.character(characters == null ? null : characters.opponent, 'dad'),
			validScore: true
		};

		result.gfVersion = ModernCompat.character(characters == null ? null : characters.girlfriend, 'gf');
		result.stage = ModernCompat.stage(playData.stage);
		result.events = convertEvents(events);
		result.modernId = song.id;
		result.variation = difficulty.variation;
		result.difficultyId = difficulty.difficulty;
		result.instPath = instrumental;
		result.vocalPaths = vocals;

		return result;
	}

	static function normalizeTimeChanges(timeChanges:Array<ModernTimeChange>):Array<ModernTimeChange>
	{
		if (timeChanges == null || timeChanges.length == 0)
			return [{t: 0, bpm: DEFAULT_BPM}];

		var sorted = timeChanges.copy();
		sorted.sort(function(a, b) return a.t < b.t ? -1 : (a.t > b.t ? 1 : 0));

		if (sorted[0].t > 0)
			sorted.unshift({t: 0, bpm: sorted[0].bpm});

		return sorted;
	}

	static function buildSections(timeChanges:Array<ModernTimeChange>, notes:Array<ModernNote>, events:Array<ModernEvent>):Array<SwagSection>
	{
		var endTime:Float = 0;

		for (note in notes)
		{
			var end = note.t + (note.l == null ? 0 : note.l);
			if (end > endTime)
				endTime = end;
		}

		for (event in events)
			if (event.t > endTime)
				endTime = event.t;

		var sections:Array<SwagSection> = [];
		var time:Float = 0;
		var bpm:Float = timeChanges[0].bpm;
		var nextChange:Int = 1;
		var mustHit:Bool = false;
		var nextEvent:Int = 0;

		// One extra section of headroom so the final notes always have a section to live in.
		while (time <= endTime + 1)
		{
			var sectionLength = sectionLengthMs(bpm);
			var changeBPM = false;

			if (nextChange < timeChanges.length && timeChanges[nextChange].t < time + sectionLength)
			{
				bpm = timeChanges[nextChange].bpm;
				sectionLength = sectionLengthMs(bpm);
				changeBPM = true;
				nextChange++;
			}

			// The camera focus in effect when the section starts decides who "owns" it, which
			// is what the legacy note encoding and camera fallback both key off of.
			while (nextEvent < events.length && events[nextEvent].t <= time + 1)
			{
				var event = events[nextEvent];
				if (event.e == 'FocusCamera')
				{
					var target = focusTarget(event.v);
					if (target == 0)
						mustHit = true;
					else if (target == 1)
						mustHit = false;
				}
				nextEvent++;
			}

			sections.push({
				sectionNotes: [],
				lengthInSteps: STEPS_PER_SECTION,
				typeOfSection: 0,
				mustHitSection: mustHit,
				bpm: bpm,
				changeBPM: changeBPM,
				altAnim: false
			});

			time += sectionLength;
		}

		return sections;
	}

	static function placeNotes(sections:Array<SwagSection>, notes:Array<ModernNote>):Void
	{
		if (sections.length == 0)
			return;

		var bounds = sectionBounds(sections);

		for (note in notes)
		{
			var index = sectionIndexFor(bounds, note.t);
			var section = sections[index];

			// Modern data is absolute (0-3 player, 4-7 opponent) while the legacy playfield
			// reads ownership relative to `mustHitSection`, so flip it for opponent sections.
			var data = section.mustHitSection ? note.d : (note.d + 4) % 8;

			section.sectionNotes.push([note.t, data, note.l == null ? 0 : note.l, false, note.k == null ? '' : note.k]);
		}
	}

	static function sectionBounds(sections:Array<SwagSection>):Array<Float>
	{
		var bounds:Array<Float> = [];
		var time:Float = 0;

		for (section in sections)
		{
			bounds.push(time);
			time += sectionLengthMs(section.bpm);
		}

		bounds.push(time);
		return bounds;
	}

	static function sectionIndexFor(bounds:Array<Float>, time:Float):Int
	{
		var low = 0;
		var high = bounds.length - 2;

		while (low < high)
		{
			var mid = low + Std.int((high - low + 1) / 2);
			if (bounds[mid] <= time)
				low = mid;
			else
				high = mid - 1;
		}

		return low < 0 ? 0 : low;
	}

	static function scrollSpeed(chart:ModernChart, difficulty:String):Float
	{
		if (chart.scrollSpeed == null)
			return 1;

		var value = Reflect.field(chart.scrollSpeed, difficulty);
		if (value == null)
			value = Reflect.field(chart.scrollSpeed, 'default');

		if (value == null)
			return 1;

		var speed:Float = value;
		return speed;
	}

	static function convertEvents(events:Array<ModernEvent>):Array<SwagEvent>
	{
		var converted:Array<SwagEvent> = [];

		for (event in events)
			converted.push({time: event.t, kind: event.e, value: event.v});

		return converted;
	}

	/**
	 * `FocusCamera` carries either a bare character index or an object with extra tween data.
	 */
	public static function focusTarget(value:Dynamic):Int
	{
		if (value == null)
			return -1;

		if (Std.isOfType(value, Int) || Std.isOfType(value, Float))
			return Std.int(value);

		var char = Reflect.field(value, 'char');
		return char == null ? -1 : Std.int(char);
	}
}
