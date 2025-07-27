package com.guitaripod.pixie

import android.app.Application
import android.content.Context
import coil.Coil
import com.guitaripod.pixie.di.AppContainer
import com.guitaripod.pixie.utils.ImageLoaderFactory

class PixieApplication : Application() {
    
    lateinit var appContainer: AppContainer
        private set
    
    override fun onCreate() {
        super.onCreate()
        appContainer = AppContainer(this)
        
        Coil.setImageLoader(ImageLoaderFactory.create(this))
    }
}

fun Context.appContainer(): AppContainer {
    return when (this) {
        is PixieApplication -> appContainer
        else -> (applicationContext as PixieApplication).appContainer
    }
}