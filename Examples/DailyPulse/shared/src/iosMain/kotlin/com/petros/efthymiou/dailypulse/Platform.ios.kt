package com.petros.efthymiou.dailypulse

import platform.UIKit.UIDevice

actual class Platform {
    actual val osName: String
        get() = "iOS"
    actual val osVersion: String
        get() = UIDevice.currentDevice.systemVersion
    actual val osModel: String
        get() = UIDevice.currentDevice.model
}

