package com.guitaripod.pixie.presentation.home

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.guitaripod.pixie.data.model.Config

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    config: Config,
    onLogout: () -> Unit,
    modifier: Modifier = Modifier
) {
    Scaffold(
        modifier = modifier.fillMaxSize(),
        topBar = {
            TopAppBar(
                title = { Text("Pixie") },
                actions = {
                    TextButton(onClick = onLogout) {
                        Text("Logout")
                    }
                }
            )
        }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                text = "Welcome to Pixie!",
                style = MaterialTheme.typography.headlineMedium
            )
            
            Card(
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(
                        text = "Account Info",
                        style = MaterialTheme.typography.titleMedium
                    )
                    
                    config.userId?.let { userId ->
                        Text(text = "User ID: $userId")
                    }
                    
                    config.authProvider?.let { provider ->
                        Text(text = "Provider: ${provider.replaceFirstChar { it.uppercase() }}")
                    }
                    
                    config.apiUrl?.let { url ->
                        Text(
                            text = "API: $url",
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                }
            }
            
            Spacer(modifier = Modifier.weight(1f))
            
            Text(
                text = "Image generation features coming soon!",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}