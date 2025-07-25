package com.guitaripod.pixie.presentation.admin

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.automirrored.filled.ArrowForwardIos
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.guitaripod.pixie.data.api.model.UserSearchResult
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminCreditAdjustmentScreen(
    viewModel: AdminCreditAdjustmentViewModel,
    onNavigateBack: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    val keyboardController = LocalSoftwareKeyboardController.current
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Credit Adjustments") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            when (uiState.currentStep) {
                CreditAdjustmentStep.USER_SEARCH -> {
                    UserSearchStep(
                        searchQuery = uiState.searchQuery,
                        onSearchQueryChange = viewModel::updateSearchQuery,
                        onSearch = {
                            keyboardController?.hide()
                            viewModel.searchUsers()
                        },
                        searchResults = uiState.searchResults,
                        isLoading = uiState.isLoading,
                        error = uiState.error,
                        onUserSelected = viewModel::selectUser,
                        onRetry = viewModel::searchUsers
                    )
                }
                CreditAdjustmentStep.ADJUSTMENT_FORM -> {
                    AdjustmentFormStep(
                        selectedUser = uiState.selectedUser!!,
                        amount = uiState.adjustmentAmount,
                        reason = uiState.adjustmentReason,
                        onAmountChange = viewModel::updateAdjustmentAmount,
                        onReasonChange = viewModel::updateAdjustmentReason,
                        onCancel = viewModel::cancelAdjustment,
                        onSubmit = {
                            viewModel.showConfirmationDialog()
                        },
                        isLoading = uiState.isLoading,
                        error = uiState.error
                    )
                }
            }
        }
    }
    
    if (uiState.showConfirmationDialog) {
        ConfirmationDialog(
            user = uiState.selectedUser!!,
            amount = uiState.adjustmentAmount.toIntOrNull() ?: 0,
            reason = uiState.adjustmentReason,
            onConfirm = {
                scope.launch {
                    viewModel.submitAdjustment()
                }
            },
            onDismiss = viewModel::hideConfirmationDialog
        )
    }
    
    if (uiState.adjustmentSuccess != null) {
        SuccessDialog(
            message = uiState.adjustmentSuccess ?: "Success",
            onDismiss = {
                viewModel.resetForm()
            }
        )
    }
}

