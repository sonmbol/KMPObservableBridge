package com.petros.efthymiou.dailypulse.articles.di

import com.petros.efthymiou.dailypulse.articles.ArticleRepository
import com.petros.efthymiou.dailypulse.articles.ArticleViewModel
import com.petros.efthymiou.dailypulse.articles.ArticlesDataSource
import com.petros.efthymiou.dailypulse.articles.ArticlesService
import com.petros.efthymiou.dailypulse.articles.ArticlesUseCase
import org.koin.dsl.module
import petros.efthymiou.dailypulse.db.DailyPulseDatabase

val articlesModule = module {
    // Supply a local NewsAPI key when running the sample. Never commit it.
    single<ArticlesService> { ArticlesService(get(), apiKey = "") }
    single<ArticlesDataSource> { ArticlesDataSource(get()) }
    single<ArticleRepository> { ArticleRepository(get(), get()) }
    single<ArticlesUseCase> { ArticlesUseCase(get()) }
    single<ArticleViewModel> { ArticleViewModel(get()) }
}
