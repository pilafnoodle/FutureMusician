import QtQuick 2.0
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.1
import MuseScore 3.0
import Muse.UiComponents 1.0
import FileIO 3.0

MuseScore {
    menuPath: "load xml notes"
    pluginType: "dialog"

    width: 400
    height: 350

    property var uiData: {
        "userInterface": {
            "Instrument": ["Piano Solo", "Piano Duet", "String Quartet", "Orchestra"],
            "character": ["Adventurous", "Cheerful", "Comedic", "Delicate", "Fantasy", "Festive", "Heroic", "Majestic", "Militaristic", "Mysterious", "Ominous", "Peaceful", "Reflective", "Romantic", "Sad", "Urgent"],
            "chordProgression": [
                { "Am-Dm-G-C": ["Am---|Dm9---|G9---|Cmaj9---", "Am---|Dm9---|G---|Cmaj9---"] },
                { "Am-Em-F-C": ["Am---|Em/G---|Fmaj7---|C/E---|Dm9---|Am/C---|B9---|E---"] },
                { "Am-D-Am-D": ["Am9-D9/A-|Am9-D9/A-|Am9-D9/A-|Am9-D9/A-"] },
                { "Am-G#m-Am-Cm": ["Am---|Am---|G#m---|G#m---|Am---|Am---|Cm---|Cm---"] }
            ]
        }
    }
    property var scoreData:{
        "museScoreTemplates": [
            {
            "museScoreFile": "piano_4-4_01.musicxml",
            "Instrument": "Piano Solo",
            "timeSignature": [4, 4],
            "tempo": ["q", 80],
            "duration": 4,
            "chordProgression": ["Am---|Dm9---|G9---|Cmaj9---"],
            "character": ["Heroic"]
            },
            {
            "museScoreFile": "piano_4-4_02.musicxml",
            "Instrument": "Piano Solo",
            "timeSignature": [4, 4],
            "tempo": ["q", 80],
            "duration": 4,
            "chordProgression": ["Am---|Dm9---|G9---|Cmaj9---"],
            "character": ["Delicate"]
            },
            {
            "museScoreFile": "piano_4-4_03.musicxml",
            "Instrument": "Piano Solo",
            "timeSignature": [4, 4],
            "tempo": ["q", 80],
            "duration": 4,
            "chordProgression": ["Am---|Dm9---|G9---|Cmaj9---"],
            "character": ["Sad"]
            },
            {
            "museScoreFile": "piano_4-4_04.musicxml",
            "Instrument": "Piano Solo",
            "timeSignature": [4, 4],
            "tempo": ["q", 80],
            "duration": 4,
            "chordProgression": ["Am---|Dm9---|G9---|Cmaj9---"],
            "character": ["Reflective"]
            },
            {
            "museScoreFile": "piano_4-4_05.musicxml",
            "Instrument": "Piano Solo",
            "timeSignature": [4, 4],
            "tempo": ["q", 80],
            "duration": 4,
            "chordProgression": ["Am---|Dm9---|G9---|Cmaj9---"],
            "character": ["Romantic"]
            },
            {
            "museScoreFile": "piano_4-4_06.musicxml",
            "Instrument": "Piano Solo",
            "timeSignature": [4, 4],
            "tempo": ["q", 80],
            "duration": 4,
            "chordProgression": ["Am---|Dm9---|G9---|Cmaj9---"],
            "character": ["Romantic"]
            },
            {
            "museScoreFile": "piano_4-4_07.musicxml",
            "Instrument": "Piano Solo",
            "timeSignature": [4, 4],
            "tempo": ["q", 80],
            "duration": 4,
            "chordProgression": ["Am---|Dm9---|G9---|Cmaj9---"],
            "character": ["Adventurous"]
            }
        ]
    }
    function toDropdownModel(list) {
        return list.map(function(item) {
            return { text: item }
        });
    }

    function chordProgressionKeys() {
        return uiData.userInterface.chordProgression.map(function(item) {
            return { text: Object.keys(item)[0] }
        });
    }

    function getNumMeasures(xmlText) {
        var measureRegex = /<measure[^>]*\bnumber="(\d+)"/g;
        var match;
        var max = 0;

        while ((match = measureRegex.exec(xmlText)) !== null) {
            var num = parseInt(match[1], 10);
            if (num > max)
                max = num;
        }

        return max;
    }

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

    function rewindToInsertLocation(cursor, numMeasures, insertModeText) {
        cursor.rewind(1);
        if (insertModeText === "before") {
            var measure = cursor.measure;
            for (var i = 0; i < numMeasures; ++i) {
                if (measure && measure.prevMeasure)
                    measure = measure.prevMeasure;
                else
                    break;
            }
            var targetTick = measure ? measure.firstSegment.tick : 0;
            cursor.rewind(0);
            cursor.rewindToTick(targetTick);
        }
    }

    function insertNotes(cursor, noteList, track) {
        cursor.track = track;

        for (var i = 0; i < noteList.length; i++) {
            var note = noteList[i];
            var midiPitch = note[0];
            var typeStr = note[2];
            var stemDir = note[3];
            var dotCount = note[4];
            var baseDur = typeToDurationType(typeStr);
            var z = Math.pow(2, dotCount + 1) - 1;
            var n = baseDur * Math.pow(2, dotCount);
            cursor.setDuration(z, n);
            cursor.addNote(midiPitch);

            var el = cursor.segment.elementAt(cursor.track);
            if (el && el.type === Element.NOTE) {
                var chord = el.parent;
                chord.dots = dotCount;
                el.stemDirection = (stemDir === "up") ? 1 : -1;
            }
        }
    }

    function findMatchingTemplate(instrument, character, progression) {
        var templates = scoreData.museScoreTemplates;
        
        for (var i = 0; i < templates.length; i++) {
            var template = templates[i];
            
            // Check if instrument matches
            if (template.Instrument !== instrument) continue;
            
            // Check if character matches (template.character is an array)
            if (template.character.indexOf(character) === -1) continue;
            
            // Check if chord progression matches
            var templateProgression = template.chordProgression[0]; // Get first chord progression
            var progressionKey = Object.keys(uiData.userInterface.chordProgression.find(function(item) {
                return Object.keys(item)[0] === progression;
            }))[0];
            
            var matchingChords = uiData.userInterface.chordProgression.find(function(item) {
                return Object.keys(item)[0] === progression;
            });
            
            if (matchingChords && matchingChords[progression].indexOf(templateProgression) !== -1) {
                return template;
            }
        }
        
        return null; // No match found
    }

    FileIO {
            id: file
            onError: console.log(msg)
    }
    Item{

        GridLayout {
            columns: 1
            anchors.fill: parent
            anchors.margins: 10
            rowSpacing: 10
            columnSpacing: 20


            Label { text: "Arrangement" }
            StyledDropdown {
                id: arrangement
                model: toDropdownModel(uiData.userInterface.Instrument)
                currentIndex: 0
                onActivated: function(index, value) {
                    currentIndex = index    
                }
            }

            Label { text: "Character" }
            StyledDropdown {
                id: character
                model: toDropdownModel(uiData.userInterface.character)
                currentIndex: 0
                onActivated: function(index, value) {
                    currentIndex = index    
                }
            }

            Label { text: "Chord Progression" }
            StyledDropdown {
                id: progression
                model: chordProgressionKeys()
                currentIndex: 0
                onActivated: function(index, value) {
                    currentIndex = index    
                }
            }
            Label { text: "Insert Mode" }
            StyledDropdown {
                id: insertMode
                model: [
                    { text: "replace" },
                    { text: "before" },
                ]
                currentIndex: 0
                onActivated: function(index, value) {
                    currentIndex = index
                }
            }


        
            Button {
                id: generateButton
                text: qsTranslate("PrefsDialogBase", "Generate")
                onClicked: {

                    var selectedInstrument = uiData.userInterface.Instrument[arrangement.currentIndex];
                    var selectedCharacter = uiData.userInterface.character[character.currentIndex];
                    var selectedProgression = Object.keys(uiData.userInterface.chordProgression[progression.currentIndex])[0];
                    
                    // Find matching template
                    var matchingTemplate = findMatchingTemplate(selectedInstrument, selectedCharacter, selectedProgression);
                    
                    if (!matchingTemplate) {
                        console.log("No matching template found");
                        return;
                    }
                    
                    // Use the matched template file
                    file.source = Qt.resolvedUrl(matchingTemplate.museScoreFile);

                    //file.source = Qt.resolvedUrl("piano_4-4_04.musicxml");
                    var xml = file.read();
            
                    var notes = extractNotes(xml);
                    var cursor = curScore.newCursor();
                    var numMeasures=getNumMeasures(xml);

                    curScore.startCmd();

                    //treble
                    rewindToInsertLocation(cursor, numMeasures, insertMode.model[insertMode.currentIndex].text);
                    insertNotes(cursor, notes.treble, 0);  
                    
                    //bass
                    rewindToInsertLocation(cursor, numMeasures, insertMode.model[insertMode.currentIndex].text);
                    insertNotes(cursor, notes.bass, 4); 

                    curScore.endCmd();
                    Qt.quit();

                }
                
                
            }
        }
    }

    onRun: {
        if (!curScore) {
            Qt.quit();
            return;
        }


    }
}