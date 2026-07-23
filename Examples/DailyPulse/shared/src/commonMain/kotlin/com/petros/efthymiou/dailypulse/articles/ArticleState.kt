package com.petros.efthymiou.dailypulse.articles

data class ArticleState(
    val articles: List<Article> = listOf(),
    val isLoading: Boolean = false,
    val error: String? = null
)