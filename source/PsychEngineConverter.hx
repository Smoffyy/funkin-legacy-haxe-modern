package;

import Section.SwagSection;
import haxe.Json;

/**
 * Converter for Psych Engine chart format to vanilla FNF format
 * Handles the differences in JSON structure between engines
 */
class PsychEngineConverter
{
    /**
     * Detect if a JSON string is in Psych Engine format
     * @param rawJson The raw JSON string to check
     * @return True if it's a Psych Engine chart
     */
    public static function isPsychFormat(rawJson:String):Bool
    {
        try
        {
            var jsonData:Dynamic = Json.parse(rawJson);
            
            // Check for Psych Engine format identifier
            if (Reflect.hasField(jsonData, "format"))
            {
                var format:String = Reflect.field(jsonData, "format");
                return format == "psych_v1_convert" || format.indexOf("psych") != -1;
            }
            
            // Also check if it's flat structure (no "song" wrapper) with Psych-specific fields
            if (!Reflect.hasField(jsonData, "song") && Reflect.hasField(jsonData, "notes"))
            {
                // Check for Psych-specific fields like gfVersion, events, or validScore at root
                return Reflect.hasField(jsonData, "gfVersion") || 
                       Reflect.hasField(jsonData, "events") ||
                       (Reflect.hasField(jsonData, "validScore") && Reflect.hasField(jsonData, "player1"));
            }
            
            return false;
        }
        catch (e:Dynamic)
        {
            trace("Error detecting Psych format: " + e);
            return false;
        }
    }
    
    /**
     * Convert Psych Engine format to vanilla format
     * @param rawJson The raw Psych Engine JSON string
     * @return Converted JSON string in vanilla format
     */
    public static function convertToVanilla(rawJson:String):String
    {
        try
        {
            var psychData:Dynamic = Json.parse(rawJson);
            
            // Create vanilla format structure
            var vanillaData:Dynamic = {
                song: {}
            };
            
            var songData:Dynamic = vanillaData.song;
            
            // Copy basic song properties
            if (Reflect.hasField(psychData, "song"))
                Reflect.setField(songData, "song", Reflect.field(psychData, "song"));
            else
                Reflect.setField(songData, "song", "Unknown");
                
            if (Reflect.hasField(psychData, "bpm"))
                Reflect.setField(songData, "bpm", Reflect.field(psychData, "bpm"));
            else
                Reflect.setField(songData, "bpm", 100);
                
            if (Reflect.hasField(psychData, "speed"))
                Reflect.setField(songData, "speed", Reflect.field(psychData, "speed"));
            else
                Reflect.setField(songData, "speed", 1.0);
                
            if (Reflect.hasField(psychData, "needsVoices"))
                Reflect.setField(songData, "needsVoices", Reflect.field(psychData, "needsVoices"));
            else
                Reflect.setField(songData, "needsVoices", true);
                
            if (Reflect.hasField(psychData, "player1"))
                Reflect.setField(songData, "player1", Reflect.field(psychData, "player1"));
            else
                Reflect.setField(songData, "player1", "bf");
                
            if (Reflect.hasField(psychData, "player2"))
                Reflect.setField(songData, "player2", Reflect.field(psychData, "player2"));
            else
                Reflect.setField(songData, "player2", "dad");
            
            // Always set validScore to true for compatibility
            Reflect.setField(songData, "validScore", true);
            
            // Convert notes sections
            var psychNotes:Array<Dynamic> = Reflect.field(psychData, "notes");
            var vanillaNotes:Array<Dynamic> = [];
            
            if (psychNotes != null)
            {
                for (section in psychNotes)
                {
                    var vanillaSection:Dynamic = convertSection(section);
                    vanillaNotes.push(vanillaSection);
                }
            }
            
            Reflect.setField(songData, "notes", vanillaNotes);
            
            return Json.stringify(vanillaData);
        }
        catch (e:Dynamic)
        {
            trace("Error converting Psych format: " + e);
            trace("Returning original JSON");
            return rawJson;
        }
    }
    
