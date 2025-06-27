import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import MuseScore 3.0
import Muse.UiComponents 1.0

MuseScore {
    version: "1.0"
    title: "Music Generator"
    description: "Dropdown-based music generator"
    pluginType: "dialog"

    width: 700
    height: 250

    property var jsonData: {
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

    function toDropdownModel(list) {
        return list.map(function(item) {
            return { text: item }
        });
    }

    function chordProgressionKeys() {
        return jsonData.userInterface.chordProgression.map(function(item) {
            return { text: Object.keys(item)[0] }
        });
    }

    Item {
        anchors.fill: parent

        GridLayout {
            columns: 2
            anchors.fill: parent
            anchors.margins: 10
            rowSpacing: 10
            columnSpacing: 20

            Label { text: "Arrangement" }
            StyledDropdown {
                id: arrangement
                model: toDropdownModel(jsonData.userInterface.Instrument)
                currentIndex: 0
            }

            Label { text: "Character" }
            StyledDropdown {
                id: character
                model: toDropdownModel(jsonData.userInterface.character)
                currentIndex: 0
            }

            Label { text: "Chord Progression" }
            StyledDropdown {
                id: progression
                model: chordProgressionKeys()
                currentIndex: 0
            }

            Label { text: "" }
            RowLayout {
                spacing: 10

                Button {
                    text: qsTranslate("PrefsDialogBase", "Generate")
                    onClicked: {
                        let selectedArrangement = arrangement.model[arrangement.currentIndex].text;
                        let selectedCharacter = character.model[character.currentIndex].text;
                        let selectedProgressionKey = progression.model[progression.currentIndex].text;

                        let progressionPatterns = jsonData.userInterface.chordProgression.find(function(item) {
                            return item[selectedProgressionKey] !== undefined;
                        })[selectedProgressionKey];

                        console.log("Arrangement:", selectedArrangement);
                        console.log("Character:", selectedCharacter);
                        console.log("Progression:", selectedProgressionKey);
                        console.log("Chord Patterns:", progressionPatterns);

                        // You can now use progressionPatterns[] to insert notes into score
                        quit();
                    }
                }

                Button {
                    text: qsTranslate("PrefsDialogBase", "Cancel")
                    onClicked: {
                        quit();
                    }
                }
            }
        }
    }

    MessageDialog {
        id: errorDialog
        title: "Error"
        text: ""
        onAccepted: quit()
        visible: false
    }

    onRun: {
        if (!curScore) {
            error("No score open.\nThis plugin requires an open score to run.\n")
            quit();
        }
    }
}
