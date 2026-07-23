package com.petros.efthymiou.dailypulse


import com.petros.efthymiou.dailypulse.articles.di.articlesModule
import com.petros.efthymiou.dailypulse.di.networkModule
import databaseModule
import org.koin.core.module.Module


val sharedKoinModules = listOf(
    networkModule,
    articlesModule,
    databaseModule,
    sqlDriverModule
)

expect val sqlDriverModule: Module