package com.petros.efthymiou.dailypulse

import android.os.Build

actual class Platform {
    actual val osName: String
        get() = "android"
    actual val osVersion: String
        get() = "${Build.VERSION.SDK_INT}"
    actual val osModel: String
        get() = "${Build.MANUFACTURER} ${Build.MODEL}"
}

