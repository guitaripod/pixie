package com.guitaripod.pixie.presentation.auth

import android.app.Activity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.guitaripod.pixie.data.model.AuthResult
import com.guitaripod.pixie.utils.DebugUtils
import com.guitaripod.pixie.utils.rememberHapticFeedback
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
    val haptic = rememberHapticFeedback()
    
    var isLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var showManualAuthDialog by remember { mutableStateOf(false) }
    var manualAuthProvider by remember { mutableStateOf("") }
    var showAuthButtons by remember { mutableStateOf(false) }
    var showWhySignInDialog by remember { mutableStateOf(false) }
    
    var currentShowcaseIndex by remember { mutableStateOf(0) }
    val showcaseStyles = listOf(
        "Anime Art" to Color(0xFF9966CC).copy(alpha = 0.3f),
        "Photorealistic" to Color(0xFF6699E8).copy(alpha = 0.3f),
        "Abstract" to Color(0xFFE87F66).copy(alpha = 0.3f),
        "Fantasy" to Color(0xFF66CC99).copy(alpha = 0.3f)
    )
    
    LaunchedEffect(Unit) {
        while (true) {
            delay(3000)
            currentShowcaseIndex = (currentShowcaseIndex + 1) % showcaseStyles.size
        }
    }
    
    val creditsHintScale by animateFloatAsState(
        targetValue = if (showAuthButtons) 0.95f else 1.02f,
        animationSpec = infiniteRepeatable(
            animation = tween(2000, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        )
    )
    
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
            Spacer(modifier = Modifier.height(20.dp))
            
            AnimatedVisibility(
                visible = !showAuthButtons,
                enter = fadeIn() + scaleIn(),
                exit = fadeOut() + scaleOut(targetScale = 0.95f)
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(24.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(200.dp)
                            .clip(RoundedCornerShape(16.dp)),
                        contentAlignment = Alignment.Center
                    ) {
                    showcaseStyles.forEachIndexed { index, (style, color) ->
                        androidx.compose.animation.AnimatedVisibility(
                            visible = currentShowcaseIndex == index,
                            enter = fadeIn(animationSpec = tween(500)),
                            exit = fadeOut(animationSpec = tween(500))
                        ) {
                            Box(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .padding(8.dp)
                                    .clip(RoundedCornerShape(12.dp))
                                    .background(color),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = style,
                                    style = MaterialTheme.typography.bodyMedium.copy(
                                        fontWeight = FontWeight.Medium,
                                        color = color.copy(alpha = 1f)
                                    )
                                )
                            }
                        }
                    }
                        
                        Row(
                            modifier = Modifier
                                .align(Alignment.BottomCenter)
                                .padding(bottom = 8.dp),
                            horizontalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            showcaseStyles.indices.forEach { index ->
                                Box(
                                    modifier = Modifier
                                        .size(6.dp)
                                        .clip(CircleShape)
                                        .background(
                                            if (index == currentShowcaseIndex) 
                                                MaterialTheme.colorScheme.primary
                                            else 
                                                MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f)
                                        )
                                )
                            }
                        }
                    }
                    
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Text(
                            text = "Turn ideas into stunning visuals",
                            style = MaterialTheme.typography.headlineSmall.copy(
                                fontWeight = FontWeight.Bold
                            ),
                            textAlign = TextAlign.Center,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        
                        Text(
                            text = "Create AI-powered images in seconds",
                            style = MaterialTheme.typography.bodyMedium,
                            textAlign = TextAlign.Center,
                            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
                        )
                    }
                    
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Card(
                            modifier = Modifier
                                .fillMaxWidth()
                                .scale(creditsHintScale),
                            colors = CardDefaults.cardColors(
                                containerColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.1f)
                            ),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Text(
                                text = "✨ Get free credits to start creating",
                                modifier = Modifier.padding(16.dp),
                                style = MaterialTheme.typography.bodyMedium.copy(
                                    fontWeight = FontWeight.Medium,
                                    color = MaterialTheme.colorScheme.primary
                                ),
                                textAlign = TextAlign.Center
                            )
                        }
                        
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            colors = CardDefaults.cardColors(
                                containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
                            ),
                            shape = RoundedCornerShape(12.dp)
                        ) {
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(16.dp),
                                horizontalArrangement = Arrangement.Center,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Lock,
                                    contentDescription = null,
                                    modifier = Modifier.size(16.dp),
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = "Secure sign-in • We never post on your behalf",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
                                )
                            }
                        }
                    }
                }
            }
            
            AnimatedVisibility(
                visible = !showAuthButtons,
                enter = fadeIn(),
                exit = fadeOut()
            ) {
                Column(
                    modifier = Modifier.padding(top = 24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Button(
                        onClick = { 
                            haptic.click()
                            showAuthButtons = true 
                        },
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = MaterialTheme.colorScheme.primary
                        ),
                        contentPadding = PaddingValues(vertical = 16.dp, horizontal = 32.dp)
                    ) {
                        Text(
                            "Get Started",
                            style = MaterialTheme.typography.bodyLarge.copy(
                                fontWeight = FontWeight.SemiBold
                            )
                        )
                    }
                    
                    TextButton(
                        onClick = { 
                            haptic.click()
                            showWhySignInDialog = true 
                        }
                    ) {
                        Text(
                            "Why do I need to sign in?",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
                        )
                    }
                }
            }
            
            AnimatedVisibility(
                visible = showAuthButtons,
                enter = fadeIn() + slideInVertically(initialOffsetY = { it / 2 }),
                exit = fadeOut()
            ) {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Spacer(modifier = Modifier.height(60.dp))
                    
                    GoogleSignInButton(
                        onClick = { 
                            haptic.click()
                            handleGoogleAuth() 
                        },
                        enabled = !isLoading
                    )
                    
                    AppleSignInButton(
                        onClick = { 
                            haptic.click()
                            handleAppleAuth() 
                        },
                        enabled = !isLoading
                    )
                    
                    GitHubSignInButton(
                        onClick = { 
                            haptic.click()
                            handleGithubAuth() 
                        },
                        enabled = !isLoading
                    )
                    
                    if (DebugUtils.isRunningInEmulator()) {
                        Button(
                            onClick = { 
                                haptic.click()
                                handleDebugAuth() 
                            },
                            modifier = Modifier.fillMaxWidth(),
                            enabled = !isLoading,
                            colors = ButtonDefaults.buttonColors(
                                containerColor = MaterialTheme.colorScheme.tertiary
                            )
                        ) {
                            Text("Debug Login (Emulator Only)")
                        }
                    }
                    
                    Spacer(modifier = Modifier.height(16.dp))
                    
                    Text(
                        text = "By signing in, you agree to our Terms",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f),
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }
            
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
            
            Spacer(modifier = Modifier.height(20.dp))
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
    
    if (showWhySignInDialog) {
        Dialog(onDismissRequest = { showWhySignInDialog = false }) {
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp)),
                color = MaterialTheme.colorScheme.surface.copy(alpha = 0.95f)
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .blur(radius = 0.dp)
                ) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(24.dp),
                        verticalArrangement = Arrangement.spacedBy(20.dp)
                    ) {
                        Text(
                            text = "Why Sign In?",
                            style = MaterialTheme.typography.headlineSmall.copy(
                                fontWeight = FontWeight.Bold
                            ),
                            textAlign = TextAlign.Center,
                            modifier = Modifier.fillMaxWidth()
                        )
                        
                        val benefits = listOf(
                            "cloud.download" to "Sync across all your devices",
                            "photo" to "Save your creations to gallery",
                            "history" to "Access generation history",
                            "credit_card" to "Track your credits and usage",
                            "lock" to "Secure and private"
                        )
                        
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            benefits.forEach { (_, text) ->
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Icon(
                                        painter = painterResource(id = com.guitaripod.pixie.R.drawable.ic_pixie_logo),
                                        contentDescription = null,
                                        modifier = Modifier.size(24.dp),
                                        tint = MaterialTheme.colorScheme.primary
                                    )
                                    Spacer(modifier = Modifier.width(12.dp))
                                    Text(
                                        text = text,
                                        style = MaterialTheme.typography.bodyMedium
                                    )
                                }
                            }
                        }
                        
                        Button(
                            onClick = { showWhySignInDialog = false },
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(
                                containerColor = MaterialTheme.colorScheme.primary
                            )
                        ) {
                            Text("Got it")
                        }
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