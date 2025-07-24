package com.guitaripod.pixie

import android.app.Application
import android.content.Context
import coil.Coil
import com.guitaripod.pixie.di.AppContainer
import com.guitaripod.pixie.utils.ImageLoaderFactory

class PixieApplication : Application() {
    
    // Single instance of AppContainer for the entire app
    lateinit var appContainer: AppContainer
        private set
    
    override fun onCreate() {
        super.onCreate()
        appContainer = AppContainer(this)
        
        // Initialize Coil with custom configuration for better caching
        Coil.setImageLoader(ImageLoaderFactory.create(this))
    }
}

// Extension function to easily access AppContainer from any Context
fun Context.appContainer(): AppContainer {
    return when (this) {
        is PixieApplication -> appContainer
        else -> (applicationContext as PixieApplication).appContainer
    }
}