@Composable
private fun UserSearchStep(
    searchQuery: String,
    onSearchQueryChange: (String) -> Unit,
    onSearch: () -> Unit,
    searchResults: List<UserSearchResult>,
    isLoading: Boolean,
    error: String?,
    onUserSelected: (UserSearchResult) -> Unit,
    onRetry: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        Text(
            text = "Search for User",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface
        )
        
        Spacer(modifier = Modifier.height(8.dp))
        
        Text(
            text = "Enter a user ID or email to search",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.8f)
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        OutlinedTextField(
            value = searchQuery,
            onValueChange = onSearchQueryChange,
            label = { Text("User ID or Email") },
            modifier = Modifier.fillMaxWidth(),
            keyboardOptions = KeyboardOptions(
                imeAction = ImeAction.Search
            ),
            keyboardActions = KeyboardActions(
                onSearch = { onSearch() }
            ),
            trailingIcon = {
                IconButton(onClick = onSearch) {
                    Icon(Icons.Filled.Search, contentDescription = "Search")
                }
            }
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        when {
            isLoading -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator()
                }
            }
            error != null -> {
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    ErrorMessage(
                        error = error,
                        onRetry = onRetry,
                        modifier = Modifier.fillMaxWidth()
                    )
                    
                    // Allow manual entry when search is unavailable
                    if (error.contains("not available", ignoreCase = true)) {
                        Card(
                            modifier = Modifier.fillMaxWidth(),
                            elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
                            colors = CardDefaults.cardColors(
                                containerColor = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.3f)
                            ),
                            border = BorderStroke(1.dp, MaterialTheme.colorScheme.secondary.copy(alpha = 0.3f))
                        ) {
                            Column(
                                modifier = Modifier.padding(16.dp)
                            ) {
                                Text(
                                    text = "Manual Entry",
                                    style = MaterialTheme.typography.titleSmall,
                                    fontWeight = FontWeight.Medium,
                                    color = MaterialTheme.colorScheme.onSecondaryContainer
                                )
                                Spacer(modifier = Modifier.height(8.dp))
                                Text(
                                    text = "If you know the user ID, you can proceed by entering it exactly as shown in the system.",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSecondaryContainer.copy(alpha = 0.8f)
                                )
                                Spacer(modifier = Modifier.height(12.dp))
                                Button(
                                    onClick = {
                                        if (searchQuery.isNotBlank()) {
                                            onUserSelected(UserSearchResult(
                                                id = searchQuery,
                                                email = null,
                                                isAdmin = false,
                                                credits = 0,
                                                createdAt = ""
                                            ))
                                        }
                                    },
                                    enabled = searchQuery.isNotBlank(),
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Text("Continue with User ID: $searchQuery")
                                }
                            }
                        }
                    }
                }
            }
            searchResults.isNotEmpty() -> {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(searchResults) { user ->
                        UserCard(
                            user = user,
                            onClick = { onUserSelected(user) }
                        )
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun UserCard(
    user: UserSearchResult,
    onClick: () -> Unit
) {
    Card(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = user.email ?: "No email",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Text(
                    text = "ID: ${user.id}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                if (user.isAdmin) {
                    Spacer(modifier = Modifier.height(4.dp))
                    Badge {
                        Text("ADMIN", style = MaterialTheme.typography.labelSmall)
                    }
                }
            }
            Column(
                horizontalAlignment = Alignment.End
            ) {
                Text(
                    text = "${user.credits} credits",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.primary
                )
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowForwardIos,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun AdjustmentFormStep(
    selectedUser: UserSearchResult,
    amount: String,
    reason: String,
    onAmountChange: (String) -> Unit,
    onReasonChange: (String) -> Unit,
    onCancel: () -> Unit,
    onSubmit: () -> Unit,
    isLoading: Boolean,
    error: String?
) {
    val focusRequester = remember { FocusRequester() }
    
    LaunchedEffect(Unit) {
        focusRequester.requestFocus()
    }
    
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        Text(
            text = "Adjust Credits",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Card(
            modifier = Modifier.fillMaxWidth(),
            elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.3f)
            ),
            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outline.copy(alpha = 0.3f))
        ) {
            Column(
                modifier = Modifier.padding(16.dp)
            ) {
                Text(
                    text = "User Details",
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.Medium
                )
                Spacer(modifier = Modifier.height(8.dp))
                if (selectedUser.email != null) {
                    Text(
                        text = selectedUser.email,
                        style = MaterialTheme.typography.bodyLarge
                    )
                }
                Text(
                    text = "ID: ${selectedUser.id}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                if (selectedUser.credits > 0 || selectedUser.email != null) {
                    Text(
                        text = "Current balance: ${selectedUser.credits} credits",
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Bold
                    )
                } else {
                    Text(
                        text = "Balance information not available",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
                        fontStyle = androidx.compose.ui.text.font.FontStyle.Italic
                    )
                }
            }
        }
        
        Spacer(modifier = Modifier.height(16.dp))
        
        OutlinedTextField(
            value = amount,
            onValueChange = onAmountChange,
            label = { Text("Amount") },
            modifier = Modifier
                .fillMaxWidth()
                .focusRequester(focusRequester),
            keyboardOptions = KeyboardOptions(
                keyboardType = KeyboardType.Number,
                imeAction = ImeAction.Next
            ),
            supportingText = {
                Text("Positive to add, negative to remove")
            },
            prefix = {
                val amountInt = amount.toIntOrNull() ?: 0
                Text(
                    text = if (amountInt >= 0) "+" else "",
                    color = if (amountInt >= 0) MaterialTheme.colorScheme.primary 
                           else MaterialTheme.colorScheme.error
                )
            }
        )
        
        Spacer(modifier = Modifier.height(8.dp))
        
        OutlinedTextField(
            value = reason,
            onValueChange = onReasonChange,
            label = { Text("Reason") },
            modifier = Modifier.fillMaxWidth(),
            minLines = 2,
            keyboardOptions = KeyboardOptions(
                imeAction = ImeAction.Done
            ),
            keyboardActions = KeyboardActions(
                onDone = { onSubmit() }
            )
        )
        
        Spacer(modifier = Modifier.height(8.dp))
        
        // Preview new balance
        val amountInt = amount.toIntOrNull() ?: 0
        val hasKnownBalance = selectedUser.credits > 0 || selectedUser.email != null
        val newBalance = if (hasKnownBalance) selectedUser.credits + amountInt else amountInt
        if (amount.isNotBlank() && amountInt != 0) {
            Card(
                modifier = Modifier.fillMaxWidth(),
                elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
                colors = CardDefaults.cardColors(
                    containerColor = if (newBalance >= 0) 
                        MaterialTheme.colorScheme.tertiaryContainer.copy(alpha = 0.3f)
                    else 
                        MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.3f)
                ),
                border = BorderStroke(
                    1.dp, 
                    if (newBalance >= 0) MaterialTheme.colorScheme.tertiary.copy(alpha = 0.3f)
                    else MaterialTheme.colorScheme.error.copy(alpha = 0.3f)
                )
            ) {
                Text(
                    text = if (hasKnownBalance) 
                        "New balance: $newBalance credits"
                    else 
                        "Adjustment: ${if (amountInt >= 0) "+" else ""}$amountInt credits",
                    modifier = Modifier.padding(16.dp),
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.Bold,
                    color = if (newBalance >= 0) 
                        MaterialTheme.colorScheme.onTertiaryContainer
                    else 
                        MaterialTheme.colorScheme.onErrorContainer
                )
            }
        }
        
        if (error != null) {
            Spacer(modifier = Modifier.height(8.dp))
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.errorContainer
                )
            ) {
                Text(
                    text = error,
                    modifier = Modifier.padding(16.dp),
                    color = MaterialTheme.colorScheme.onErrorContainer
                )
            }
        }
        
        Spacer(modifier = Modifier.weight(1f))
        
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            OutlinedButton(
                onClick = onCancel,
                modifier = Modifier.weight(1f),
                enabled = !isLoading
            ) {
                Text("Cancel")
            }
            Button(
                onClick = onSubmit,
                modifier = Modifier.weight(1f),
                enabled = amount.isNotBlank() && reason.isNotBlank() && !isLoading
            ) {
                if (isLoading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(16.dp),
                        color = MaterialTheme.colorScheme.onPrimary,
                        strokeWidth = 2.dp
                    )
                } else {
                    Text("Submit")
                }
            }
        }
    }
}

