import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "themediastandard.drive-speedtest"
  ipcTarget: "themediastandard.drive-speedtest"

  property var drives: []
  property int selectedIndex: 0
  property var selectedDrive: null
  property bool loading: false
  property bool running: false
  property bool expectedStop: false
  property string phase: ""
  property string readMBps: ""
  property string writeMBps: ""
  property string error: ""
  property string stderrText: ""

  readonly property string pluginDir: Quickshell.env("HOME") + "/.config/omarchy/plugins/themediastandard.drive-speedtest"
  readonly property real readValue: numericRate(readMBps)
  readonly property real writeValue: numericRate(writeMBps)

  function numericRate(raw) {
    var value = parseFloat(raw)
    return isFinite(value) && value >= 0 ? value : 0
  }

  function displayRate(raw) {
    return raw === "" ? "—" : raw
  }

  function open() {
    root.controller.show()
    root.refreshDrives()
  }

  function close() {
    if (speedProc.running) {
      expectedStop = true
      speedProc.running = false
    }
    running = false
    phase = ""
    root.controller.hide()
  }

  function refreshDrives() {
    if (listProc.running) return
    loading = true
    listProc.running = true
  }

  function moveSelection(delta) {
    if (!drives.length || running) return
    selectedIndex = Math.max(0, Math.min(drives.length - 1, selectedIndex + delta))
  }

  function startSelected() {
    if (running || !drives.length) return
    startTest(selectedIndex)
  }

  function startTest(index) {
    if (running || index < 0 || index >= drives.length) return
    selectedIndex = index
    selectedDrive = drives[index]
    error = ""
    stderrText = ""
    readMBps = ""
    writeMBps = ""
    phase = selectedDrive.kind === "network" ? "write" : "read"
    running = true
    speedProc.command = selectedDrive.kind === "network"
      ? [root.pluginDir + "/network-speedtest", String(selectedDrive.mount)]
      : ["omarchy-disk-speedtest", String(selectedDrive.mount)]
    speedProc.running = true
  }

  function updateLine(line) {
    var parts = String(line).trim().split(/\s+/)
    if (parts.length < 2) return
    if (parts[0] === "read") {
      phase = "read"
      readMBps = parts[1]
    } else if (parts[0] === "write") {
      phase = "write"
      writeMBps = parts[1]
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰋊"
    tooltipText: root.running ? "Testing " + (root.selectedDrive ? root.selectedDrive.display : "drive") : "Test drive speed"
    active: root.running
    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.refreshDrives()
      else root.toggle()
    }
  }

  Process {
    id: listProc
    command: [root.pluginDir + "/list-drives"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(String(text || "[]"))
          root.drives = Array.isArray(parsed) ? parsed : []
          if (root.selectedIndex >= root.drives.length)
            root.selectedIndex = Math.max(0, root.drives.length - 1)
          root.error = ""
        } catch (e) {
          root.drives = []
          root.error = "Could not read the mounted-drive list"
        }
      }
    }
    onExited: function(exitCode) {
      root.loading = false
      if (exitCode !== 0) root.error = "Could not read the mounted-drive list"
    }
  }

  Process {
    id: speedProc
    stdout: SplitParser { onRead: function(line) { root.updateLine(line) } }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.stderrText = String(text || "").trim()
        if (root.error !== "" && root.stderrText !== "") root.error = root.stderrText
      }
    }
    onExited: function(exitCode) {
      if (!root.expectedStop && exitCode !== 0)
        root.error = root.stderrText || "Disk speed test failed"
      root.expectedStop = false
      root.running = false
      root.phase = ""
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) root.moveSelection(dy)
      }
      onActivateRequested: root.startSelected()
      onReturnRequested: root.startSelected()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "r" && !root.running) root.refreshDrives()
      }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: contentColumn
          width: parent.width
          spacing: Style.space(14)

          Item {
            width: parent.width
            implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

            Text {
              id: heroIcon
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: root.running ? "󰑮" : "󰋊"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.displayLarge

              RotationAnimator on rotation {
                running: root.running
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite
              }
            }

            Column {
              id: heroLabels
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(14)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                width: parent.width
                text: root.selectedDrive ? root.selectedDrive.display : "Drive speed test"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: root.running
                  ? (root.phase === "write" ? "MEASURING WRITE SPEED" : "MEASURING READ SPEED")
                  : (root.selectedDrive ? "LAST SELECTED · PRESS ENTER TO TEST AGAIN" : "CHOOSE A MOUNTED DRIVE")
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.1
                elide: Text.ElideRight
              }
            }
          }

          Row {
            visible: root.selectedDrive !== null
            width: parent.width
            spacing: Style.space(10)

            RateCard {
              width: (parent.width - parent.spacing) / 2
              label: "READ"
              value: root.displayRate(root.readMBps)
              live: root.running && root.phase === "read"
            }

            RateCard {
              width: (parent.width - parent.spacing) / 2
              label: "WRITE"
              value: root.displayRate(root.writeMBps)
              live: root.running && root.phase === "write"
            }
          }

          Text {
            visible: root.error !== ""
            width: parent.width
            text: root.error
            color: root.bar.urgent
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.Wrap
          }

          PanelSeparator { foreground: root.bar.foreground }

          Row {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: root.loading ? "FINDING DRIVES…" : "MOUNTED DRIVES"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - refreshButton.width - parent.spacing * 2); height: 1 }

            PanelActionButton {
              id: refreshButton
              iconText: "󰑐"
              tooltipText: "Refresh drives"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              enabled: !root.running && !root.loading
              onClicked: root.refreshDrives()
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(4)

            Repeater {
              model: root.drives

              Rectangle {
                required property var modelData
                required property int index
                width: parent.width
                height: driveLabels.implicitHeight + Style.space(16)
                radius: Style.cornerRadius
                color: index === root.selectedIndex
                  ? Style.hoverFillFor(root.bar.foreground, Color.accent)
                  : "transparent"
                opacity: root.running && root.selectedIndex !== index ? 0.45 : 1

                Column {
                  id: driveLabels
                  anchors.left: parent.left
                  anchors.right: runIcon.left
                  anchors.leftMargin: Style.space(12)
                  anchors.rightMargin: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(2)

                  Text {
                    width: parent.width
                    text: modelData.display
                    color: root.bar.foreground
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: index === root.selectedIndex
                    elide: Text.ElideRight
                  }

                  Text {
                    width: parent.width
                    text: modelData.detail
                    color: Qt.darker(root.bar.foreground, 1.5)
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideMiddle
                  }
                }

                Text {
                  id: runIcon
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(12)
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.running && index === root.selectedIndex ? "󰑮" : ""
                  color: root.bar.foreground
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.body
                }

                MouseArea {
                  anchors.fill: parent
                  enabled: !root.running
                  hoverEnabled: true
                  cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                  onEntered: root.selectedIndex = index
                  onClicked: root.startTest(index)
                }
              }
            }

            Text {
              visible: !root.loading && root.drives.length === 0
              width: parent.width
              text: "No writable drives are mounted. Connect one in Files, then refresh."
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.Wrap
            }
          }

          Text {
            width: parent.width
            text: root.selectedDrive && root.selectedDrive.kind === "network"
              ? "Network tests transfer a temporary 256 MB file and measure the complete computer-to-share path. The file is deleted when finished or cancelled."
              : "Local tests write temporary data, run for about 20 seconds, and delete the test files when finished or cancelled."
            color: Qt.darker(root.bar.foreground, 1.55)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
          }
        }
      }
    }
  }

  component RateCard: Rectangle {
    property string label: ""
    property string value: "—"
    property bool live: false

    implicitHeight: rateColumn.implicitHeight + Style.space(18)
    radius: Style.cornerRadius
    color: live
      ? Style.selectedFillFor(root.bar.foreground, Color.accent)
      : Style.normalFillFor(root.bar.foreground, Color.accent)
    border.width: Style.spacing.hairline
    border.color: live ? Color.accent : Style.normalBorderFor(root.bar.foreground, Color.accent)

    Column {
      id: rateColumn
      anchors.centerIn: parent
      spacing: Style.space(2)

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: label
        color: Qt.darker(root.bar.foreground, 1.4)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 1.1
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(4)

        Text {
          text: value
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.display
          font.bold: true
        }

        Text {
          anchors.baseline: parent.children[0].baseline
          text: "MB/s"
          color: Qt.darker(root.bar.foreground, 1.4)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
