/*
 *  SPDX-FileCopyrightText: 2021 Michael Pyne <mpyne@kde.org>
 *  SPDX-License-Identifier: MIT
 */

import QtQuick 2.0
import QtQuick.Layouts 1.15

import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents

S5WDial {
    id: base_dial
    minimum: plasmoid.configuration.minValue
    maximum: plasmoid.configuration.maxValue

    Layout.minimumHeight: 60
    Layout.minimumWidth: 60
    Layout.preferredWidth: 200 * PlasmaCore.Units.devicePixelRatio
    Layout.preferredHeight: 200 * PlasmaCore.Units.devicePixelRatio
    width:  200
    height: 200

    numTicks: plasmoid.configuration.numTicks
    label: plasmoid.configuration.dataSensorLabel

    useWarningArea: plasmoid.configuration.useWarningArea
    warnLow: plasmoid.configuration.warningLow
    warnHigh: plasmoid.configuration.warningHigh

    useDesiredArea: plasmoid.configuration.useDesiredArea
    desiredLow: plasmoid.configuration.desiredLow
    desiredHigh: plasmoid.configuration.desiredHigh

    Plasmoid.preferredRepresentation: Plasmoid.fullRepresentation

    PlasmaCore.DataSource {
        id: dataSource
        engine: "systemmonitor"
        connectedSources: [plasmoid.configuration.dataSensorName]
        interval: plasmoid.configuration.dataSensorUpdateIntervalMS

        onNewData: {
            if(data.hasOwnProperty('value') && !Number.isNaN(data.value)) {
                base_dial.value = Math.min(Math.max(data.value, base_dial.minimum), base_dial.maximum);
            }
        }
    }
}
