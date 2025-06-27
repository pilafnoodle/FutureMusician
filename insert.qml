import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import MuseScore 3.0
import Muse.UiComponents 1.0

MuseScore {
    version: "1.0"
    title: "Insert C Notes"
    description: "Inserts c at cursor"
    pluginType: "dialog"

    width: 300
    height: 120

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 20

        Button {
            text: "Insert C4 Notes"
            onClicked: {
                if (!curScore) {
                    errorDialog.text = "No score is open.";
                    errorDialog.visible = true;
                    return;
                }

                cursor = curScore.newCursor();
                cursor.rewind(1);
		        curScore.startCmd()
                cursor.addNote("C4", 480); // C4, quarter note (480 ticks)
		        curScore.endCmd()
            

                quit();
            }
        }

        Button {
            text: "Cancel"
            onClicked: quit()
        }
    }

    MessageDialog {
        id: errorDialog
        title: "Error"
        visible: false
        onAccepted: visible = false
    }

    onRun: {
        if (!curScore) {
            errorDialog.text = "No score is open.";
            errorDialog.visible = true;
        }
    }
}
