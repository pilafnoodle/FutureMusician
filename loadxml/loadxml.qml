import QtQuick 2.0
import MuseScore 3.0
import FileIO 3.0


MuseScore {
    menuPath: "load xml notes"

    FileIO {
            id: file
            onError: console.log(msg)
    }

    onRun: {
        if (!curScore) {
            Qt.quit();
            return;
        }

        file.source = Qt.resolvedUrl("piano_4-4_04.musicxml");
        var xml = file.read();


        function typeToDurationType(typeStr) {
            switch(typeStr) {
                case "whole": return 1;
                case "half": return 2;
                case "quarter": return 4;
                case "eighth": return 8;
                case "16th": return 16;
                case "32nd": return 32;
                default: return 0; // quarter note default
            }
        }
    
        function extractNotes(xmlText) {
            var treble = [];
            var bass = [];

            var noteRegex = /<note\b[^>]*>([\s\S]*?)<\/note>/g;
            var match;

            while ((match = noteRegex.exec(xmlText)) !== null) {
                var noteXml = match[1];

                var stepMatch = /<step>([A-G])<\/step>/.exec(noteXml);
                var octaveMatch = /<octave>(\d)<\/octave>/.exec(noteXml);
                var durationMatch = /<duration>(\d+)<\/duration>/.exec(noteXml);
                var staffMatch = /<staff>(\d)<\/staff>/.exec(noteXml);
                var typeMatch = /<type>([^<]+)<\/type>/.exec(noteXml);
                var stemMatch = /<stem>(up|down)<\/stem>/.exec(noteXml);
                var dotMatch = noteXml.match(/<dot\s*[^>]*>/g);
                
                if (stepMatch && octaveMatch && durationMatch && staffMatch) {
                    var step = stepMatch[1];
                    var octave = parseInt(octaveMatch[1]);
                    var duration = parseInt(durationMatch[1]);
                    var staff = parseInt(staffMatch[1]);
                    var stepToSemitone = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 };
                    var midi = 12 * (octave + 1) + stepToSemitone[step];
                    var typeStr = typeMatch ? typeMatch[1] : "quarter";
                    var stemDirection = stemMatch ? stemMatch[1] : "up";  
                    var dots = dotMatch ? dotMatch.length : 0;

                    var noteData = [midi, duration, typeStr,stemDirection,dots];
                    if (staff === 1)
                        treble.push(noteData);
                    else if (staff === 2)
                        bass.push(noteData);
                }
            }
            return { treble: treble, bass: bass };
        }
        var notes = extractNotes(xml);

        var cursor = curScore.newCursor();
        curScore.startCmd();

        //(staff 1 = track 0), each staff can have a maximum of 4 voices (tracks)
        //treble staff
        cursor.rewind(1);
        cursor.track = 0;
        for (var i = 0; i < notes.treble.length; i++) {
            var note = notes.treble[i];
            var midiPitch = note[0];
            var typeStr = note[2];
            var stemDir = note[3];
            var dotCount = note[4];

            var baseDur = typeToDurationType(typeStr)  
            var z = Math.pow(2, dotCount + 1) - 1      
            var n = baseDur * Math.pow(2, dotCount)   
            cursor.setDuration(z, n)

            cursor.addNote(midiPitch);

            var el = cursor.segment.elementAt(cursor.track);
            if (el && el.type === Element.NOTE) {
                var chord = el.parent;
                chord.dots = dots;
                el.stemDirection = (stemDir === "up") ? 1 : -1;  //1 is up, -1 is down (stem direction is currently broken)
            }
        }

        //bass staff
        cursor.rewind(1);
        cursor.track = 4;
        for (var j = 0; j < notes.bass.length; j++) {
            var note = notes.bass[j];
            var midiPitch = note[0];
            var typeStr = note[2];
            var stemDir = note[3];
            var dotCount = note[4];

            var baseDur = typeToDurationType(typeStr)  
            var z = Math.pow(2, dotCount + 1) - 1      
            var n = baseDur * Math.pow(2, dotCount)   
            cursor.setDuration(z, n)

            cursor.addNote(midiPitch);

            var el = cursor.segment.elementAt(cursor.track);
            
            if (el && el.type === Element.NOTE) {
                var chord = el.parent;
                chord.dots = dotCount;
                el.stemDirection = (stemDir === "up") ? 1 : -1;
            }
        }
        curScore.endCmd();
        Qt.quit();
    }
}


