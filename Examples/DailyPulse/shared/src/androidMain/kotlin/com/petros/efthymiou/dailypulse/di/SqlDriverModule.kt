import app.cash.sqldelight.db.SqlDriver
import app.cash.sqldelight.driver.android.AndroidSqliteDriver
import org.koin.core.module.Module
import org.koin.dsl.module
import petros.efthymiou.dailypulse.db.DailyPulseDatabase

actual val sqlDriverModule: Module = module {
    // 🚀 This is the Android SQL Driver definition
    single<SqlDriver> {
        AndroidSqliteDriver(
            schema = DailyPulseDatabase.Schema,
            context = get(), // Automatically gets Android application context from Koin
            name = "DailyPulseDatabase.db"
        )
    }
}
