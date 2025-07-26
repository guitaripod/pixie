package com.guitaripod.pixie.utils

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat

@Composable
fun NotificationPermissionEffect(
    onPermissionResult: (Boolean) -> Unit = {}
) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        val context = LocalContext.current
        var hasRequestedPermission by remember {
            mutableStateOf(
                context.getSharedPreferences("pixie_prefs", Context.MODE_PRIVATE)
                    .getBoolean("has_requested_notification_permission", false)
            )
        }
        
        val hasNotificationPermission = remember {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        }
        
        if (!hasNotificationPermission && !hasRequestedPermission) {
            NotificationPermissionDialog(
                onPermissionResult = { granted ->
                    context.getSharedPreferences("pixie_prefs", Context.MODE_PRIVATE)
                        .edit()
                        .putBoolean("has_requested_notification_permission", true)
                        .apply()
                    hasRequestedPermission = true
                    onPermissionResult(granted)
                }
            )
        }
    }
}

@Composable
fun NotificationPermissionDialog(
    onPermissionResult: (Boolean) -> Unit
) {
    val context = LocalContext.current
    var showRationale by remember { mutableStateOf(false) }
    var showSettingsDialog by remember { mutableStateOf(false) }
    
    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        if (!isGranted && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val shouldShowRationale = (context as? androidx.activity.ComponentActivity)
                ?.shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS)
                ?: false
            
            if (shouldShowRationale) {
                showRationale = true
            } else {
                showSettingsDialog = true
            }
        }
        onPermissionResult(isGranted)
    }
    
    // Initial explanation dialog
    var showInitialDialog by remember { mutableStateOf(true) }
    
    if (showInitialDialog) {
        AlertDialog(
            onDismissRequest = { 
                showInitialDialog = false
                onPermissionResult(false)
            },
            title = { Text("Enable Notifications") },
            text = {
                Text(
                    "Pixie can show you notifications when your images are ready, " +
                    "even if you switch to another app while generating.",
                    textAlign = TextAlign.Start
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        showInitialDialog = false
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                        }
                    }
                ) {
                    Text("Enable")
                }
            },
            dismissButton = {
                TextButton(
                    onClick = {
                        showInitialDialog = false
                        onPermissionResult(false)
                    }
                ) {
                    Text("Not Now")
                }
            }
        )
    }
    
    // Rationale dialog (user denied once)
    if (showRationale) {
        AlertDialog(
            onDismissRequest = { 
                showRationale = false
                onPermissionResult(false)
            },
            title = { Text("Notifications Help You Stay Updated") },
            text = {
                Text(
                    "Without notifications, you won't know when your images are ready if you leave the app. " +
                    "This is especially useful for longer generation tasks.",
                    textAlign = TextAlign.Start
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        showRationale = false
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                        }
                    }
                ) {
                    Text("Try Again")
                }
            },
            dismissButton = {
                TextButton(
                    onClick = {
                        showRationale = false
                        onPermissionResult(false)
                    }
                ) {
                    Text("No Thanks")
                }
            }
        )
    }
    
    // Settings dialog (permanently denied)
    if (showSettingsDialog) {
        AlertDialog(
            onDismissRequest = { 
                showSettingsDialog = false
                onPermissionResult(false)
            },
            title = { Text("Enable in Settings") },
            text = {
                Text(
                    "To receive notifications when your images are ready, please enable notifications " +
                    "for Pixie in your device settings.",
                    textAlign = TextAlign.Start
                )
            },
            confirmButton = {
                TextButton(
                    onClick = {
                        showSettingsDialog = false
                        // Could open settings here if needed
                        onPermissionResult(false)
                    }
                ) {
                    Text("OK")
                }
            }
        )
    }
}

fun hasNotificationPermission(context: Context): Boolean {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
    } else {
        true // Permission not required before Android 13
    }
}