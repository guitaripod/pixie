package com.guitaripod.pixie.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.guitaripod.pixie.data.api.ConnectivityStatus
import com.guitaripod.pixie.data.api.NetworkConnectivityObserver
import com.guitaripod.pixie.data.api.isDisconnected

@Composable
fun OfflineBanner(
    networkObserver: NetworkConnectivityObserver,
    modifier: Modifier = Modifier
) {
    val connectivityStatus by networkObserver.observe().collectAsStateWithLifecycle(
        initialValue = networkObserver.getCurrentConnectivityStatus()
    )
    
    AnimatedVisibility(
        visible = connectivityStatus.isDisconnected(),
        enter = expandVertically(),
        exit = shrinkVertically(),
        modifier = modifier
    ) {
        Surface(
            modifier = Modifier.fillMaxWidth(),
            color = MaterialTheme.colorScheme.errorContainer
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center
            ) {
                Icon(
                    imageVector = Icons.Default.WifiOff,
                    contentDescription = "No connection",
                    tint = MaterialTheme.colorScheme.onErrorContainer,
                    modifier = Modifier.size(16.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "No internet connection",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onErrorContainer
                )
            }
        }
    }
}