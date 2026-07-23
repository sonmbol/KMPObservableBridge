package com.petros.efthymiou.dailypulse

import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.native.NativeSqliteDriver
import org.koin.core.module.Module
import org.koin.dsl.module
import petros.efthymiou.dailypulse.db.DailyPulseDatabase

actual val sqlDriverModule: Module
    get() = module {
        // 🚀 This is the iOS Native SQL Driver definition
        single<SqlDriver> {
            NativeSqliteDriver(
                schema = DailyPulseDatabase.Schema,
                name = "DailyPulseDatabase.db"
            )
        }
    }