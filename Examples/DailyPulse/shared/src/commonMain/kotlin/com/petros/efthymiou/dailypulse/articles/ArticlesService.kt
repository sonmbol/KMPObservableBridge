package com.petros.efthymiou.dailypulse.articles

import com.petros.efthymiou.dailypulse.articles.Model.ArticelRaw
import com.petros.efthymiou.dailypulse.articles.Model.ArticlesResponse
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.get

class ArticlesService(
    private val client: HttpClient,
    private val apiKey: String
) {
    private val country = "us"
    private val category = "business"
    suspend fun fetchArticles(): List<ArticelRaw> {
        val response: ArticlesResponse = client.get("https://newsapi.org/v2/top-headlines?country=$country&category=$category&apiKey=$apiKey").body()
        return response.articles.orEmpty()
    }
}
