package com.petros.efthymiou.dailypulse.articles.Model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class ArticlesResponse(
    @SerialName("status")
    val status: String?,
    @SerialName("totalResults")
    val total: Int?,
    @SerialName("articles")
    val articles: List<ArticelRaw>?
)