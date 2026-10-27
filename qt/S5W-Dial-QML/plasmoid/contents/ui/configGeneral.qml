/*
 *  SPDX-FileCopyrightText: 2014 Joseph Wenninger <jowenn@kde.org>
 *  SPDX-FileCopyrightText: 2018 Piotr Kąkol <piotrkakol@protonmail.com>
 *
 *  Based on analog-clock configGeneral.qml:
 *  SPDX-FileCopyrightText: 2013 David Edmundson <davidedmundson@kde.org>
 *
 *  SPDX-License-Identifier: GPL-2.0-or-later
 */

import QtQuick 2.0
import QtQuick.Controls 2.10 as QtControls
import QtQuick.Controls 1.4 as QtC1
import QtQuick.Layouts 1.12
import org.kde.kquickcontrols 2.0 as KQuickControls
import org.kde.kirigami 2.5 as Kirigami

Kirigami.FormLayout {
    id: generalConfigPage
    anchors.left: parent.left
    anchors.right: parent.right

    property alias cfg_minValue: minimumValue.value
    property alias cfg_maxValue: maximumValue.value
    property alias cfg_numTicks: numTicks.value
    property alias cfg_dataSensorLabel: dataSensorLabel.text
    property alias cfg_dataSensorName: dataSensorName.text
    property alias cfg_dataSensorUpdateIntervalMS: dataSensorUpdateIntervalMS.value
    property alias cfg_useWarningArea: useWarningArea.checked
    property alias cfg_warningLow: warningLow.value
    property alias cfg_warningHigh: warningHigh.value
    property alias cfg_useDesiredArea: useDesiredArea.checked
    property alias cfg_desiredLow: desiredLow.value
    property alias cfg_desiredHigh: desiredHigh.value

    QtC1.SpinBox {
        id: minimumValue
        Kirigami.FormData.label: i18n("Minimum dial value")
        decimals: 1
        minimumValue: 0.0
        maximumValue: 1.0e12
    }

    QtC1.SpinBox {
        id: maximumValue
        Kirigami.FormData.label: i18n("Maximum dial value")
        decimals: 1
        minimumValue: 0.0
        maximumValue: 1.0e12
    }

    QtControls.SpinBox {
        id: numTicks
        Kirigami.FormData.label:i18n("Number of major tick marks")
        from: 3
        to: 20
        editable: true
    }

    QtControls.TextField {
        id: dataSensorLabel
        Kirigami.FormData.label:i18n("Label to display")
    }

    Item {
        Kirigami.FormData.isSection:true
    }

    QtControls.TextField {
        id: dataSensorName
        Kirigami.FormData.label:i18n("Name of data sensor to read from")
    }

    QtControls.SpinBox {
        id: dataSensorUpdateIntervalMS
        Kirigami.FormData.label:i18n("Data sensor check interval (in milliseconds)")
        from: 50
        to: 10000
        editable: true
    }

    Item {
        Kirigami.FormData.isSection:true
    }

    QtControls.CheckBox {
        id: useWarningArea
        text: i18nc("@option:check", "Enable warning area color band")
    }

    QtC1.SpinBox {
        id: warningLow
        Kirigami.FormData.label: i18n("Warning area low setpoint")
        decimals: 1
        minimumValue: 0.0
        maximumValue: 1.0e12
    }

    QtC1.SpinBox {
        id: warningHigh
        Kirigami.FormData.label: i18n("Warning area high setpoint")
        decimals: 1
        minimumValue: 0.0
        maximumValue: 1.0e12
    }

    QtControls.CheckBox {
        id: useDesiredArea
        text: i18nc("@option:check", "Enable desired area color band")
    }

    QtC1.SpinBox {
        id: desiredLow
        Kirigami.FormData.label: i18n("Desired area low setpoint")
        decimals: 1
        minimumValue: 0.0
        maximumValue: 1.0e12
    }

    QtC1.SpinBox {
        id: desiredHigh
        Kirigami.FormData.label: i18n("Desired area high setpoint")
        decimals: 1
        minimumValue: 0.0
        maximumValue: 1.0e12
    }
}
