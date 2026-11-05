import QtQuick
import "Utils.js" as Utils
import QtQuick.Controls 2.15
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.iconthemes as KIconThemes

FocusScope {
    id: rootScope

    property var mo: appsModel
    property var modelExe: rootModel.modelForRow(0)
    property var searchModel: runnerModel.count > 0 ? runnerModel.modelForRow(0) : null
    property bool listGeneralActive: listActive === "generalList"

    readonly property var modelActive: activeGroup ? folderAppModel : listGeneralActive ? mo : searchModel

    property bool visibleApps: true

    signal openGridApp(int ID)


    // Configuración de la cuadrícula
    readonly property int maxItemsPerRow: Math.max(1, Math.floor((width*.8)/cellWidth))
    readonly property int maxItemsPerColumn: Math.max(1, Math.floor((height - cellHeight)/cellHeight))

    property real horizonBar: (Math.ceil(folderAppModel.count/maxItemsPerRow) < 3 ? Math.ceil(folderAppModel.count/maxItemsPerRow) :3)

    readonly property int cellWidth: Plasmoid.configuration.cellSize
    readonly property int cellHeight: Plasmoid.configuration.cellSize
    readonly property int iconSize: Plasmoid.configuration.iconSize
    readonly property int marginPage: /*/activeGroup ? 0 :/*/ (width - (cellWidth*maxItemsPerRow))/2
    readonly property int itemsPerPage: Math.max(1, maxItemsPerRow * maxItemsPerColumn)


    // FIX: jumlah item diambil dari jumlah delegate yang benar-benar dibuat.
    // Versi lama memakai `model.index` dari delegate terakhir, sehingga totalPages
    // terlalu kecil dan halaman tengah tidak bisa dicapai.
    readonly property int itemCount: (typeof appsRepeater !== "undefined" && appsRepeater) ? appsRepeater.count : 0
    readonly property int totalPages: Math.max(1, Math.ceil(itemCount / itemsPerPage))

    property string nameActiveGroup
    property int activeIndex

    // Cooldown agar satu gestur trackpad (banyak event wheel) tidak melompati
    // beberapa halaman sekaligus — dulu ini bikin cuma bisa mendarat di halaman
    // pertama atau terakhir.
    property double lastPageSwitch: 0

    property int marginMinimalGroup: activeGroup ? folderAppModel.count < maxItemsPerRow ? ((maxItemsPerRow - folderAppModel.count)*cellWidth)/2 : 0 : 0

    onTotalPagesChanged: {
        // Kalau jumlah halaman menyusut (mis. setelah search), jaga currentPage tetap valid
        if (currentPage > totalPages - 1) {
            currentPage = Math.max(0, totalPages - 1)
        }
    }

    // ── Wheel / 2 jari (trackpad) ───────────────────────────────
    // Grid-nya horizontal, jadi gestur 2 jari KIRI↔KANAN yang dipakai (sumbu X).
    // Trackpad di Wayland mengirim pixelDelta (angleDelta = 0) untuk smooth
    // scrolling; mouse wheel / Shift+wheel mengirim angleDelta.
    property real wheelAccum: 0
    property double lastWheelActivity: 0
    property bool wheelGestureUsed: false

    function handleWheel(angleX, angleY, pixelX, pixelY) {
        var now = Date.now()

        // Gestur dianggap selesai kalau 400 ms tidak ada event lagi
        if (now - lastWheelActivity > 400) {
            wheelAccum = 0
            wheelGestureUsed = false
        }
        lastWheelActivity = now

        console.log("APPBAY-WHEEL ax=" + angleX + " ay=" + angleY + " px=" + pixelX + " py=" + pixelY)

        var isTouchpad = (angleX === 0 && angleY === 0 && (pixelX !== 0 || pixelY !== 0))

        // 1 gestur 2 jari = 1 halaman
        if (isTouchpad && wheelGestureUsed)
            return
        if (now - lastPageSwitch < 300)
            return

        // Prioritas sumbu X (kiri/kanan). Y hanya fallback kalau trackpad /
        // sistem tidak mengirim komponen horizontal.
        var amount = 0
        if (angleX !== 0)
            amount = angleX / 120
        else if (pixelX !== 0)
            amount = pixelX / 60
        else if (angleY !== 0)
            amount = angleY / 120
        else if (pixelY !== 0)
            amount = pixelY / 60

        if (amount === 0)
            return

        wheelAccum += amount
        if (Math.abs(wheelAccum) < 1)
            return

        // geser ke kiri (delta negatif) = halaman berikutnya
        var step = wheelAccum < 0 ? 1 : -1
        wheelAccum = 0
        lastPageSwitch = now
        wheelGestureUsed = isTouchpad
        console.log("APPBAY-PAGE -> " + (currentPage + step))
        goToPage(currentPage + step)
    }

    // Satu-satunya jalan untuk pindah halaman (dipakai wheel, swipe, dan klik titik)
    function goToPage(targetPage) {
        var lastPage = Math.max(0, totalPages - 1)
        var page = Math.max(0, Math.min(lastPage, targetPage))
        if (page === currentPage)
            return
        iconsAnamitaionInitialLoad = true
        currentPage = page
    }

    function handleCreateGroup(index, item1, item2) {
        var groupIndex = subModel ? subModel.length + 1 : 1
        var newGroupName = "Group " + groupIndex

        // Crear grupo para subModel
        var newGroup = {
            displayGrupName: newGroupName,
            indexInModel: index,
            isGroup: true,
            elements: [
                { display: item1.display, decoration: item1.decoration, appIndex: item1.appIndex },
                { display: item2.display, decoration: item2.decoration, appIndex: item2.appIndex }
            ]
        }

        subModel.push(newGroup)
        saveSubModel()

        Utils.removeByAppIndex(item1.appIndex)
        Utils.removeByAppIndex(item2.appIndex)

        // Crear array JS puro para modelGroup
        var groupArray = [
            { display: item1.display, decoration: item1.decoration, appIndex: item1.appIndex },
            { display: item2.display, decoration: item2.decoration, appIndex: item2.appIndex }
        ]

        // Insertar grupo “vacío” primero
        appsModel.insert(index, {
            display: newGroupName,
            decoration: "",
            isGroup: true,
            modelGroup: [] // vacío temporal
        })

        // Actualizar inmediatamente con array JS puro para forzar render
        appsModel.set(index, {
            display: newGroupName,
            decoration: "",
            isGroup: true,
            modelGroup: groupArray
        })
        activeAnimations = false
        activeGroup = !activeGroup
        activeGroup = !activeGroup
        activeAnimations = true
    }







    function handleAddToGroup(targetIndex, draggedItem) {

        var target = appsModel.get(targetIndex)
        if (!target) {
            return
        }

        // Convertir a array real si es necesario
        var arrayModelGroup = Utils.toArray(target.modelGroup)

        arrayModelGroup.push({
            display: draggedItem.display,
            decoration: draggedItem.decoration,
            appIndex: draggedItem.appIndex
        })


        // ⚡ Actualizar subModel también
        for (var i = 0; i < subModel.length; i++) {
            if (subModel[i].displayGrupName === target.display) {
                subModel[i].elements = Utils.cloneToPureArray(arrayModelGroup)
                break
            }
        }

        // ⚡ Actualizar appsModel
        appsModel.set(targetIndex, {
            modelGroup: arrayModelGroup,
            display: target.display,
            isGroup: true
        })

        saveSubModel()

        Utils.removeByAppIndex(draggedItem.appIndex)
    }

    Kirigami.PromptDialog {
        id: rename
        title: "Rename Group"
        subtitle: "Enter a new name for this group"
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        preferredWidth: 320
        //preferredHeight: 188

        TextField {
            id: nameField
            width: parent.width
            height: 48
            horizontalAlignment: Text.AlignHCenter
            placeholderText: nameActiveGroup
            anchors.horizontalCenter: parent.horizontalCenter
            //leftPadding: 28 // Espacio fijo para el icono
            focus: true
            selectByMouse: true // Permitir selección de texto con mouse

            background: Rectangle {
                color: entryDialogColor
                radius: height/2
                opacity: 0.3
            }
        }
        onAccepted: {
            if (nameField.text.trim() !== "") {
                nameActiveGroup = nameField.text.trim()
                Utils.renameGroup(activeIndex, nameActiveGroup)
            }
        }
    }

    Item {
        id: gridRoot
        width: parent.width
        height:  parent.height
        //Visible: visibleApps

        // FIX: handler di level grid -> wheel/two-finger scroll tetap bekerja
        // walaupun kursor berada di atas ikon aplikasi (bukan hanya area kosong)
        WheelHandler {
            id: pageWheelHandler
            onWheel: function(event) {
                var ax = pageWheelHandler.angleDelta ? pageWheelHandler.angleDelta.x : 0
                var ay = pageWheelHandler.angleDelta ? pageWheelHandler.angleDelta.y : 0
                var px = pageWheelHandler.pixelDelta ? pageWheelHandler.pixelDelta.x : 0
                var py = pageWheelHandler.pixelDelta ? pageWheelHandler.pixelDelta.y : 0
                if (ax === 0 && ay === 0 && px === 0 && py === 0)
                    return
                rootScope.handleWheel(ax, ay, px, py)
            }
        }

        MouseArea {
            id: backgroundArea
            anchors.fill: parent
            propagateComposedEvents: true

            // Deteksi swipe horizontal (drag / trackpad) untuk pindah halaman
            property real pressX: 0
            property real pressY: 0
            property bool didSwipe: false

            onPressed: function(mouse) {
                pressX = mouse.x
                pressY = mouse.y
                didSwipe = false
            }

            onPositionChanged: function(mouse) {
                if (!pressed)
                    return
                var dx = mouse.x - pressX
                var dy = mouse.y - pressY
                // Satu swipe = satu halaman (tidak reset pressX supaya tidak
                // beruntun melewati halaman tengah)
                if (!didSwipe && Math.abs(dx) > 70 && Math.abs(dx) > Math.abs(dy) * 1.5) {
                    didSwipe = true
                    rootScope.goToPage(currentPage + (dx < 0 ? 1 : -1))
                }
            }

            onWheel: function(wheel) {
                var ax = wheel.angleDelta ? wheel.angleDelta.x : 0
                var ay = wheel.angleDelta ? wheel.angleDelta.y : 0
                var px = wheel.pixelDelta ? wheel.pixelDelta.x : 0
                var py = wheel.pixelDelta ? wheel.pixelDelta.y : 0
                if (ax !== 0 || ay !== 0 || px !== 0 || py !== 0)
                    rootScope.handleWheel(ax, ay, px, py)
                wheel.accepted = true
            }

            onClicked: function(mouse) {
                if (didSwipe) {
                    didSwipe = false
                    return
                }
                if (activeGroup) {
                    activeGroup = false
                    currentPage = oldPage
                } else {
                    // cuando se da click fuera del area de los iconos se cerrara el menu
                    dashboard.toggle()
                }

            }
        }


        Item {
            id: wrapper
            width: activeGroup ? (folderAppModel.count < maxItemsPerRow) ? folderAppModel.count*cellWidth : maxItemsPerRow*cellWidth : parent.width

            height: activeGroup ? horizonBar*cellHeight : parent.height

            property int marginFirstPageGroup: activeGroup ? (gridRoot.width-width)/2 : 0

            Behavior on anchors.leftMargin {
                enabled: iconsAnamitaionInitialLoad
                NumberAnimation {
                    id: marginAnimation
                    duration: 200
                    easing.type: Easing.InOutQuad

                    onRunningChanged: {
                        if (!running) {
                            iconsAnamitaionInitialLoad = false
                        }
                    }
                }
            }

            anchors.left: parent.left
            anchors.leftMargin: ((parent.width - width)/2) - currentPage * gridRoot.width - marginFirstPageGroup + marginMinimalGroup //activeGroup ? ((parent.width - width)/2) : ((parent.width - width)/2) - currentPage * gridRoot.width
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: bgGroup
                width: !activeGroup ? 0 : parent.width
                height: !activeGroup ? 0 :parent.height
                anchors.left: parent.left
                anchors.leftMargin: (gridRoot.width-width)/2 + (parent.width*currentPage) + (gridRoot.width-parent.width)*currentPage - marginMinimalGroup
                anchors.verticalCenter: parent.verticalCenter
                visible: activeGroup
                color: Qt.rgba(bgColor.r, bgColor.g, bgColor.b, 0.7)
                radius: 12
                Behavior on width {
                    NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                }
                Behavior on height {
                    NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                }

            }



            Repeater {
                id: appsRepeater
                model: modelActive

                delegate: Item {
                    width: cellWidth
                    height: cellHeight

                    property int page: Math.floor(index / itemsPerPage)
                    property int localIndex: index % itemsPerPage
                    property int row: localIndex % maxItemsPerRow
                    property int column: Math.floor(localIndex / maxItemsPerRow)
                    property int extraPadding: page > 0 ? marginPage + (marginPage*page) : marginPage

                    x: (row * cellWidth) + (page * (maxItemsPerRow * cellWidth + marginPage)) + extraPadding
                    y: column * cellHeight

                    ListDelegate {
                        anchors.fill: parent
                        iconSource: model.icon || model.decoration
                        name: model.name || model.display
                        isGroup: model.isGroup !== undefined ? model.isGroup : false
                        appIndex: model.appIndex !== undefined ? model.appIndex : -1
                        elementsVisible: visibleApps
                        dragActive: false
                        sizeIcon: iconSize
                        subModel: model.modelGroup
                        parentItem: bgGroup
                        onDropOnItem: function(
                            draggedIndex,
                            draggedName,
                            draggedIcon,
                            draggedAppIndex,
                            targetIndex,
                            targetName,
                            targetIcon,
                            targetAppIndex
                        ) {
                            var draggedItem = { display: draggedName, decoration: draggedIcon, appIndex: draggedAppIndex }
                            var targetItem  = { display: targetName, decoration: targetIcon, appIndex: targetAppIndex }
                            handleCreateGroup(targetIndex,draggedItem,targetItem)
                        }
                        onDropOnItemGroup: function (
                            draggedIndex,
                            draggedName,
                            draggedIcon,
                            draggedAppIndex,
                            targetIndex
                        ) {
                            var draggedItem = {
                                display: draggedName,
                                decoration: draggedIcon,
                                appIndex: draggedAppIndex
                            }

                            handleAddToGroup(targetIndex, draggedItem)
                        }

                        onOpenGroup: function (model,indexGroup){

                            folderAppModel = model
                            parentGroupIndex = indexGroup
                            oldPage = currentPage
                            currentPage = 0
                            activeGroup = true

                        }
                        onRelocateGroup: function (orignalIndex,idx) {
                            console.log(idx,orignalIndex)
                            var item = appsModel.get(orignalIndex)

                            appsModel.insert(idx,item)

                            var indexRemove = 0

                            if (orignalIndex > idx) {
                                indexRemove = orignalIndex + 1
                            } else {
                                 indexRemove = orignalIndex
                            }
                            appsModel.remove(indexRemove)

                            Utils.relocateGroup(idx)

                        }
                        onRemoveAppInGroup: function (idx,nme) {
                            Utils.removeAppOfGroup(idx, nme)
                        }
                    }

                    // (dihapus) perhitungan totalItems lewat model.index membuat
                    // totalPages terlalu kecil -> halaman tengah tidak bisa dibuka
                }
            }
        }

        PageIndicator {
            id: pageIndicator
            count: totalPages
            currentIndex: currentPage
            visible: totalPages > 1
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: wrapper.top
            anchors.topMargin: cellHeight*maxItemsPerColumn + 16


            // Navegación por clic en los puntos
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (pageIndicator.count <= 1)
                        return
                    var clickedIndex = Math.floor(mouseX / (pageIndicator.width / pageIndicator.count))
                    rootScope.goToPage(clickedIndex)
                }
            }
        }

    }
}

