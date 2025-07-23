package com.guitaripod.pixie.presentation.auth

import android.app.Activity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.guitaripod.pixie.data.model.AuthResult
import kotlinx.coroutines.launch
import kotlinx.coroutines.delay

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AuthScreen(
    authViewModel: AuthViewModel,
    onAuthSuccess: () -> Unit,
    modifier: Modifier = Modifier
) {
    val activity = LocalContext.current as Activity
    val scope = rememberCoroutineScope()
    
    var isLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var showManualAuthDialog by remember { mutableStateOf(false) }
    var manualAuthProvider by remember { mutableStateOf("") }
    
    val googleSignInLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.StartActivityForResult()
    ) { result ->
        scope.launch {
            authViewModel.handleGoogleSignInResult(result.data).collect { authResult ->
                when (authResult) {
                    is AuthResult.Success -> {
                        isLoading = false
                        onAuthSuccess()
                    }
                    is AuthResult.Error -> {
                        isLoading = false
                        errorMessage = authResult.message
                    }
                    is AuthResult.Cancelled -> {
                        isLoading = false
                        errorMessage = "Sign in cancelled"
                    }
                    is AuthResult.Pending -> {
                        isLoading = true
                    }
                }
            }
        }
    }
    
    fun handleGithubAuth() {
        scope.launch {
            authViewModel.authenticateGithub().collect { result ->
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
                    }
                    is AuthResult.Cancelled -> {
                        isLoading = false
                        errorMessage = "Authentication cancelled"
                    }
                }
            }
        }
    }
    
    fun handleGoogleAuth() {
        scope.launch {
            isLoading = true
            errorMessage = null
            authViewModel.authenticateGoogle(activity, googleSignInLauncher).collect { result ->
                if (result !is AuthResult.Pending) {
                    isLoading = false
                }
            }
        }
    }
    
    fun handleAppleAuth() {
        scope.launch {
            authViewModel.authenticateApple(activity).collect { result ->
                when (result) {
                    is AuthResult.Pending -> {
                        isLoading = true
                        errorMessage = null
                        delay(2000)
                        isLoading = false
                        manualAuthProvider = "apple"
                        showManualAuthDialog = true
                    }
                    is AuthResult.Success -> {
                        isLoading = false
                        onAuthSuccess()
                    }
                    is AuthResult.Error -> {
                        isLoading = false
                        errorMessage = result.message
                    }
                    is AuthResult.Cancelled -> {
                        isLoading = false
                        errorMessage = "Authentication cancelled"
                    }
                }
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
                
                GoogleSignInButton(
                    onClick = { handleGoogleAuth() },
                    enabled = !isLoading
                )
                
                Spacer(modifier = Modifier.height(12.dp))
                
                AppleSignInButton(
                    onClick = { handleAppleAuth() },
                    enabled = !isLoading
                )
                
                Spacer(modifier = Modifier.height(12.dp))
                
                GitHubSignInButton(
                    onClick = { handleGithubAuth() },
                    enabled = !isLoading
                )
                
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
    
    if (showManualAuthDialog) {
        ManualAuthDialog(
            onDismiss = { 
                showManualAuthDialog = false
                manualAuthProvider = ""
            },
            onSubmit = { apiKey, userId ->
                scope.launch {
                    authViewModel.authenticateManually(apiKey, userId, manualAuthProvider).collect { result ->
                        when (result) {
                            is AuthResult.Success -> {
                                showManualAuthDialog = false
                                onAuthSuccess()
                            }
                            is AuthResult.Error -> {
                                errorMessage = result.message
                            }
                            is AuthResult.Pending -> {
                            }
                            is AuthResult.Cancelled -> {
                                showManualAuthDialog = false
                            }
                        }
                    }
                }
            },
            isLoading = false
        )
    }
}