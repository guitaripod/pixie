package com.guitaripod.pixie.presentation.help

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HelpScreen(
    onNavigateBack: () -> Unit
) {
    var selectedTab by remember { mutableStateOf(0) }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Help") },
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
            TabRow(selectedTabIndex = selectedTab) {
                Tab(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    text = { Text("Getting Started") }
                )
                Tab(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    text = { Text("Features") }
                )
                Tab(
                    selected = selectedTab == 2,
                    onClick = { selectedTab = 2 },
                    text = { Text("FAQ") }
                )
            }
            
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp)
            ) {
                when (selectedTab) {
                    0 -> GettingStartedContent()
                    1 -> FeaturesContent()
                    2 -> FAQContent()
                }
            }
        }
    }
}

@Composable
private fun GettingStartedContent() {
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        HelpSection(
            title = "Welcome to Pixie",
            content = """
                Pixie is a powerful AI image generation app powered by gpt-image-1. Create stunning images from text descriptions, edit existing images, and browse galleries of amazing creations.
            """.trimIndent()
        )
        
        HelpSection(
            title = "Quick Start",
            content = """
                1. **Generate Images**: Tap the bottom toolbar and enter a description
                2. **Edit Images**: Select an image from gallery or your device
                3. **Browse Gallery**: Explore public images or view your creations
                4. **Manage Credits**: Check your balance and purchase more credits
            """.trimIndent()
        )
        
        HelpSection(
            title = "Authentication",
            content = """
                Sign in with your preferred provider:
                • GitHub (recommended)
                • Google
                • Apple
                
                Your account syncs across all devices and with the CLI tool.
            """.trimIndent()
        )
    }
}

@Composable
private fun FeaturesContent() {
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        HelpSection(
            title = "Image Generation",
            content = """
                **Quality Options:**
                • Low: ~4-6 credits per image
                • Medium: ~16-24 credits per image
                • High: ~62-94 credits per image
                • Auto: ~50-75 credits (AI selects)
                
                **Size Options:**
                • Square (1024×1024)
                • Landscape (1536×1024)
                • Portrait (1024×1536)
                • Auto (AI selects optimal)
                
                **Advanced Options:**
                • Background: Auto, transparent, white, black
                • Format: PNG, JPEG, WebP
                • Compression: 0-100 (JPEG/WebP only)
                • Moderation: Auto (default), Low (less restrictive)
            """.trimIndent()
        )
        
        HelpSection(
            title = "Image Editing",
            content = """
                Transform existing images with AI:
                
                **Edit Options:**
                • Change styles (cyberpunk, oil painting, etc.)
                • Add or remove elements
                • Enhance details
                • Create variations
                
                **Quality & Fidelity:**
                • Low fidelity: More creative freedom
                • High fidelity: Preserves faces/logos better
                
                **Credit Costs:**
                Base edit cost + quality cost:
                • Low: ~7 credits
                • Medium: ~16 credits
                • High: ~72-110 credits
            """.trimIndent()
        )
        
        HelpSection(
            title = "Gallery Features",
            content = """
                **Public Gallery:**
                • Browse all public images
                • View image details and prompts
                • Copy prompts for inspiration
                • Download or share images
                
                **My Images:**
                • View your generated images
                • Edit from gallery
                • Manage your creations
                • Track image metadata
            """.trimIndent()
        )
        
        HelpSection(
            title = "Credits System",
            content = """
                **Understanding Credits:**
                • Credits never expire
                • Shared across all platforms
                • Used for image generation and editing
                
                **Usage Tracking:**
                • View daily/weekly/monthly usage
                • Export usage data as CSV
                • Monitor credit consumption
                • Set up low balance alerts
            """.trimIndent()
        )
    }
}

@Composable
private fun FAQContent() {
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        FAQItem(
            question = "How do credits work?",
            answer = "Credits are the currency used to generate and edit images. Each operation costs a different amount based on quality and size."
        )
        
        FAQItem(
            question = "Can I use my own OpenAI API key?",
            answer = "Yes! The backend supports using your own OpenAI API key. Contact support to set this up for your account."
        )
        
        FAQItem(
            question = "What's the difference between quality levels?",
            answer = "Higher quality produces more detailed images but costs more credits. Low quality is great for drafts and experiments, while high quality is best for final artwork."
        )
        
        FAQItem(
            question = "How do I get transparent backgrounds?",
            answer = "Select 'Transparent' in the background options when generating images. This works best with isolated subjects like logos or products."
        )
        
        FAQItem(
            question = "Can I edit images from my gallery?",
            answer = "Yes! Long-press any image in the gallery and select 'Edit' to modify it with AI."
        )
        
        FAQItem(
            question = "Is my data private?",
            answer = "Your API keys are stored securely on your device. Images you generate are private unless you explicitly share them to the public gallery."
        )
        
        FAQItem(
            question = "How do I report issues?",
            answer = "Report issues at github.com/anthropics/claude-code/issues or contact support through the app."
        )
        
        FAQItem(
            question = "Can I use Pixie offline?",
            answer = "No, Pixie requires an internet connection to communicate with the AI servers for image generation."
        )
    }
}

@Composable
private fun HelpSection(
    title: String,
    content: String
) {
    Column {
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = content,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface
        )
    }
}

@Composable
private fun FAQItem(
    question: String,
    answer: String
) {
    var expanded by remember { mutableStateOf(false) }
    
    Card(
        modifier = Modifier.fillMaxWidth(),
        onClick = { expanded = !expanded }
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Text(
                text = question,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.primary
            )
            
            if (expanded) {
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = answer,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}