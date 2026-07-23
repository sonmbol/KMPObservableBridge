package com.petros.efthymiou.dailypulse.articles

import com.petros.efthymiou.dailypulse.BaseViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class ArticleViewModel(
    private val articlesUseCase: ArticlesUseCase
): BaseViewModel() {
    private val _articleState: MutableStateFlow<ArticleState> = MutableStateFlow(ArticleState(isLoading = true))
    val articleState: StateFlow<ArticleState>  get() = _articleState.asStateFlow()

    init {
        getArticle()
    }
    fun getArticle() {
        scope.launch {
            val articles = articlesUseCase.getArticles()
            _articleState.emit(ArticleState(articles = articles))
        }
    }

}