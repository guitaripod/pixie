package com.guitaripod.pixie.utils

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.HapticFeedbackConstants
import android.view.View
class HapticFeedbackManager(
    private val context: Context
) {
    private val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
        vibratorManager?.defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
    }

    private val hasVibrator: Boolean = vibrator?.hasVibrator() == true

    enum class HapticType {
        CLICK,
        LONG_PRESS,
        KEYBOARD_TAP,
        KEYBOARD_RELEASE,
        VIRTUAL_KEY,
        VIRTUAL_KEY_RELEASE,
        TEXT_HANDLE_MOVE,
        CLOCK_TICK,
        CONTEXT_CLICK,
        CONFIRM,
        REJECT,
        GESTURE_START,
        GESTURE_END,
        SEGMENT_TICK,
        SEGMENT_FREQUENT_TICK,
        ERROR,
        SUCCESS,
        WARNING,
        SLIDER_TICK,
        TOGGLE
    }

    fun performHapticFeedback(view: View, type: HapticType) {
        if (!hasVibrator) return

        when (type) {
            HapticType.CLICK -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    view.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
                } else {
                    view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
                }
            }
            HapticType.LONG_PRESS -> {
                view.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
            }
            HapticType.KEYBOARD_TAP -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                    view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                } else {
                    view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
                }
            }
            HapticType.KEYBOARD_RELEASE -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                    view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_RELEASE)
                } else {
                    view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY_RELEASE)
                }
            }
            HapticType.VIRTUAL_KEY -> {
                view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
            }
            HapticType.VIRTUAL_KEY_RELEASE -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY_RELEASE)
                }
            }
            HapticType.TEXT_HANDLE_MOVE -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                    view.performHapticFeedback(HapticFeedbackConstants.TEXT_HANDLE_MOVE)
                }
            }
            HapticType.CLOCK_TICK -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
                }
            }
            HapticType.CONTEXT_CLICK -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    view.performHapticFeedback(HapticFeedbackConstants.CONTEXT_CLICK)
                }
            }
            HapticType.CONFIRM -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    view.performHapticFeedback(HapticFeedbackConstants.CONFIRM)
                } else {
                    performCustomVibration(10)
                }
            }
            HapticType.REJECT -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    view.performHapticFeedback(HapticFeedbackConstants.REJECT)
                } else {
                    performCustomVibration(30)
                }
            }
            HapticType.GESTURE_START -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    view.performHapticFeedback(HapticFeedbackConstants.GESTURE_START)
                }
            }
            HapticType.GESTURE_END -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    view.performHapticFeedback(HapticFeedbackConstants.GESTURE_END)
                }
            }
            HapticType.SEGMENT_TICK -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    view.performHapticFeedback(HapticFeedbackConstants.SEGMENT_TICK)
                } else {
                    performCustomVibration(5)
                }
            }
            HapticType.SEGMENT_FREQUENT_TICK -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    view.performHapticFeedback(HapticFeedbackConstants.SEGMENT_FREQUENT_TICK)
                } else {
                    performCustomVibration(2)
                }
            }
            HapticType.ERROR -> {
                performCustomVibration(longArrayOf(0, 50, 50, 50))
            }
            HapticType.SUCCESS -> {
                performCustomVibration(longArrayOf(0, 20, 20, 20))
            }
            HapticType.WARNING -> {
                performCustomVibration(40)
            }
            HapticType.SLIDER_TICK -> {
                performCustomVibration(3)
            }
            HapticType.TOGGLE -> {
                performCustomVibration(8)
            }
        }
    }

    fun performHapticFeedback(type: HapticType) {
        if (!hasVibrator) return

        when (type) {
            HapticType.ERROR -> performCustomVibration(longArrayOf(0, 50, 50, 50))
            HapticType.SUCCESS -> performCustomVibration(longArrayOf(0, 20, 20, 20))
            HapticType.WARNING -> performCustomVibration(40)
            else -> performCustomVibration(10)
        }
    }

    private fun performCustomVibration(duration: Long) {
        vibrator?.let {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                it.vibrate(VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                it.vibrate(duration)
            }
        }
    }

    private fun performCustomVibration(pattern: LongArray) {
        vibrator?.let {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                it.vibrate(VibrationEffect.createWaveform(pattern, -1))
            } else {
                @Suppress("DEPRECATION")
                it.vibrate(pattern, -1)
            }
        }
    }
}