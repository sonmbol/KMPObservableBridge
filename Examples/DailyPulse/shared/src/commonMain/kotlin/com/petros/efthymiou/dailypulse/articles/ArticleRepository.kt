package com.petros.efthymiou.dailypulse.articles

import com.petros.efthymiou.dailypulse.articles.Model.ArticelRaw
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.IO
import kotlinx.coroutines.withContext

class ArticleRepository(
    private val service: ArticlesService,
    private val dataSource: ArticlesDataSource
) {

    suspend fun getArticles(): List<ArticelRaw> {
        val localData = dataSource.getAllArticles()
        if (localData.isNotEmpty()) return localData
        val remoteData = service.fetchArticles()
        withContext(Dispatchers.IO) {
            dataSource.insertArticles(remoteData)
        }
        return  remoteData
    }
}