    /**
     * Convert a Psych Engine section to vanilla section format
     * @param psychSection The Psych Engine section object
     * @return Converted vanilla section object
     */
    private static function convertSection(psychSection:Dynamic):Dynamic
    {
        var vanillaSection:Dynamic = {};
        
        // Get mustHitSection value first (needed for note lane conversion)
        var mustHitSection:Bool = true;
        if (Reflect.hasField(psychSection, "mustHitSection"))
            mustHitSection = Reflect.field(psychSection, "mustHitSection");
        
        // Copy and convert sectionNotes
        // IMPORTANT: Psych Engine and vanilla handle note lanes differently!
        // In Psych: When mustHitSection is false, lanes need to be swapped
        // In Vanilla: Lanes are already in correct positions
        if (Reflect.hasField(psychSection, "sectionNotes"))
        {
            var psychNotes:Array<Dynamic> = Reflect.field(psychSection, "sectionNotes");
            var convertedNotes:Array<Dynamic> = [];
            
            for (note in psychNotes)
            {
                if (note != null && note.length >= 2)
                {
                    var noteTime:Float = note[0];
                    var noteData:Int = Std.int(note[1]);
                    var noteSustain:Float = note.length >= 3 ? note[2] : 0;
                    var noteType:String = note.length >= 4 ? note[3] : "";
                    
                    // Swap note lanes if mustHitSection is false
                    // This is the key difference between Psych and vanilla!
                    if (!mustHitSection)
                    {
                        if (noteData < 4)
                        {
                            // Opponent note (0-3) -> swap to player side (4-7)
                            noteData = noteData + 4;
                        }
                        else if (noteData >= 4)
                        {
                            // Player note (4-7) -> swap to opponent side (0-3)
                            noteData = noteData - 4;
                        }
                    }
                    
                    // Rebuild note array with converted lane
                    var convertedNote:Array<Dynamic> = [noteTime, noteData, noteSustain];
                    if (noteType != "")
                        convertedNote.push(noteType);
                    
                    convertedNotes.push(convertedNote);
                }
            }
            
            Reflect.setField(vanillaSection, "sectionNotes", convertedNotes);
        }
        else
        {
            Reflect.setField(vanillaSection, "sectionNotes", []);
        }
        
        // Convert sectionBeats to lengthInSteps
        // Psych uses sectionBeats (usually 4), vanilla uses lengthInSteps (usually 16)
        // Formula: lengthInSteps = sectionBeats * 4
        if (Reflect.hasField(psychSection, "sectionBeats"))
        {
            var sectionBeats:Float = Reflect.field(psychSection, "sectionBeats");
            Reflect.setField(vanillaSection, "lengthInSteps", Std.int(sectionBeats * 4));
        }
        else if (Reflect.hasField(psychSection, "lengthInSteps"))
        {
            Reflect.setField(vanillaSection, "lengthInSteps", Reflect.field(psychSection, "lengthInSteps"));
        }
        else
        {
            Reflect.setField(vanillaSection, "lengthInSteps", 16); // Default
        }
        
        // Copy mustHitSection (already extracted above)
        Reflect.setField(vanillaSection, "mustHitSection", mustHitSection);
        
        // Copy typeOfSection
        if (Reflect.hasField(psychSection, "typeOfSection"))
            Reflect.setField(vanillaSection, "typeOfSection", Reflect.field(psychSection, "typeOfSection"));
        else
            Reflect.setField(vanillaSection, "typeOfSection", 0);
        
        // Copy BPM fields
        if (Reflect.hasField(psychSection, "bpm"))
            Reflect.setField(vanillaSection, "bpm", Reflect.field(psychSection, "bpm"));
        else
            Reflect.setField(vanillaSection, "bpm", 0);
            
        if (Reflect.hasField(psychSection, "changeBPM"))
            Reflect.setField(vanillaSection, "changeBPM", Reflect.field(psychSection, "changeBPM"));
        else
            Reflect.setField(vanillaSection, "changeBPM", false);
        
        // Copy altAnim
        if (Reflect.hasField(psychSection, "altAnim"))
            Reflect.setField(vanillaSection, "altAnim", Reflect.field(psychSection, "altAnim"));
        else
            Reflect.setField(vanillaSection, "altAnim", false);
        
        return vanillaSection;
    }
    
    /**
     * Get info about a Psych Engine chart (for debugging)
     * @param rawJson The raw Psych Engine JSON string
     * @return String with chart information
     */
    public static function getChartInfo(rawJson:String):String
    {
        try
        {
            var psychData:Dynamic = Json.parse(rawJson);
            var info:String = "=== Psych Engine Chart Info ===\n";
            
            if (Reflect.hasField(psychData, "song"))
                info += "Song: " + Reflect.field(psychData, "song") + "\n";
            if (Reflect.hasField(psychData, "format"))
                info += "Format: " + Reflect.field(psychData, "format") + "\n";
            if (Reflect.hasField(psychData, "bpm"))
                info += "BPM: " + Reflect.field(psychData, "bpm") + "\n";
            if (Reflect.hasField(psychData, "speed"))
                info += "Speed: " + Reflect.field(psychData, "speed") + "\n";
            if (Reflect.hasField(psychData, "player1"))
                info += "Player 1: " + Reflect.field(psychData, "player1") + "\n";
            if (Reflect.hasField(psychData, "player2"))
                info += "Player 2: " + Reflect.field(psychData, "player2") + "\n";
            if (Reflect.hasField(psychData, "gfVersion"))
                info += "GF Version: " + Reflect.field(psychData, "gfVersion") + "\n";
            if (Reflect.hasField(psychData, "stage"))
                info += "Stage: " + Reflect.field(psychData, "stage") + "\n";
            
            var notes:Array<Dynamic> = Reflect.field(psychData, "notes");
            if (notes != null)
                info += "Sections: " + notes.length + "\n";
            
            info += "===============================";
            return info;
        }
        catch (e:Dynamic)
        {
            return "Error getting chart info: " + e;
        }
    }
}
