import app.cash.sqldelight.db.SqlDriver
import org.koin.dsl.module
import petros.efthymiou.dailypulse.db.DailyPulseDatabase

val databaseModule = module {
    single<DailyPulseDatabase> {
        DailyPulseDatabase(driver = get())
    }
}
