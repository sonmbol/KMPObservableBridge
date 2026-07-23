package com.petros.efthymiou.dailypulse.di

import com.petros.efthymiou.dailypulse.articles.ArticleViewModel
import com.petros.efthymiou.dailypulse.sharedKoinModules
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject
import org.koin.core.context.startKoin

fun initKoin() {
    val modules = sharedKoinModules

    startKoin {
        modules(modules)
    }
}

class ArticleInjector: KoinComponent {
    val articleViewModel: ArticleViewModel by inject()
}