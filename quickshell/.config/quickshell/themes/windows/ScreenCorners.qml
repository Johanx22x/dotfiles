// NOTHING, AND THAT IS THE ANSWER RATHER THAN A GAP.
//
// Windows rounds WINDOWS, not the screen. themes/windows/theme.json sets
// screenCornerRadius to 0, so the host's four ScreenCorner windows come out
// zero-sized, reserve nothing, take no input and draw nothing, and the
// CornerWedge they would have carved is the empty implementation the interface
// explicitly supports.
//
// The four windows still exist. That is the host's decision and this file has
// no say in it; what it does say is that there is nothing to put in them.

import QtQuick

Item {
    required property var modelData
}
