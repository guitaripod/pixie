package com.guitaripod.pixie.presentation.auth

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.google.android.gms.common.SignInButton
import com.guitaripod.pixie.utils.rememberHapticFeedback

@Composable
fun GoogleSignInButton(
    onClick: () -> Unit,
    enabled: Boolean = true,
    modifier: Modifier = Modifier
) {
    val haptic = rememberHapticFeedback()
    AndroidView(
        modifier = modifier.fillMaxWidth().height(50.dp),
        factory = { context ->
            SignInButton(context).apply {
                setSize(SignInButton.SIZE_WIDE)
                setOnClickListener { 
                    if (enabled) {
                        haptic.click()
                        onClick()
                    }
                }
            }
        },
        update = { button ->
            button.isEnabled = enabled
        }
    )
}

@Composable
fun AppleSignInButton(
    onClick: () -> Unit,
    enabled: Boolean = true,
    modifier: Modifier = Modifier
) {
    val haptic = rememberHapticFeedback()
    Button(
        onClick = {
            haptic.click()
            onClick()
        },
        enabled = enabled,
        modifier = modifier.fillMaxWidth().height(50.dp),
        shape = RoundedCornerShape(8.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = Color.Black,
            contentColor = Color.White,
            disabledContainerColor = Color.Black.copy(alpha = 0.5f),
            disabledContentColor = Color.White.copy(alpha = 0.5f)
        ),
        contentPadding = PaddingValues(horizontal = 20.dp)
    ) {
        Icon(
            painter = painterResource(id = com.guitaripod.pixie.R.drawable.ic_apple),
            contentDescription = null,
            modifier = Modifier.size(20.dp),
            tint = Color.White
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = "Sign in with Apple",
            fontSize = 16.sp,
            fontWeight = FontWeight.Medium,
            letterSpacing = 0.sp
        )
    }
}

@Composable
fun GitHubSignInButton(
    onClick: () -> Unit,
    enabled: Boolean = true,
    modifier: Modifier = Modifier
) {
    val haptic = rememberHapticFeedback()
    Button(
        onClick = {
            haptic.click()
            onClick()
        },
        enabled = enabled,
        modifier = modifier.fillMaxWidth().height(50.dp),
        shape = RoundedCornerShape(6.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = Color(0xFF24292E),
            contentColor = Color.White,
            disabledContainerColor = Color(0xFF24292E).copy(alpha = 0.5f),
            disabledContentColor = Color.White.copy(alpha = 0.5f)
        ),
        contentPadding = PaddingValues(horizontal = 20.dp)
    ) {
        Icon(
            painter = painterResource(id = com.guitaripod.pixie.R.drawable.ic_github),
            contentDescription = null,
            modifier = Modifier.size(20.dp),
            tint = Color.White
        )
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = "Sign in with GitHub",
            fontSize = 16.sp,
            fontWeight = FontWeight.Medium
        )
    }
}