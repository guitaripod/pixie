package com.guitaripod.pixie.presentation.auth

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import kotlinx.coroutines.launch
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.guitaripod.pixie.R
import com.guitaripod.pixie.data.model.AuthResult
import kotlinx.coroutines.flow.Flow

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AuthScreen(
    onGithubAuth: () -> Flow<AuthResult>,
    onGoogleAuth: () -> Flow<AuthResult>,
    onAppleAuth: () -> Flow<AuthResult>,
    onAuthSuccess: () -> Unit,
    modifier: Modifier = Modifier
) {
    var isLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var currentProvider by remember { mutableStateOf<String?>(null) }
    
    val scope = rememberCoroutineScope()
    
    fun handleAuth(provider: String) {
        scope.launch {
            try {
                val authFlow = when (provider) {
                    "github" -> onGithubAuth()
                    "google" -> onGoogleAuth()
                    "apple" -> onAppleAuth()
                    else -> return@launch
                }
                
                authFlow.collect { result ->
                    when (result) {
                        is AuthResult.Pending -> {
                            isLoading = true
                            errorMessage = null
                        }
                        is AuthResult.Success -> {
                            isLoading = false
                            onAuthSuccess()
                        }
                        is AuthResult.Error -> {
                            isLoading = false
                            errorMessage = result.message
                            currentProvider = null
                        }
                        is AuthResult.Cancelled -> {
                            isLoading = false
                            errorMessage = "Authentication cancelled"
                            currentProvider = null
                        }
                    }
                }
            } catch (e: Exception) {
                isLoading = false
                errorMessage = "Authentication failed: ${e.message}"
                currentProvider = null
            }
        }
    }
    
    Box(
        modifier = modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        if (isLoading) {
            CircularProgressIndicator()
        } else {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 32.dp)
                    .verticalScroll(rememberScrollState()),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Text(
                    text = "Welcome to Pixie",
                    style = MaterialTheme.typography.headlineLarge,
                    textAlign = TextAlign.Center
                )
                
                Text(
                    text = "Sign in to generate and edit images",
                    style = MaterialTheme.typography.bodyLarge,
                    textAlign = TextAlign.Center,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                
                Spacer(modifier = Modifier.height(32.dp))
                
                // GitHub Button
                OutlinedButton(
                    onClick = { handleAuth("github") },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = !isLoading
                ) {
                    // Icon placeholder - would use actual GitHub icon
                    Text("Sign in with GitHub")
                }
                
                // Google Button
                OutlinedButton(
                    onClick = { handleAuth("google") },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = !isLoading
                ) {
                    // Icon placeholder - would use actual Google icon
                    Text("Sign in with Google")
                }
                
                // Apple Button
                OutlinedButton(
                    onClick = { handleAuth("apple") },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = !isLoading
                ) {
                    // Icon placeholder - would use actual Apple icon
                    Text("Sign in with Apple")
                }
                
                // Error message
                errorMessage?.let { error ->
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.errorContainer
                        )
                    ) {
                        Text(
                            text = error,
                            modifier = Modifier.padding(16.dp),
                            color = MaterialTheme.colorScheme.onErrorContainer,
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                }
            }
        }
    }
}