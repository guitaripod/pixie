package com.guitaripod.pixie.presentation.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.AdminPanelSettings
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.automirrored.filled.ArrowForwardIos
import androidx.compose.material.icons.automirrored.filled.HelpOutline
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.guitaripod.pixie.BuildConfig
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    viewModel: SettingsViewModel,
    onNavigateBack: () -> Unit,
    onNavigateToHelp: () -> Unit,
    onNavigateToAdmin: () -> Unit,
    onLogout: () -> Unit
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    var showLogoutDialog by remember { mutableStateOf(false) }
    var showClearCacheDialog by remember { mutableStateOf(false) }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Settings") },
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
                .verticalScroll(rememberScrollState())
        ) {
            // Appearance Section
            SettingsSection(title = "Appearance") {
                ThemeSelector(
                    currentTheme = uiState.userPreferences.theme,
                    onThemeSelected = { theme ->
                        scope.launch {
                            viewModel.updateTheme(theme)
                        }
                    }
                )
            }
            
            // Defaults Section
            SettingsSection(title = "Defaults") {
                DefaultQualitySelector(
                    currentQuality = uiState.userPreferences.defaultQuality,
                    onQualitySelected = { quality ->
                        scope.launch {
                            viewModel.updateDefaultQuality(quality)
                        }
                    }
                )
                
                Spacer(modifier = Modifier.height(12.dp))
                
                DefaultSizeSelector(
                    currentSize = uiState.userPreferences.defaultSize,
                    onSizeSelected = { size ->
                        scope.launch {
                            viewModel.updateDefaultSize(size)
                        }
                    }
                )
                
                Spacer(modifier = Modifier.height(12.dp))
                
                DefaultFormatSelector(
                    currentFormat = uiState.userPreferences.defaultOutputFormat,
                    onFormatSelected = { format ->
                        scope.launch {
                            viewModel.updateDefaultOutputFormat(format)
                        }
                    }
                )
                
                if (uiState.userPreferences.defaultOutputFormat != com.guitaripod.pixie.data.model.DefaultOutputFormat.PNG) {
                    Spacer(modifier = Modifier.height(12.dp))
                    
                    CompressionLevelSlider(
                        currentLevel = uiState.userPreferences.defaultCompressionLevel,
                        onLevelChanged = { level ->
                            scope.launch {
                                viewModel.updateDefaultCompressionLevel(level)
                            }
                        }
                    )
                }
            }
            
            // Storage Section
            SettingsSection(title = "Storage") {
                CacheManagement(
                    cacheSize = uiState.cacheSize,
                    onClearCache = {
                        showClearCacheDialog = true
                    }
                )
            }
            
            // API Section
            SettingsSection(title = "API") {
                ConnectionStatus(
                    connectionStatus = uiState.connectionStatus,
                    onTestConnection = {
                        scope.launch {
                            viewModel.testConnection()
                        }
                    }
                )
            }
            
            // Admin Section (only shown for admins)
            if (uiState.isAdmin) {
                SettingsSection(title = "Admin") {
                    SettingsItem(
                        icon = Icons.Filled.AdminPanelSettings,
                        title = "Admin Dashboard",
                        subtitle = "Manage system and users",
                        onClick = onNavigateToAdmin
                    )
                }
            }
            
            // Help & Support Section
            SettingsSection(title = "Help & Support") {
                SettingsItem(
                    icon = Icons.AutoMirrored.Filled.HelpOutline,
                    title = "Help Documentation",
                    subtitle = "Learn how to use Pixie",
                    onClick = onNavigateToHelp
                )
                
                SettingsItem(
                    icon = Icons.Filled.Info,
                    title = "About",
                    subtitle = "Version ${BuildConfig.VERSION_NAME}",
                    onClick = { }
                )
            }
            
            // Account Section
            SettingsSection(title = "Account") {
                SettingsItem(
                    icon = Icons.AutoMirrored.Filled.Logout,
                    title = "Log Out",
                    subtitle = "Sign out of your account",
                    onClick = { showLogoutDialog = true },
                    tint = MaterialTheme.colorScheme.error
                )
            }
            
            Spacer(modifier = Modifier.height(16.dp))
        }
    }
    
    // Logout Confirmation Dialog
    if (showLogoutDialog) {
        AlertDialog(
            onDismissRequest = { showLogoutDialog = false },
            title = { Text("Log Out") },
            text = { Text("Are you sure you want to log out? You'll need to sign in again to use Pixie.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showLogoutDialog = false
                        onLogout()
                    },
                    colors = ButtonDefaults.textButtonColors(
                        contentColor = MaterialTheme.colorScheme.error
                    )
                ) {
                    Text("Log Out")
                }
            },
            dismissButton = {
                TextButton(onClick = { showLogoutDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
    
    // Clear Cache Confirmation Dialog
    if (showClearCacheDialog) {
        AlertDialog(
            onDismissRequest = { showClearCacheDialog = false },
            title = { Text("Clear Cache") },
            text = { Text("This will delete all cached images. Are you sure?") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showClearCacheDialog = false
                        scope.launch {
                            viewModel.clearCache()
                        }
                    }
                ) {
                    Text("Clear")
                }
            },
            dismissButton = {
                TextButton(onClick = { showClearCacheDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}

@Composable
private fun SettingsSection(
    title: String,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.colorScheme.primary,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(vertical = 16.dp)
        )
        
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
            )
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                content = content
            )
        }
    }
}

@Composable
private fun SettingsItem(
    icon: ImageVector,
    title: String,
    subtitle: String? = null,
    onClick: () -> Unit,
    tint: androidx.compose.ui.graphics.Color = MaterialTheme.colorScheme.onSurface
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .clickable(onClick = onClick)
            .padding(vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = tint,
            modifier = Modifier.size(24.dp)
        )
        
        Spacer(modifier = Modifier.width(16.dp))
        
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge,
                color = tint
            )
            subtitle?.let {
                Text(
                    text = it,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        
        Icon(
            imageVector = Icons.AutoMirrored.Filled.ArrowForwardIos,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun ThemeSelector(
    currentTheme: com.guitaripod.pixie.data.model.AppTheme,
    onThemeSelected: (com.guitaripod.pixie.data.model.AppTheme) -> Unit
) {
    Column {
        Text(
            text = "Theme",
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.Medium
        )
        
        Spacer(modifier = Modifier.height(8.dp))
        
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            com.guitaripod.pixie.data.model.AppTheme.values().forEach { theme ->
                FilterChip(
                    selected = currentTheme == theme,
                    onClick = { onThemeSelected(theme) },
                    label = { 
                        Text(
                            when (theme) {
                                com.guitaripod.pixie.data.model.AppTheme.LIGHT -> "Light"
                                com.guitaripod.pixie.data.model.AppTheme.DARK -> "Dark"
                                com.guitaripod.pixie.data.model.AppTheme.SYSTEM -> "System"
                            }
                        )
                    },
                    modifier = Modifier.weight(1f)
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DefaultQualitySelector(
    currentQuality: com.guitaripod.pixie.data.model.DefaultImageQuality,
    onQualitySelected: (com.guitaripod.pixie.data.model.ImageQuality) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    
    Column {
        Text(
            text = "Default Quality",
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.Medium
        )
        
        Spacer(modifier = Modifier.height(8.dp))
        
        ExposedDropdownMenuBox(
            expanded = expanded,
            onExpandedChange = { expanded = it }
        ) {
            OutlinedTextField(
                value = when (currentQuality) {
                    com.guitaripod.pixie.data.model.DefaultImageQuality.LOW -> "Low (~4-5 credits)"
                    com.guitaripod.pixie.data.model.DefaultImageQuality.MEDIUM -> "Medium (~12-15 credits)"
                    com.guitaripod.pixie.data.model.DefaultImageQuality.HIGH -> "High (~50-80 credits)"
                    com.guitaripod.pixie.data.model.DefaultImageQuality.AUTO -> "Auto (AI selects)"
                },
                onValueChange = {},
                readOnly = true,
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                modifier = Modifier
                    .fillMaxWidth()
                    .menuAnchor(MenuAnchorType.PrimaryNotEditable)
            )
            
            ExposedDropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false }
            ) {
                listOf(
                    com.guitaripod.pixie.data.model.ImageQuality.LOW to "Low (~4-5 credits)",
                    com.guitaripod.pixie.data.model.ImageQuality.MEDIUM to "Medium (~12-15 credits)",
                    com.guitaripod.pixie.data.model.ImageQuality.HIGH to "High (~50-80 credits)",
                    com.guitaripod.pixie.data.model.ImageQuality.AUTO to "Auto (AI selects)"
                ).forEach { (quality, label) ->
                    DropdownMenuItem(
                        text = { Text(label) },
                        onClick = {
                            onQualitySelected(quality)
                            expanded = false
                        }
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DefaultSizeSelector(
    currentSize: String,
    onSizeSelected: (String) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    
    val sizeOptions = listOf(
        "square" to "Square (1024×1024)",
        "landscape" to "Landscape (1536×1024)",
        "portrait" to "Portrait (1024×1536)",
        "auto" to "Auto (AI selects)"
    )
    
    val currentLabel = sizeOptions.find { it.first == currentSize }?.second ?: currentSize
    
    Column {
        Text(
            text = "Default Size",
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.Medium
        )
        
        Spacer(modifier = Modifier.height(8.dp))
        
        ExposedDropdownMenuBox(
            expanded = expanded,
            onExpandedChange = { expanded = it }
        ) {
            OutlinedTextField(
                value = currentLabel,
                onValueChange = {},
                readOnly = true,
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                modifier = Modifier
                    .fillMaxWidth()
                    .menuAnchor(MenuAnchorType.PrimaryNotEditable)
            )
            
            ExposedDropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false }
            ) {
                sizeOptions.forEach { (value, label) ->
                    DropdownMenuItem(
                        text = { Text(label) },
                        onClick = {
                            onSizeSelected(value)
                            expanded = false
                        }
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DefaultFormatSelector(
    currentFormat: com.guitaripod.pixie.data.model.DefaultOutputFormat,
    onFormatSelected: (com.guitaripod.pixie.data.model.OutputFormat) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    
    Column {
        Text(
            text = "Default Format",
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.Medium
        )
        
        Spacer(modifier = Modifier.height(8.dp))
        
        ExposedDropdownMenuBox(
            expanded = expanded,
            onExpandedChange = { expanded = it }
        ) {
            OutlinedTextField(
                value = currentFormat.name,
                onValueChange = {},
                readOnly = true,
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                modifier = Modifier
                    .fillMaxWidth()
                    .menuAnchor(MenuAnchorType.PrimaryNotEditable)
            )
            
            ExposedDropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false }
            ) {
                com.guitaripod.pixie.data.model.OutputFormat.values().forEach { format ->
                    DropdownMenuItem(
                        text = { Text(format.name) },
                        onClick = {
                            onFormatSelected(format)
                            expanded = false
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun CompressionLevelSlider(
    currentLevel: Int,
    onLevelChanged: (Int) -> Unit
) {
    Column {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                text = "Compression Level",
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium
            )
            Text(
                text = "$currentLevel%",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        
        Spacer(modifier = Modifier.height(8.dp))
        
        Slider(
            value = currentLevel.toFloat(),
            onValueChange = { onLevelChanged(it.toInt()) },
            valueRange = 0f..100f,
            steps = 19
        )
    }
}

@Composable
private fun CacheManagement(
    cacheSize: String,
    onClearCache: () -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column {
            Text(
                text = "Image Cache",
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium
            )
            Text(
                text = cacheSize,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        
        Button(
            onClick = onClearCache,
            colors = ButtonDefaults.buttonColors(
                containerColor = MaterialTheme.colorScheme.error
            )
        ) {
            Text("Clear")
        }
    }
}

@Composable
private fun ConnectionStatus(
    connectionStatus: com.guitaripod.pixie.presentation.settings.ConnectionStatus,
    onTestConnection: () -> Unit
) {
    Column {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = "API Connection",
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.Medium
                )
                Text(
                    text = "Test connection to Pixie servers",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            
            TextButton(onClick = onTestConnection) {
                Text("Test")
            }
        }
        
        when (connectionStatus) {
            is ConnectionStatus.Idle -> Unit
            is ConnectionStatus.Testing -> {
                Spacer(modifier = Modifier.height(8.dp))
                LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
            }
            is ConnectionStatus.Success -> {
                Spacer(modifier = Modifier.height(8.dp))
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.primaryContainer
                    )
                ) {
                    Row(
                        modifier = Modifier.padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.Filled.CheckCircle,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(20.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = "Connected successfully",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onPrimaryContainer
                        )
                    }
                }
            }
            is ConnectionStatus.Error -> {
                Spacer(modifier = Modifier.height(8.dp))
                Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(
                        containerColor = MaterialTheme.colorScheme.errorContainer
                    )
                ) {
                    Row(
                        modifier = Modifier.padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.Filled.Warning,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.error,
                            modifier = Modifier.size(20.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = connectionStatus.message,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onErrorContainer
                        )
                    }
                }
            }
        }
    }
}