@Composable
private fun ConfirmationDialog(
    user: UserSearchResult,
    amount: Int,
    reason: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text("Confirm Credit Adjustment")
        },
        text = {
            Column {
                Text("Are you sure you want to make this adjustment?")
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = "User: ${user.email ?: user.id}",
                    style = MaterialTheme.typography.bodyMedium
                )
                Text(
                    text = "Amount: ${if (amount >= 0) "+" else ""}$amount credits",
                    style = MaterialTheme.typography.bodyMedium,
                    color = if (amount >= 0) MaterialTheme.colorScheme.primary 
                           else MaterialTheme.colorScheme.error
                )
                Text(
                    text = "New balance: ${user.credits + amount} credits",
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = "Reason: $reason",
                    style = MaterialTheme.typography.bodySmall
                )
            }
        },
        confirmButton = {
            Button(onClick = onConfirm) {
                Text("Confirm")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}

@Composable
private fun SuccessDialog(
    message: String,
    onDismiss: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        icon = {
            Icon(
                Icons.Filled.CheckCircle,
                contentDescription = null,
                modifier = Modifier.size(48.dp),
                tint = MaterialTheme.colorScheme.primary
            )
        },
        title = {
            Text("Success")
        },
        text = {
            Text(message)
        },
        confirmButton = {
            Button(onClick = onDismiss) {
                Text("OK")
            }
        }
    )
}

@Composable
private fun ErrorMessage(
    error: String,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier,
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.3f)
        ),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.error.copy(alpha = 0.3f))
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = error,
                color = MaterialTheme.colorScheme.onErrorContainer,
                textAlign = TextAlign.Center
            )
            Spacer(modifier = Modifier.height(8.dp))
            TextButton(onClick = onRetry) {
                Text("Retry")
            }
        }
    }
}

enum class CreditAdjustmentStep {
    USER_SEARCH,
    ADJUSTMENT_FORM
}