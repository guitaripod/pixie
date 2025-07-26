package com.guitaripod.pixie.utils

import android.view.View
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import com.guitaripod.pixie.appContainer

@Composable
fun rememberHapticFeedback(): HapticFeedback {
    val view = LocalView.current
    val context = LocalContext.current
    val hapticManager = remember { context.appContainer().hapticFeedbackManager }
    
    return remember(view, hapticManager) {
        HapticFeedback(view, hapticManager)
    }
}

class HapticFeedback(
    private val view: View,
    private val hapticManager: HapticFeedbackManager
) {
    fun click() = hapticManager.performHapticFeedback(view, HapticFeedbackManager.HapticType.CLICK)
    fun longPress() = hapticManager.performHapticFeedback(view, HapticFeedbackManager.HapticType.LONG_PRESS)
    fun toggle() = hapticManager.performHapticFeedback(view, HapticFeedbackManager.HapticType.TOGGLE)
    fun error() = hapticManager.performHapticFeedback(HapticFeedbackManager.HapticType.ERROR)
    fun success() = hapticManager.performHapticFeedback(HapticFeedbackManager.HapticType.SUCCESS)
    fun warning() = hapticManager.performHapticFeedback(HapticFeedbackManager.HapticType.WARNING)
    fun sliderTick() = hapticManager.performHapticFeedback(view, HapticFeedbackManager.HapticType.SLIDER_TICK)
    fun confirm() = hapticManager.performHapticFeedback(view, HapticFeedbackManager.HapticType.CONFIRM)
    fun reject() = hapticManager.performHapticFeedback(view, HapticFeedbackManager.HapticType.REJECT)
}

fun Modifier.hapticClickable(
    enabled: Boolean = true,
    onClick: () -> Unit
): Modifier = composed {
    val haptic = rememberHapticFeedback()
    
    this.then(
        Modifier.clickable(enabled = enabled) {
            haptic.click()
            onClick()
        }
    )
}

@OptIn(ExperimentalFoundationApi::class)
fun Modifier.hapticLongClickable(
    enabled: Boolean = true,
    onLongClick: () -> Unit
): Modifier = composed {
    val haptic = rememberHapticFeedback()
    
    this.then(
        Modifier.combinedClickable(
            enabled = enabled,
            onLongClick = {
                haptic.longPress()
                onLongClick()
            },
            onClick = {}
        )
    )
}

@OptIn(ExperimentalFoundationApi::class)
fun Modifier.hapticCombinedClickable(
    enabled: Boolean = true,
    onClick: () -> Unit,
    onLongClick: (() -> Unit)? = null
): Modifier = composed {
    val haptic = rememberHapticFeedback()
    
    this.then(
        Modifier.combinedClickable(
            enabled = enabled,
            onClick = {
                haptic.click()
                onClick()
            },
            onLongClick = onLongClick?.let {
                {
                    haptic.longPress()
                    it()
                }
            }
        )
    )
}