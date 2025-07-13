import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import MuseScore 3.0
import Muse.UiComponents 1.0
import FileIO 3.0

MuseScore {
    version: "3.0.2"
    title: "modify chord progression"
    description: "Load XML notes and replace chord notes with C"
    menuPath: "load xml notes"
    pluginType: "dialog"

    width: 450
    height: 400

    property var uiData: ({})
    property var scoreData: ({})
    property var chordData: ({})

    property var noteCounter:0;
    property var noteCounters:{};


    property bool dataLoaded: false

    FileIO {
        id: uiDataFile
        source: Qt.resolvedUrl("uiData.json")
    }

    FileIO {
        id: scoreDataFile
        source: Qt.resolvedUrl("scoreData.json")
    }

    FileIO {
        id: chordDataFile
        source: Qt.resolvedUrl("chordSymbolToMIDI.json")
    }

    FileIO {
        id: file
    }

    // Load JSON data functions
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
            
            var chordJson = chordDataFile.read();
            if (chordJson) {
                chordData = JSON.parse(chordJson);
            }

            dataLoaded = true;
            updateDropdownModels();
        } catch (e) {
            dataLoaded = false;
        }
    }

    function updateDropdownModels() {
        if (dataLoaded && uiData.userInterface) {
            var arrangementData = uiData.userInterface.Instrument;
            arrangement.model = toDropdownModel(arrangementData);

            var characterData = uiData.userInterface.character;
            character.model = toDropdownModel(characterData);

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
            return { text: String(item).trim() };
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

    // XML Processing functions
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
            default: return 0;
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

                var noteData = [midi, duration, typeStr, stemDirection, dots];
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
        var matchingTemplates = [];

        for (var i = 0; i < templates.length; i++) {
            var template = templates[i];

            if (template.Instrument !== instrument) continue;

            if (template.character.indexOf(character) === -1) continue;

            var templateProgression = template.chordProgression[0];

            var matchingChords = uiData.userInterface.chordProgression.find(function(item) {
                return Object.keys(item)[0] === progression;
            });

            if (matchingChords && matchingChords[progression].indexOf(templateProgression) !== -1) {
                matchingTemplates.push(template);
            }
        }

        if (matchingTemplates.length === 0) {
            console.log("No matching templates found");
            return -1;
        }

        if (matchingTemplates.length === 1) {
            console.log("Found 1 matching template");
            return matchingTemplates[0];
        }

        var randomIndex = Math.floor(Math.random() * matchingTemplates.length);
        console.log("Found", matchingTemplates.length, "matching templates, randomly selected index:", randomIndex);
        return matchingTemplates[randomIndex];
    }

    function getExistingChordProgression() {
        //chord progression of the default file piano_4-4_01
        return ["Am", "Dm9", "G9", "Cmaj7"];
    }
    
    function getTargetChordProgression(selectedProgression) {
        var selectedProgression = Object.keys(uiData.userInterface.chordProgression[progression.currentIndex])[0];

        return selectedProgression.split("-");
    }
    
    function getSelection() {
        var cursor = curScore.newCursor();
        cursor.rewind(1);
        if (!cursor.segment) {
            return null;
        }
        var selection = {
            cursor: cursor,
            startTick: cursor.tick,
            endTick: null,
            startStaff: cursor.staffIdx,
            endStaff: null,
            startTrack: null,
            endTrack: null
        };
        cursor.rewind(2);
        selection.endStaff = cursor.staffIdx + 1;
        if (cursor.tick == 0) {
            selection.endTick = curScore.lastSegment.tick + 1;
        } else {
            selection.endTick = cursor.tick;
        }
        selection.startTrack = selection.startStaff * 4;
        selection.endTrack = selection.endStaff * 4;
        return selection;
    }
    

    function mapOverTreble(selection, filter) {
        mapOverTracks(selection, filter, 0, 4); // Tracks 0 to 3
    }

    function mapOverBass(selection, filter) {
        mapOverTracks(selection, filter, 4, 8); // Tracks 4 to 7
    }

function getMidiPitchesInPreviousMeasure(currentTick, trackStart, trackEnd) {
    var ticksPerMeasure = 960 * 2;
    var prevMeasureTick = currentTick - ticksPerMeasure;
    if (prevMeasureTick < 0) return {};

    var cursor = curScore.newCursor();
    cursor.rewind(0);
    cursor.rewindToTick(prevMeasureTick);
    var endTick = prevMeasureTick + ticksPerMeasure;

    var pitchesByTrack = {};
    for (var t = trackStart; t < trackEnd; t++) {
        pitchesByTrack[t] = [];
    }

    while (cursor.segment && cursor.tick < endTick) {
        for (var t = trackStart; t < trackEnd; t++) {
            var element = cursor.segment.elementAt(t);
            if (element && element.type === Element.CHORD) {
                for (var n = 0; n < element.notes.length; n++) {
                    pitchesByTrack[t].push(element.notes[n].pitch);
                }
            }
        }
        cursor.next();
    }

    return pitchesByTrack;
}


function mapOverTracks(selection, filter, trackStart, trackEnd) {
    var chordIndex = 0;
    var existingChords = getExistingChordProgression();
    var targetChords = getTargetChordProgression();

    var ticksPerMeasure = 960 * 2;
    var cursor = selection.cursor;
    cursor.rewind(1);

    var startTick = cursor.tick;
    var startMeasure = Math.floor(startTick / ticksPerMeasure);
    var nextMeasureTick = (startMeasure + 1) * ticksPerMeasure;

    var prevChordArray = null;
    var firstNoteBass = true;

    while (cursor.segment && cursor.tick < startTick + (existingChords.length * ticksPerMeasure)) {
        if (cursor.tick >= nextMeasureTick) {
            chordIndex++;
            nextMeasureTick += ticksPerMeasure;
            firstNoteBass = true;  // reset for each measure
        }

        prevChordArray = getMidiPitchesInPreviousMeasure(cursor.tick, trackStart, trackEnd);

        for (var track = trackStart; track < trackEnd; track++) {
            var element = cursor.segment.elementAt(track);

            if (!element || !filter(element)) continue;

            if (track < 4) {
                fixMeasureTreble(element, existingChords, targetChords, chordIndex, prevChordArray[track]);
            } else {
                fixMeasureBass(element, targetChords, chordIndex, prevChordArray[track], firstNoteBass);
                firstNoteBass = false;  // only first note in measure gets root logic
            }
        }

        cursor.next();
    }
}


function fixMeasureTreble(element, existingChords, targetChords, chordIndex, prevPitchArray) {
    var targetChord = targetChords[chordIndex];
    var targetRelativeMidi = chordData.chordSymbolToMIDI[targetChord].midi;

    for (var i = 0; i < element.notes.length; i++) {
        var oldNote = element.notes[i];
        var newNote = cloneNote(oldNote);

        var reference;
        if (!prevPitchArray || i >= prevPitchArray.length) {
            reference = oldNote.pitch;
        } else {
            reference = prevPitchArray[i];
        }

        var bestPitch = findClosestPitch(reference, targetRelativeMidi);
        newNote.pitch = bestPitch;

        element.add(newNote);
        element.remove(oldNote);
    }
}

function fixMeasureBass(element, targetChords, chordIndex, prevPitchArray, firstNoteBass) {
    var targetChord = targetChords[chordIndex];
    var targetRelativeMidi = chordData.chordSymbolToMIDI[targetChord].midi;

    for (var i = 0; i < element.notes.length; i++) {
        var oldNote = element.notes[i];
        var newNote = cloneNote(oldNote);

        var reference = oldNote.pitch;
        if (prevPitchArray && i < prevPitchArray.length) {
            reference = prevPitchArray[i];
        }

        var bestPitch;
        var baseOctave = Math.floor(reference / 12);

        if (firstNoteBass && i === 0) {
            // first note in bass measure always root at base octave
            bestPitch = (targetRelativeMidi[0] % 12) + 12 * baseOctave;
        } else {
            bestPitch = findClosestPitch(reference, targetRelativeMidi);
        }

        newNote.pitch = bestPitch;
        element.add(newNote);
        element.remove(oldNote);
    }
}

    function findClosestPitch(referencePitch, targetMidiArray) {
        var closest = targetMidiArray[0];
        var minDiff = 128;

        for (var i = 0; i < targetMidiArray.length; i++) {
            var pc = targetMidiArray[i] % 12;
            var baseOctave = Math.floor(referencePitch / 12);

            var candidates = [
                pc + 12 * (baseOctave - 1),
                pc + 12 * baseOctave,
                pc + 12 * (baseOctave + 1)
            ];

            for (var j = 0; j < candidates.length; j++) {
                var diff = Math.abs(candidates[j] - referencePitch);
                if (diff < minDiff) {
                    closest = candidates[j];
                    minDiff = diff;
                }
            }
        }

        return closest;
    }

    function cloneNote(original) {
        var note = newElement(Element.NOTE);
        note.tpc1 = original.tpc1;
        note.tpc2 = original.tpc2;
        note.tied = original.tied;
        note.tuning = original.tuning;
        note.visible = original.visible;
        note.userAccidental = original.userAccidental;
        note.velocity = original.velocity;
        note.pitch = original.pitch;
        return note;
    }

    function filterNotes(element) {
        return element.type == Element.CHORD;
    }



    function mapOverAllTracks(selection, filter) {
        mapOverTracks(selection, filter, selection.startTrack, selection.endTrack);
    }
    // UI
    Item {
        anchors.fill: parent

        ScrollView {
            anchors.fill: parent
            anchors.margins: 10
            
            GridLayout {
                columns: 2
                width: parent.width
                columnSpacing: 10
                rowSpacing: 10

                // XML Loading Section
                Label {
                    text: "XML Loading"
                    font.bold: true
                    Layout.columnSpan: 2
                }

                Label { 
                    text: "Arrangement"
                    visible: dataLoaded
                }
                StyledDropdown {
                    id: arrangement
                    model: [{ text: "Loading..." }]
                    currentIndex: 0
                    visible: dataLoaded
                    onActivated: function(index, value) {
                        currentIndex = index;
                    }
                }

                Label { 
                    text: "Character"
                    visible: dataLoaded
                }
                StyledDropdown {
                    id: character
                    model: [{ text: "Loading..." }]
                    currentIndex: 0
                    visible: dataLoaded
                    onActivated: function(index, value) {
                        currentIndex = index;
                    }
                }

                Label { 
                    text: "Chord Progression"
                    visible: dataLoaded
                }
                StyledDropdown {
                    id: progression
                    model: [{ text: "Loading..." }]
                    currentIndex: 0
                    visible: dataLoaded
                    onActivated: function(index, value) {
                        currentIndex = index;
                    }
                }

                Label { 
                    text: "Insert Mode"
                    visible: dataLoaded
                }
                StyledDropdown {
                    id: insertMode
                    model: [
                        { text: "replace" },
                        { text: "before" }
                    ]
                    currentIndex: 0
                    visible: dataLoaded
                    onActivated: function(index, value) {
                        currentIndex = index;
                    }
                }

                // Buttons
                Button {
                    id: generateButton
                    text: "Generate & Transform Chord Progressions"
                    enabled: dataLoaded
                    Layout.columnSpan: 2
                    Layout.topMargin: 20
                    onClicked: {
                        var selectedInstrument = uiData.userInterface.Instrument[arrangement.currentIndex];
                        var selectedCharacter = uiData.userInterface.character[character.currentIndex];
                        var selectedProgression = Object.keys(uiData.userInterface.chordProgression[progression.currentIndex])[0];

                        var matchChords = false;
                        var matchingTemplate = findMatchingTemplate(selectedInstrument, selectedCharacter, selectedProgression);

                        if (matchingTemplate === -1) {
                            file.source = Qt.resolvedUrl("piano_4-4_01.musicxml");
                            matchChords = true;
                        } else {
                            file.source = Qt.resolvedUrl(matchingTemplate.museScoreFile);
                            matchChords = false;
                        }
                        
                        var xml = file.read();
                        var notes = extractNotes(xml);
                        var cursor = curScore.newCursor();
                        var numMeasures = getNumMeasures(xml);

                        curScore.startCmd();

                        // Insert notes
                        rewindToInsertLocation(cursor, numMeasures, insertMode.model[insertMode.currentIndex].text);
                        insertNotes(cursor, notes.treble, 0);  

                        rewindToInsertLocation(cursor, numMeasures, insertMode.model[insertMode.currentIndex].text);
                        insertNotes(cursor, notes.bass, 4); 

                        // Replace all notes with C
                        var selection = getSelection();
                        if (matchChords) {
                            var selection = getSelection();
                            mapOverAllTracks(selection, filterNotes);
                        }

                        curScore.endCmd();
                        Qt.quit();
                    }
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