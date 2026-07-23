package com.petros.efthymiou.dailypulse.articles.Model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class ArticelRaw(
    @SerialName("title")
   val title: String?,
    @SerialName("description")
    val desc: String?,
    @SerialName("publishedAt")
    val date: String?,
    @SerialName("urlToImage")
    val imageUrl: String?
)
