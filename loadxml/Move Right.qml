import QtQuick 2.0
import MuseScore 3.0

MuseScore {
    menuPath: "Plugins.Move/Duplicate Selection.Move Right"
    description: "Moves selection to the Right by an 1/8 note."
    version: "1.0"

    Component.onCompleted : {
        if (mscoreMajorVersion >= 4) {
            title= "Move Right"
            thumbnailName = "right.png"
            categoryCode = "Move selection"
        }
    }

    function moveSelectionRight(byDuration) {
        if (!curScore || !curScore.selection) {
            console.log("No score or selection.");
            return;
        }

        var dur = 4;  // Default duration base
        var cursor = curScore.newCursor();
        cursor.rewind(0);

        while (cursor.segment) {
            var element = cursor.element;
            if (element && element.type === Element.TIMESIG) {
                dur = element.denominator;
                break;
            }
            cursor.next();
        }

        cursor = curScore.newCursor();
        cursor.rewind(2); // end of selection
        var endTick = cursor.tick;
        var endStaff = cursor.staffIdx + 1;
        var endTrack = endStaff * 4;

        cursor.rewind(1); // start of selection
        var startSegTick = curScore.selection.startSegment.tick;
        var startTick = cursor.tick;
        var startStaff = cursor.staffIdx;
        var startTrack = startStaff * 4;

        curScore.startCmd();

        cmd("copy");

        var elements = curScore.selection.elements;
        for (var i in elements) {
            removeElement(elements[i]);
        }

        for (var track = startTrack; track < endTrack; track++) {
            cursor.track = track;
            cursor.rewindToTick(startTick);
            while (cursor.element && cursor.tick < endTick) {
                var e = cursor.element;
                var annotations = cursor.segment.annotations;

                if (e.tuplet) {
                    removeElement(e.tuplet);
                } else {
                    removeElement(e);
                }

                for (var i in annotations) {
                    removeElement(annotations[i]);
                }

                cursor.next();
            }
        }

        cursor.track = startTrack;
        cursor.rewindToTick(startSegTick);

        if (startSegTick != startTick) {
            cursor.setDuration(2 * dur, dur * 2);
            cursor.addRest();
        } else {
            cursor.setDuration(2 * dur, dur);
            cursor.addRest();
        }

        if (cursor.element && cursor.element.type == Element.CHORD) {
            curScore.selection.select(cursor.element.notes[0]);
        } else {
            curScore.selection.select(cursor.element);
        }

        cmd("paste");

        curScore.endCmd();
    }

    onRun: {
        // Call the function here with the desired duration shift
        moveSelectionRight(8);  // Example: move right by an 1/8 note
        Qt.quit();
    }
}
