package com.guitaripod.pixie.ui.theme

import android.app.Activity
import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

private val DarkColorScheme = darkColorScheme(
    primary = PixiePurpleLight,
    onPrimary = PixiePurpleDark,
    primaryContainer = PixiePurpleDark,
    onPrimaryContainer = PixiePurpleLight,
    secondary = PixieTealLight,
    onSecondary = PixieTealDark,
    secondaryContainer = PixieTealDark,
    onSecondaryContainer = PixieTealLight,
    tertiary = PixieOrangeLight,
    onTertiary = PixieOrangeDark,
    tertiaryContainer = PixieOrangeDark,
    onTertiaryContainer = PixieOrangeLight,
    error = ErrorRed,
    errorContainer = ErrorRedDark,
    onError = ErrorRedLight,
    onErrorContainer = ErrorRedLight,
    background = SurfaceDark,
    onBackground = SurfaceLight,
    surface = SurfaceDark,
    onSurface = SurfaceLight,
    surfaceVariant = NeutralGray,
    onSurfaceVariant = SurfaceLight,
    outline = NeutralGray,
    inverseOnSurface = SurfaceDark,
    inverseSurface = SurfaceLight,
    inversePrimary = PixiePurple
)

private val LightColorScheme = lightColorScheme(
    primary = PixiePurple,
    onPrimary = SurfaceLight,
    primaryContainer = PixiePurpleLight,
    onPrimaryContainer = PixiePurpleDark,
    secondary = PixieTeal,
    onSecondary = SurfaceLight,
    secondaryContainer = PixieTealLight,
    onSecondaryContainer = PixieTealDark,
    tertiary = PixieOrange,
    onTertiary = SurfaceLight,
    tertiaryContainer = PixieOrangeLight,
    onTertiaryContainer = PixieOrangeDark,
    error = ErrorRed,
    errorContainer = ErrorRedLight,
    onError = SurfaceLight,
    onErrorContainer = ErrorRedDark,
    background = SurfaceLight,
    onBackground = SurfaceDark,
    surface = SurfaceLight,
    onSurface = SurfaceDark,
    surfaceVariant = SurfaceLight,
    onSurfaceVariant = NeutralGray,
    outline = NeutralGray,
    inverseOnSurface = SurfaceLight,
    inverseSurface = SurfaceDark,
    inversePrimary = PixiePurpleLight
)

@Composable
fun PixieTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }
        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }
    
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            WindowCompat.setDecorFitsSystemWindows(window, false)
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = !darkTheme
        }
    }
    
    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}