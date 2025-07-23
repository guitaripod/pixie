package com.guitaripod.pixie

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import com.guitaripod.pixie.ui.theme.PixieTheme
import com.guitaripod.pixie.data.model.AuthResult

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        
        // Handle OAuth callback if launched from deep link
        handleIntent(intent)
        
        setContent {
            PixieTheme {
                Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
                    Greeting(
                        name = "Pixie",
                        modifier = Modifier.padding(innerPadding)
                    )
                }
            }
        }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }
    
    private fun handleIntent(intent: Intent) {
        intent.data?.let { uri ->
            if (uri.scheme == "pixie" && uri.host == "auth") {
                // Handle OAuth callback
                val appContainer = (application as PixieApplication).appContainer
                val result = appContainer.authRepository.handleOAuthCallback(uri)
                
                // TODO: Handle the auth result (e.g., show toast, navigate to home)
                when (result) {
                    is AuthResult.Success -> {
                        // TODO: Navigate to home screen
                    }
                    is AuthResult.Error -> {
                        // TODO: Show error message
                    }
                    is AuthResult.Cancelled -> {
                        // TODO: Handle cancellation
                    }
                    is AuthResult.Pending -> {
                        // Should not happen for callback
                    }
                }
            }
        }
    }
}

@Composable
fun Greeting(name: String, modifier: Modifier = Modifier) {
    Text(
        text = "Welcome to $name!",
        modifier = modifier
    )
}

@Preview(showBackground = true)
@Composable
fun GreetingPreview() {
    PixieTheme {
        Greeting("Pixie")
    }
}