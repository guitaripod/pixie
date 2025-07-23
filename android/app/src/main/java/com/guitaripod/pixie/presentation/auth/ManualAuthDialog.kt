package com.guitaripod.pixie.presentation.auth

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog

@Composable
fun ManualAuthDialog(
    onDismiss: () -> Unit,
    onSubmit: (apiKey: String, userId: String) -> Unit,
    isLoading: Boolean = false
) {
    var apiKey by remember { mutableStateOf("") }
    var userId by remember { mutableStateOf("") }
    var apiKeyError by remember { mutableStateOf<String?>(null) }
    var userIdError by remember { mutableStateOf<String?>(null) }
    
    Dialog(onDismissRequest = onDismiss) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp)
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Text(
                    text = "🍎 Apple Sign In",
                    style = MaterialTheme.typography.headlineSmall
                )
                
                Text(
                    text = "Your browser has opened with the Apple Sign In page. After signing in, you'll see your credentials.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                
                Text(
                    text = "Switch between this app and your browser to copy and paste each value:",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                
                OutlinedTextField(
                    value = apiKey,
                    onValueChange = { 
                        apiKey = it
                        apiKeyError = null
                    },
                    label = { Text("API Key") },
                    placeholder = { Text("pixie_abc123def456...") },
                    isError = apiKeyError != null,
                    supportingText = apiKeyError?.let { { Text(it) } },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Password,
                        imeAction = ImeAction.Next
                    )
                )
                
                OutlinedTextField(
                    value = userId,
                    onValueChange = { 
                        userId = it
                        userIdError = null
                    },
                    label = { Text("User ID") },
                    placeholder = { Text("763135bb-02dd-4bd8-a3ca-4dab2666e1e9") },
                    isError = userIdError != null,
                    supportingText = userIdError?.let { { Text(it) } },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Text,
                        imeAction = ImeAction.Done
                    )
                )
                
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    TextButton(
                        onClick = onDismiss,
                        enabled = !isLoading
                    ) {
                        Text("Cancel")
                    }
                    
                    Spacer(modifier = Modifier.width(8.dp))
                    
                    Button(
                        onClick = {
                            var hasError = false
                            
                            if (apiKey.isBlank()) {
                                apiKeyError = "API key is required"
                                hasError = true
                            } else if (!apiKey.startsWith("pixie_")) {
                                apiKeyError = "Invalid API key format"
                                hasError = true
                            }
                            
                            if (userId.isBlank()) {
                                userIdError = "User ID is required"
                                hasError = true
                            }
                            
                            if (!hasError) {
                                onSubmit(apiKey.trim(), userId.trim())
                            }
                        },
                        enabled = !isLoading
                    ) {
                        if (isLoading) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(16.dp),
                                strokeWidth = 2.dp
                            )
                        } else {
                            Text("Submit")
                        }
                    }
                }
            }
        }
    }
}