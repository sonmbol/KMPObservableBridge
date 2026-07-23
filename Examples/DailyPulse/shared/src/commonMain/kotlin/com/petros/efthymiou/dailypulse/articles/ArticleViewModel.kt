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
            runCatching {
                articlesUseCase.getArticles()
            }.fold(
                onSuccess = { articles ->
                    _articleState.emit(ArticleState(articles = articles))
                },
                onFailure = { error ->
                    _articleState.emit(
                        ArticleState(
                            error = error.message ?: "Unable to load articles",
                        ),
                    )
                },
            )
        }
    }

}
