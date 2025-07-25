package com.guitaripod.pixie.presentation.auth

import android.app.Activity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import com.guitaripod.pixie.data.model.AuthResult
import com.guitaripod.pixie.utils.DebugUtils
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
    
    fun handleDebugAuth() {
        scope.launch {
            authViewModel.authenticateDebug().collect { result ->
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
    
    Box(
        modifier = modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(modifier = Modifier.height(60.dp))
            Icon(
                painter = painterResource(id = com.guitaripod.pixie.R.drawable.ic_pixie_logo),
                contentDescription = "Pixie Logo",
                modifier = Modifier.size(64.dp),
                tint = MaterialTheme.colorScheme.primary
            )
            
            Spacer(modifier = Modifier.height(16.dp))
            
            Text(
                text = "Pixie",
                style = MaterialTheme.typography.displaySmall.copy(
                    fontWeight = FontWeight.Bold
                ),
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onSurface
            )
            
            Spacer(modifier = Modifier.height(4.dp))
            
            Text(
                text = "AI-powered image generation",
                style = MaterialTheme.typography.bodyMedium,
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
            )
            
            Spacer(modifier = Modifier.height(48.dp))
            
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                GoogleSignInButton(
                    onClick = { handleGoogleAuth() },
                    enabled = !isLoading
                )
                
                AppleSignInButton(
                    onClick = { handleAppleAuth() },
                    enabled = !isLoading
                )
                
                GitHubSignInButton(
                    onClick = { handleGithubAuth() },
                    enabled = !isLoading
                )
                
                if (DebugUtils.isRunningInEmulator()) {
                    Button(
                        onClick = { handleDebugAuth() },
                        modifier = Modifier.fillMaxWidth(),
                        enabled = !isLoading,
                        colors = ButtonDefaults.buttonColors(
                            containerColor = MaterialTheme.colorScheme.tertiary
                        )
                    ) {
                        Text("Debug Login (Emulator Only)")
                    }
                }
            }
            
            Spacer(modifier = Modifier.height(32.dp))
            
            Text(
                text = "By signing in, you agree to our Terms",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
                textAlign = TextAlign.Center
            )
            
            errorMessage?.let { error ->
                Spacer(modifier = Modifier.height(16.dp))
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.errorContainer
                    ),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text(
                        text = error,
                        modifier = Modifier.padding(12.dp),
                        color = MaterialTheme.colorScheme.onErrorContainer,
                        style = MaterialTheme.typography.bodySmall,
                        textAlign = TextAlign.Center
                    )
                }
            }
        }
        
        if (isLoading) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colorScheme.surface.copy(alpha = 0.8f)),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator()
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