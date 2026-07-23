package com.petros.efthymiou.dailypulse.articles
import com.petros.efthymiou.dailypulse.articles.Model.ArticelRaw
import petros.efthymiou.dailypulse.db.DailyPulseDatabase


class ArticlesDataSource(
    private val database: DailyPulseDatabase
) {


    suspend fun getAllArticles(): List<ArticelRaw>
    = database.dailyPulseDatabaseQueries.selectAllArticles(::mapArticleRow).executeAsList()


    suspend fun insertArticles(articles: List<ArticelRaw>) {
        database.dailyPulseDatabaseQueries.transaction {
            articles.forEach {
                database.dailyPulseDatabaseQueries.insertArticle(
                    it.title.orEmpty(),
                    it.desc,
                    it.date.orEmpty(),
                    it.imageUrl
                )
            }
        }
    }

    suspend fun clearArticles() {
        database.dailyPulseDatabaseQueries.removeAllArticles()
    }
    private fun mapArticleRow(
        title: String,
        desc: String?,
        date: String,
        imageUrl: String?
    ): ArticelRaw
    = ArticelRaw(title, desc.orEmpty(), date, imageUrl.orEmpty())
}