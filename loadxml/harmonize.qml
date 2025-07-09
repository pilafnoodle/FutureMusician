// Harmonize Melodies
// Copyright (C) 2025 Sam Wymann
//
// Based on Bill Hails mirror_intervals plugin - Thanks Bill!
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
// JavaScript 1.5 / ECMA 262
//
// 

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import MuseScore 3.0
import Muse.UiComponents 1.0

MuseScore {
	version: "3.0.2"
	title: "Harmonize Melodies"
	description: "Harmonize Melodies"
	pluginType: "dialog"
	categoryCode: "composing-arranging-tools"
	thumbnailName: "harmonize.png"

	// ---- UI definition -----------
	
	width: 300
	height: 200

	Item {
		anchors.fill: parent

		GridLayout {
			columns: 2
			anchors.fill: parent
			anchors.margins: 10
			
			Label {
				text: "Root"
			}
			StyledDropdown {
				id: rootNote
				model: [
					{ text: "C",  note: 0 },
					{ text: "C♯", note: 1  },
					{ text: "D",  note: 2  },
					{ text: "E♭",  note: 3  },
					{ text: "E",  note: 4  },
					{ text: "F",  note: 5  },
					{ text: "F♯", note: 6  },
					{ text: "G",  note: 7  },
					{ text: "G♯", note: 8  },
					{ text: "A",  note: 9  },
					{ text: "B♭",  note: 10 },
					{ text: "B",  note: 11 }					
				]
				currentIndex: 0
				onActivated: function(index, value) {
					currentIndex = index
				}
			}
			
			Label {
				text: "Mode"
			}
			StyledDropdown {
				id: mode
				model: [
					{ text: "ION",  notes: [0,2,4,5,7,9,11]    },
					{ text: "MMA",  notes: [0,2,3,5,7,9,11]    },
					{ text: "HM",   notes: [0,1,3,5,7,8,11]    },
					{ text: "WT",   notes: [0,2,4,6,8]         },
					{ text: "HTWT", notes: [0,1,3,4,6,7,9,10]  }
				]
				currentIndex: 0
				onActivated: function(index, value) {
					currentIndex = index
				}
			}	
			
			Label {
				text: "Transforms"
			}
			StyledDropdown {
				id: transform
				model: [
					{ text: "3rd Cluster        ",  additions: [-1,-2]    },
					{ text: "4th Cluster add 2nd",  additions: [-1,-3]    },
					{ text: "4th Cluster add 3rd",  additions: [-2,-3]    },
					{ text: "5th Block",            additions: [-2,-5,-11]},
					{ text: "3rd Block",            additions: [-2,-5,-9] },
					{ text: "7th Block",            additions: [-2,-4,-6] },
					{ text: "7th d2 Block",         additions: [-4,-6,-9] },
					{ text: "7th d3 Block",         additions: [-2,-6,-11]}
				]
				currentIndex: 0
				onActivated: function(index, value) {
					currentIndex = index
				}
			}						
			
			Button {
				id: applyButton
				text: qsTranslate("PrefsDialogBase", "Apply")
				onClicked: {
					applyHarmony()
					quit()
				}
			}
			Button {
				id: cancelButton
				text: qsTranslate("PrefsDialogBase", "Cancel")
				onClicked: {
					quit()
				}
			}
		}
	}

	MessageDialog {
		id: errorDialog
		title: "Error"
		text: ""
		onAccepted: {
			quit()
		}
		visible: false
	}		

	onRun: {
		if (!curScore) {
			error("No score open.\nThis plugin requires an open score to run.\n")
			quit()
		}
	}
	
	// --------------- functions ----------------------------------------------

	function filterNotes(element) {
		return element.type == Element.CHORD
	}

	function getSelection() {
		var cursor = curScore.newCursor()
		cursor.rewind(1)
		if (!cursor.segment) {
			return null
		}
		var selection = {
			cursor: cursor,
			startTick: cursor.tick,
			endTick: null,
			startStaff: cursor.staffIdx,
			endStaff: null,
			startTrack: null,
			endTrack: null
		}
		cursor.rewind(2)
		selection.endStaff = cursor.staffIdx + 1
		if (cursor.tick == 0) {
			selection.endTick = curScore.lastSegment.tick + 1
		} else {
			selection.endTick = cursor.tick
		}
		selection.startTrack = selection.startStaff * 4
		selection.endTrack = selection.endStaff * 4
		return selection
	}

	function getRootNote() {
		return rootNote.model[rootNote.currentIndex].note
	}
	
	function getModeNotes() {
		return mode.model[mode.currentIndex].notes
	}
	
	function getTransformAdditions() {
		return transform.model[transform.currentIndex].additions
	}

	function error(errorMessage) {
		errorDialog.text = qsTr(errorMessage)
		errorDialog.open()
	}
		
	// ----- Main ----------------------------------------------------
	function applyHarmony() {
		var selection = getSelection()
		if (!selection) {
			error("No selection.\nThis plugin requires a current selection to run.\n")
			quit()
		}
		curScore.startCmd()
		mapOverSelection(selection, filterNotes)
		curScore.endCmd()
	}

	function mapOverSelection(selection, filter) {
		selection.cursor.rewind(1)
		for (
			var segment = selection.cursor.segment;
			segment && segment.tick < selection.endTick;
			segment = segment.next
			) {
			for (var track = selection.startTrack; track < selection.endTrack; track++) {
				var element = segment.elementAt(track)
				if (element) {
					if (filter(element)) {
						myProcess(element, track)
					}
				}
			}
		}
	}
	
	function cloneNote(original) {
		var note = newElement(Element.NOTE)
		note.tpc1 = original.tpc1
		note.tpc2 = original.tpc2
		note.tied = original.tied 
		note.tuning = original.tuning 
		note.visible = original.visible 
		note.userAccidental = original.userAccidential
		note.velocity = original.velocity
		note.pitch = original.pitch
		return note 
	}
	
	function divmod(x,y) { 
		var q=Math.floor(x/y)
		var r=x-(q*y)
		return {q: q, r: r } // octave, note 
	}
	
	function isDiatonic(note) {
		var realativePitch=note.pitch-getRootNote()
		if (realativePitch < 0) {
			return false
		}
		var relative=divmod(realativePitch,12)
		return getModeNotes().indexOf(relative.r) > -1
	}

	function transformPitch(top,tvalue) {
		var r=getRootNote()
		var s=top.pitch-r            // project down to C 
		if (s < 0) {
			return -1
		}
		var t=divmod(s,12)           // split into octave, pitch
		var mn=getModeNotes()
		var i=mn.indexOf(t.r)                    // find index of note in mode
		var o=divmod(i+tvalue,mn.length)         // find index of transformed note 
    var nn=mn[o.r]               // lookupn new note 	
		var p=nn+12*o.q+12*t.q+r
		return p
	}
	
	function addTransform(tvalue, top, element) {
		var note = cloneNote(top)
		var newpitch = transformPitch(top,tvalue)
		if (newpitch < 0) {
			return 
		}
		var note = cloneNote(top)
		note.pitch = newpitch 
		element.add(note)
	}
	
	function myProcess(element, track) {
		var top = element.notes[element.notes.length-1]
		if (!isDiatonic(top)) {
			return
		}
		var ary = getTransformAdditions()
		for (var i=0;i<ary.length;i++) {
			addTransform(ary[i], top, element)
		}
	}		
}
