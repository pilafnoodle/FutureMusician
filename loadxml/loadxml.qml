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


    FileIO {
        id: uiDataFile
        source: Qt.resolvedUrl("uiData.json")
    }

    FileIO {
        id: scoreDataFile
        source: Qt.resolvedUrl("scoreData.json")
    }

    function loadJsonData() {
        try {
            var uiJson = uiDataFile.read();
            if (uiJson) {
                uiData = JSON.parse(uiJson);
            }
            var scoreJson = scoreDataFile.read();
            if (scoreJson) {
                scoreData = JSON.parse(scoreJson);
            }

            dataLoaded = true;
            updateDropdownModels();
        } catch (e) {
            dataLoaded = false;
        }
    }

    function updateDropdownModels() {
        if (dataLoaded && uiData.userInterface) {
            
            // Update arrangement dropdown
            var arrangementData = uiData.userInterface.Instrument;
            arrangement.model = toDropdownModel(arrangementData);
            
            // Update character dropdown
            var characterData = uiData.userInterface.character;
            character.model = toDropdownModel(characterData);
            
            // Update progression dropdown
            var progressionData = chordProgressionKeys();
            progression.model = progressionData;
        }
    }

    Component.onCompleted: {
        loadJsonData();
    }

    function toDropdownModel(list) {
        
        if (!list || !Array.isArray(list)) {
            return [{ text: "No data available" }];
        }
        
        var filteredList = list.filter(function(item) {
            return item !== null && item !== undefined && item !== "" && typeof item === "string";
        });
        
        if (filteredList.length === 0) {
            return [{ text: "No valid options" }];
        }
        
        var result = filteredList.map(function(item) {
            return { text: String(item).trim() }; // Ensure it's a string and trim whitespace
        });
        
       return result;
    }

    function chordProgressionKeys() {
        if (!uiData.userInterface || !uiData.userInterface.chordProgression) {
            return [{ text: "No progressions available" }];
        }
        
        var progressions = uiData.userInterface.chordProgression;
        
        if (!Array.isArray(progressions)) {
            return [{ text: "Invalid progression data" }];
        }
        
        var result = [];
        for (var i = 0; i < progressions.length; i++) {
            var item = progressions[i];
            if (item && typeof item === "object") {
                var keys = Object.keys(item);
                if (keys.length > 0) {
                    var key = keys[0];
                    if (key && key !== "" && typeof key === "string") {
                        result.push({ text: key.trim() });
                    }
                }
            }
        }
        
        if (result.length === 0) {
            return [{ text: "No valid progressions found" }];
        }
        
        return result;
    }

    FileIO {
        id: musicXmlFile
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
        if (!scoreData.museScoreTemplates) return null;
        
        var templates = scoreData.museScoreTemplates;
        var matchingTemplates = []; // Array to store all matching templates
        
        for (var i = 0; i < templates.length; i++) {
            var template = templates[i];
            
            // Check if instrument matches
            if (template.Instrument !== instrument) continue;
            
            // Check if character matches (template.character is an array)
            if (template.character.indexOf(character) === -1) continue;
            
            // Check if chord progression matches
            var templateProgression = template.chordProgression[0]; // Get first chord progression
            
            var matchingChords = uiData.userInterface.chordProgression.find(function(item) {
                return Object.keys(item)[0] === progression;
            });
            
            if (matchingChords && matchingChords[progression].indexOf(templateProgression) !== -1) {
                matchingTemplates.push(template); // Add to matching templates array
            }
        }
        
        // If no matches found, return null
        if (matchingTemplates.length === 0) {
            console.log("No matching templates found");
            return null;
        }
        
        // If only one match, return it
        if (matchingTemplates.length === 1) {
            console.log("Found 1 matching template");
            return matchingTemplates[0];
        }
        
        // If multiple matches, randomly select one
        var randomIndex = Math.floor(Math.random() * matchingTemplates.length);
        console.log("Found", matchingTemplates.length, "matching templates, randomly selected index:", randomIndex);
        return matchingTemplates[randomIndex];
    }
    FileIO {
        id: file
    }

    Item {
        GridLayout {
            columns: 1
            anchors.fill: parent
            anchors.margins: 10
            rowSpacing: 10
            columnSpacing: 20

            Column {
                visible: dataLoaded
                Layout.fillWidth: true
                spacing: 10

                Label { text: "Arrangement" }
                StyledDropdown {
                    id: arrangement
                    model: [{ text: "Loading..." }] 
                    currentIndex: 0
                    onActivated: function(index, value) {
                        currentIndex = index    
                    }
                }

                Label { text: "Character" }
                StyledDropdown {
                    id: character
                    model: [{ text: "Loading..." }]
                    currentIndex: 0
                    onActivated: function(index, value) {
                        currentIndex = index    
                    }
                }

                Label { text: "Chord Progression" }
                StyledDropdown {
                    id: progression
                    model: [{ text: "Loading..." }] 
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
                    enabled: dataLoaded
                    onClicked: {


                        var selectedInstrument = uiData.userInterface.Instrument[arrangement.currentIndex];
                        var selectedCharacter = uiData.userInterface.character[character.currentIndex];
                        var selectedProgression = Object.keys(uiData.userInterface.chordProgression[progression.currentIndex])[0];
        
                        // Find matching template
                        var matchingTemplate = findMatchingTemplate(selectedInstrument, selectedCharacter, selectedProgression);
                        

                        // Use the matched template file
                        file.source = Qt.resolvedUrl(matchingTemplate.museScoreFile);
                        var xml = file.read();
                
                        var notes = extractNotes(xml);
                        var cursor = curScore.newCursor();
                        var numMeasures = getNumMeasures(xml);

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
    }
    Item{

        GridLayout {
            columns: 1
            anchors.fill: parent
            anchors.margins: 10
            rowSpacing: 10
            columnSpacing: 20
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
                var numMeasures=getNumMeasures(xml);
                var targetTick = 0;

                curScore.startCmd();


                cursor.rewind(1); // Move to selection start
                if (insertMode.model[insertMode.currentIndex].text === "before") {
                    var measure = cursor.measure;
                    for (var i = 0; i < numMeasures; ++i) {
                        if (measure && measure.prevMeasure)
                            measure = measure.prevMeasure;
                        else
                            break;
                    }
                    if (measure) {
                        targetTick = measure.firstSegment.tick;
                    }
                    cursor.rewind(0);
                    cursor.rewindToTick(targetTick);
                }
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
                        chord.dots = dotCount;
                        el.stemDirection = (stemDir === "up") ? 1 : -1;  //1 is up, -1 is down (stem direction is currently broken)
                    }
                }

                //bass staff
                cursor.rewind(1);
                
                if (insertMode.model[insertMode.currentIndex].text === "before") {

                    var measure = cursor.measure;
                    for (var i = 0; i < numMeasures; ++i) {
                        if (measure && measure.prevMeasure)
                            measure = measure.prevMeasure;
                        else
                            break;
                    }
                    var targetTick = 0;
                    if (measure) {
                        targetTick = measure.firstSegment.tick;
                    }
                    cursor.rewind(0);
                    cursor.rewindToTick(targetTick);

                }
                
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
        }
    }

    onRun: {
        if (!curScore) {
            Qt.quit();
            return;
        }
<<<<<<< HEAD


    }
}
=======
    }
}
>>>>>>> b94f5c15d3f54c0fc721667728f8e6d5ef0b6ef6
