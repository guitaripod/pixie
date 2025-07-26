package com.guitaripod.pixie.presentation.chat

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.*
import androidx.compose.foundation.interaction.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import coil.compose.AsyncImage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import android.content.ContentUris
import android.provider.MediaStore
import com.guitaripod.pixie.utils.rememberHapticFeedback
import com.guitaripod.pixie.utils.hapticClickable

data class QuickAction(
    val icon: ImageVector,
    val title: String,
    val description: String,
    val prompt: String,
    val backgroundColor: Color,
    val iconTint: Color = Color.White
)

data class CreativePrompt(
    val category: String,
    val emoji: String,
    val prompts: List<String>,
    val color: Color
)

data class StylePreset(
    val name: String,
    val description: String,
    val prompt: String,
    val icon: ImageVector,
    val gradient: List<Color>
)

private val ContentHorizontalPadding = 8.dp
private val SectionSpacing = 24.dp
private val ItemSpacing = 8.dp

private fun Modifier.scaleClickable(
    onClick: () -> Unit,
    enabled: Boolean = true
) = composed {
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()
    
    val scale by animateFloatAsState(
        targetValue = if (isPressed) 0.95f else 1f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessLow
        )
    )
    
    this
        .scale(scale)
        .clickable(
            interactionSource = interactionSource,
            indication = null,
            enabled = enabled,
            onClick = onClick
        )
}

@Composable
fun SuggestionsView(
    onPromptSelected: (String) -> Unit,
    onImageSelected: (android.net.Uri) -> Unit,
    isInEditMode: Boolean = false,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    var recentImages by remember { mutableStateOf<List<android.net.Uri>>(emptyList()) }
    
    val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.READ_MEDIA_IMAGES
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
    } else {
        ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.READ_EXTERNAL_STORAGE
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
    }
    
    val galleryLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri ->
        uri?.let { onImageSelected(it) }
    }
    
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        if (isGranted) {
            galleryLauncher.launch("image/*")
        }
    }
    
    LaunchedEffect(hasPermission) {
        if (hasPermission) {
            recentImages = loadRecentImages(context)
        }
    }
    
    Column(
        modifier = modifier
            .fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(SectionSpacing)
    ) {
        EditImageSection(
            recentImages = recentImages,
            hasPermission = hasPermission,
            onImageSelected = onImageSelected,
            onRequestPermission = {
                if (hasPermission) {
                    galleryLauncher.launch("image/*")
                } else {
                    val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        Manifest.permission.READ_MEDIA_IMAGES
                    } else {
                        Manifest.permission.READ_EXTERNAL_STORAGE
                    }
                    permissionLauncher.launch(permission)
                }
            }
        )
        
        QuickActionsSection(
            onActionSelected = { action ->
                onPromptSelected(action.prompt)
            },
            isInEditMode = isInEditMode
        )
        
        CreativePromptsSection(
            onPromptSelected = onPromptSelected
        )
        
        StylePresetsSection(
            onStyleSelected = { style ->
                onPromptSelected(style.prompt)
            }
        )
        
        PromptModifiersSection()
        
        Spacer(modifier = Modifier.height(ContentHorizontalPadding * 2))
    }
}


@Composable
private fun QuickActionsSection(
    onActionSelected: (QuickAction) -> Unit,
    isInEditMode: Boolean = false
) {
    val quickActions = remember(isInEditMode) {
        if (isInEditMode) {
            listOf(
                QuickAction(
                    icon = Icons.Default.ColorLens,
                    title = "Recolor",
                    description = "Change colors",
                    prompt = "Change the color scheme to vibrant warm tones",
                    backgroundColor = Color(0xFF6366F1)
                ),
                QuickAction(
                    icon = Icons.Default.WbSunny,
                    title = "Lighting",
                    description = "Adjust lighting",
                    prompt = "Make the lighting brighter and add golden hour effect",
                    backgroundColor = Color(0xFF10B981)
                ),
                QuickAction(
                    icon = Icons.Default.Brush,
                    title = "Art Style",
                    description = "Apply art style",
                    prompt = "Transform this into a watercolor painting style",
                    backgroundColor = Color(0xFFF59E0B)
                ),
                QuickAction(
                    icon = Icons.Default.CropFree,
                    title = "Remove",
                    description = "Remove objects",
                    prompt = "Remove all unwanted objects and distractions from the background",
                    backgroundColor = Color(0xFFEF4444)
                ),
                QuickAction(
                    icon = Icons.Default.AutoAwesome,
                    title = "Enhance",
                    description = "Auto enhance",
                    prompt = "Enhance the image quality, make it sharper and more vibrant",
                    backgroundColor = Color(0xFF8B5CF6)
                ),
                QuickAction(
                    icon = Icons.Default.Nightlight,
                    title = "Night",
                    description = "Night mode",
                    prompt = "Transform this into a beautiful nighttime scene with stars and moonlight",
                    backgroundColor = Color(0xFF1E40AF)
                ),
                QuickAction(
                    icon = Icons.Default.WbCloudy,
                    title = "Weather",
                    description = "Add weather",
                    prompt = "Add dramatic storm clouds and rain to create a moody atmosphere",
                    backgroundColor = Color(0xFF64748B)
                ),
                QuickAction(
                    icon = Icons.Default.Timer,
                    title = "Season",
                    description = "Change season",
                    prompt = "Transform this into a beautiful autumn scene with fall colors",
                    backgroundColor = Color(0xFFDC2626)
                ),
                QuickAction(
                    icon = Icons.Default.Face,
                    title = "Age",
                    description = "Age progression",
                    prompt = "Make the person look 20 years older while keeping them recognizable",
                    backgroundColor = Color(0xFF7C3AED)
                ),
                QuickAction(
                    icon = Icons.Default.SentimentVerySatisfied,
                    title = "Expression",
                    description = "Change mood",
                    prompt = "Make the person smile naturally and look happy",
                    backgroundColor = Color(0xFFF59E0B)
                ),
                QuickAction(
                    icon = Icons.Default.Wallpaper,
                    title = "Background",
                    description = "New background",
                    prompt = "Replace the background with a tropical beach paradise",
                    backgroundColor = Color(0xFF0891B2)
                ),
                QuickAction(
                    icon = Icons.Default.BlurOn,
                    title = "Blur",
                    description = "Depth effect",
                    prompt = "Add professional bokeh blur to the background, keep subject sharp",
                    backgroundColor = Color(0xFF059669)
                ),
                QuickAction(
                    icon = Icons.Default.Bedtime,
                    title = "Dreamy",
                    description = "Dream effect",
                    prompt = "Make this look dreamy and ethereal with soft glowing light",
                    backgroundColor = Color(0xFFA855F7)
                ),
                QuickAction(
                    icon = Icons.Default.PhotoFilter,
                    title = "Vintage",
                    description = "Retro style",
                    prompt = "Apply vintage film photography style with grain and faded colors",
                    backgroundColor = Color(0xFF92400E)
                ),
                QuickAction(
                    icon = Icons.Default.Bolt,
                    title = "Cyberpunk",
                    description = "Futuristic",
                    prompt = "Transform into cyberpunk style with neon lights and futuristic elements",
                    backgroundColor = Color(0xFFE11D48)
                ),
                QuickAction(
                    icon = Icons.Default.Spa,
                    title = "Minimal",
                    description = "Simplify",
                    prompt = "Make this minimalist and clean, remove clutter, simple composition",
                    backgroundColor = Color(0xFF475569)
                ),
                QuickAction(
                    icon = Icons.Default.LocalFireDepartment,
                    title = "Dramatic",
                    description = "Intense mood",
                    prompt = "Make this dramatic with strong contrast and moody lighting",
                    backgroundColor = Color(0xFFB91C1C)
                )
            )
        } else {
            listOf(
                QuickAction(
                    icon = Icons.Default.Portrait,
                    title = "Portrait",
                    description = "Professional headshot",
                    prompt = "Professional portrait photo of a person, studio lighting, high quality, sharp focus",
                    backgroundColor = Color(0xFF6366F1)
                ),
                QuickAction(
                    icon = Icons.Default.Landscape,
                    title = "Landscape",
                    description = "Beautiful scenery",
                    prompt = "Breathtaking landscape photography, golden hour lighting, dramatic sky, high resolution",
                    backgroundColor = Color(0xFF10B981)
                ),
                QuickAction(
                    icon = Icons.Default.Brush,
                    title = "Digital Art",
                    description = "Creative artwork",
                    prompt = "Digital artwork, vibrant colors, detailed illustration, professional quality",
                    backgroundColor = Color(0xFFF59E0B)
                ),
                QuickAction(
                    icon = Icons.Default.Architecture,
                    title = "Architecture",
                    description = "Modern buildings",
                    prompt = "Modern architecture photography, clean lines, minimalist design, professional composition",
                    backgroundColor = Color(0xFFEF4444)
                ),
                QuickAction(
                    icon = Icons.Default.Pets,
                    title = "Animals",
                    description = "Cute creatures",
                    prompt = "Adorable animal portrait, detailed fur texture, expressive eyes, natural lighting",
                    backgroundColor = Color(0xFF8B5CF6)
                ),
                QuickAction(
                    icon = Icons.Default.Restaurant,
                    title = "Food",
                    description = "Delicious dishes",
                    prompt = "Professional food photography, appetizing presentation, restaurant quality, shallow depth of field",
                    backgroundColor = Color(0xFFEC4899)
                ),
                QuickAction(
                    icon = Icons.Default.Bolt,
                    title = "Cyberpunk",
                    description = "Neon future",
                    prompt = "Cyberpunk cityscape with neon lights, flying cars, rain, blade runner style",
                    backgroundColor = Color(0xFFE11D48)
                ),
                QuickAction(
                    icon = Icons.Default.Castle,
                    title = "Fantasy",
                    description = "Magic worlds",
                    prompt = "Epic fantasy landscape with magical elements, dragons, castles, mystical atmosphere",
                    backgroundColor = Color(0xFF7C3AED)
                ),
                QuickAction(
                    icon = Icons.Default.Rocket,
                    title = "Space",
                    description = "Cosmic art",
                    prompt = "Stunning space scene with galaxies, nebulas, planets, cosmic colors",
                    backgroundColor = Color(0xFF1E293B)
                ),
                QuickAction(
                    icon = Icons.Default.LocalFlorist,
                    title = "Macro",
                    description = "Close-up detail",
                    prompt = "Extreme macro photography, intricate details, shallow depth of field, professional quality",
                    backgroundColor = Color(0xFF0F766E)
                ),
                QuickAction(
                    icon = Icons.Default.Bedtime,
                    title = "Surreal",
                    description = "Dream-like",
                    prompt = "Surreal dreamscape with impossible geometry, floating objects, Salvador Dali style",
                    backgroundColor = Color(0xFF6D28D9)
                ),
                QuickAction(
                    icon = Icons.Default.PhotoFilter,
                    title = "Retro",
                    description = "80s vibes",
                    prompt = "80s retro style with synthwave colors, palm trees, sunset, miami vice aesthetic",
                    backgroundColor = Color(0xFFDB2777)
                ),
                QuickAction(
                    icon = Icons.Default.Water,
                    title = "Underwater",
                    description = "Ocean depths",
                    prompt = "Underwater photography, coral reef, tropical fish, sun rays through water",
                    backgroundColor = Color(0xFF0284C7)
                ),
                QuickAction(
                    icon = Icons.Default.Toys,
                    title = "Miniature",
                    description = "Tiny worlds",
                    prompt = "Miniature tilt-shift photography effect, looks like a tiny model world",
                    backgroundColor = Color(0xFFF97316)
                )
            )
        }
    }
    
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        SectionHeader(
            title = "Quick Actions",
            subtitle = "Start with popular templates"
        )
        
        LazyRow(
            contentPadding = PaddingValues(horizontal = ContentHorizontalPadding),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            items(quickActions.chunked(3)) { columnActions ->
                Column(
                    verticalArrangement = Arrangement.spacedBy(ItemSpacing)
                ) {
                    columnActions.forEach { action ->
                        QuickActionCard(
                            action = action,
                            onClick = { onActionSelected(action) }
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun QuickActionCard(
    action: QuickAction,
    onClick: () -> Unit
) {
    val haptic = rememberHapticFeedback()
    Surface(
        modifier = Modifier
            .width(100.dp)
            .height(40.dp)
            .scaleClickable(
                onClick = { 
                    haptic.click()
                    onClick() 
                }
            ),
        shape = RoundedCornerShape(20.dp),
        color = action.backgroundColor,
        tonalElevation = 2.dp
    ) {
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Icon(
                imageVector = action.icon,
                contentDescription = null,
                tint = action.iconTint,
                modifier = Modifier.size(16.dp)
            )
            
            Text(
                text = action.title,
                style = MaterialTheme.typography.labelMedium,
                color = Color.White,
                fontWeight = FontWeight.Medium,
                maxLines = 1
            )
        }
    }
}

@Composable
private fun EditImageSection(
    recentImages: List<android.net.Uri>,
    hasPermission: Boolean,
    onImageSelected: (android.net.Uri) -> Unit,
    onRequestPermission: () -> Unit
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = ContentHorizontalPadding),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            SectionHeader(
                title = "Edit an Image",
                subtitle = "Transform your photos with AI"
            )
            
            val haptic = rememberHapticFeedback()
            TextButton(onClick = {
                haptic.click()
                onRequestPermission()
            }) {
                Text("Browse")
            }
        }
        
        if (hasPermission && recentImages.isNotEmpty()) {
            LazyRow(
                contentPadding = PaddingValues(horizontal = ContentHorizontalPadding),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                item {
                    AddImageCard(onClick = onRequestPermission)
                }
                
                items(recentImages.take(10)) { uri ->
                    RecentImageCard(
                        uri = uri,
                        onClick = { onImageSelected(uri) }
                    )
                }
            }
        } else {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
            ) {
                AddImageCard(
                    onClick = onRequestPermission,
                    modifier = Modifier.weight(1f)
                )
            }
        }
    }
}

@Composable
private fun AddImageCard(
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val haptic = rememberHapticFeedback()
    Card(
        modifier = modifier
            .height(120.dp)
            .scaleClickable(
                onClick = { 
                    haptic.click()
                    onClick() 
                }
            ),
        shape = RoundedCornerShape(12.dp),
        border = BorderStroke(
            width = 2.dp,
            color = MaterialTheme.colorScheme.primary.copy(alpha = 0.5f)
        ),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f)
        )
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            contentAlignment = Alignment.Center
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.AddPhotoAlternate,
                    contentDescription = "Add image",
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(32.dp)
                )
                
                Text(
                    text = "Choose Image",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.Medium
                )
            }
        }
    }
}

@Composable
private fun RecentImageCard(
    uri: android.net.Uri,
    onClick: () -> Unit
) {
    val haptic = rememberHapticFeedback()
    Card(
        modifier = Modifier
            .size(120.dp)
            .scaleClickable(
                onClick = { 
                    haptic.click()
                    onClick() 
                }
            ),
        shape = RoundedCornerShape(12.dp)
    ) {
        Box {
            AsyncImage(
                model = uri,
                contentDescription = "Recent image",
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize()
            )
            
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        Brush.verticalGradient(
                            colors = listOf(
                                Color.Transparent,
                                Color.Black.copy(alpha = 0.3f)
                            )
                        )
                    )
            )
        }
    }
}

@Composable
private fun CreativePromptsSection(
    onPromptSelected: (String) -> Unit
) {
    val categories = remember {
        listOf(
            CreativePrompt(
                category = "Fantasy",
                emoji = "🐉",
                prompts = listOf(
                    "Majestic dragon soaring through cloudy skies, fantasy art style",
                    "Futuristic city with flying cars and neon lights at night",
                    "Magical forest with glowing mushrooms and fairy lights",
                    "Space station orbiting a distant planet with multiple moons",
                    "Steampunk airship floating above Victorian London",
                    "Enchanted castle on floating island in the clouds"
                ),
                color = Color(0xFF9333EA)
            ),
            CreativePrompt(
                category = "Nature",
                emoji = "🌿",
                prompts = listOf(
                    "Majestic eagle soaring over mountain peaks at sunrise",
                    "Underwater coral reef teeming with colorful tropical fish",
                    "Northern lights dancing over a frozen lake in winter",
                    "Ancient tree with twisted roots in misty forest",
                    "Butterfly garden with hundreds of colorful butterflies",
                    "Thunderstorm over dramatic desert landscape"
                ),
                color = Color(0xFF059669)
            ),
            CreativePrompt(
                category = "Abstract",
                emoji = "🎨",
                prompts = listOf(
                    "Vibrant abstract painting with swirling colors and geometric shapes",
                    "Minimalist composition with bold colors and clean lines",
                    "Surreal dreamscape with floating objects and impossible geometry",
                    "Pop art style portrait with bright colors and comic book aesthetics",
                    "Impressionist painting of a sunset over lavender fields",
                    "Fractal patterns with infinite complexity and vivid colors"
                ),
                color = Color(0xFFDC2626)
            ),
            CreativePrompt(
                category = "Urban",
                emoji = "🏙️",
                prompts = listOf(
                    "High fashion photoshoot in minimalist studio setting",
                    "Cozy coffee shop interior with warm lighting and plants",
                    "Street style fashion photography in urban setting",
                    "Luxury spa interior with zen garden and natural materials",
                    "Modern home office with scandinavian design aesthetic",
                    "Bustling city street at night with neon signs"
                ),
                color = Color(0xFFDB2777)
            ),
            CreativePrompt(
                category = "Tech",
                emoji = "🤖",
                prompts = listOf(
                    "Advanced AI robot assistant helping in modern home",
                    "Holographic interface displaying complex data visualization",
                    "Electric vehicle charging station of the future",
                    "Virtual reality user exploring digital worlds",
                    "Quantum computer in high-tech laboratory setting",
                    "Cybernetic augmentations on human body"
                ),
                color = Color(0xFF2563EB)
            )
        )
    }
    
    var selectedCategory by remember { mutableStateOf(categories.first()) }
    
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        SectionHeader(
            title = "Creative Prompts",
            subtitle = "Tap a category, then select a prompt"
        )
        
        LazyRow(
            contentPadding = PaddingValues(horizontal = ContentHorizontalPadding),
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            items(categories) { category ->
                CategoryChip(
                    category = category,
                    isSelected = category == selectedCategory,
                    onClick = { selectedCategory = category }
                )
            }
        }
        
        LazyRow(
            contentPadding = PaddingValues(horizontal = ContentHorizontalPadding),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(selectedCategory.prompts.chunked(2)) { columnPrompts ->
                Column(
                    verticalArrangement = Arrangement.spacedBy(ItemSpacing)
                ) {
                    columnPrompts.forEach { prompt ->
                        CompactPromptCard(
                            prompt = prompt,
                            color = selectedCategory.color,
                            onClick = { onPromptSelected(prompt) }
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun CategoryChip(
    category: CreativePrompt,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    val haptic = rememberHapticFeedback()
    FilterChip(
        selected = isSelected,
        onClick = {
            haptic.click()
            onClick()
        },
        modifier = Modifier.height(32.dp),
        label = {
            Row(
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = category.emoji,
                    style = MaterialTheme.typography.labelMedium
                )
                Text(
                    text = category.category,
                    style = MaterialTheme.typography.labelMedium
                )
            }
        },
        colors = FilterChipDefaults.filterChipColors(
            selectedContainerColor = category.color,
            selectedLabelColor = Color.White
        )
    )
}

@Composable
private fun CompactPromptCard(
    prompt: String,
    color: Color,
    onClick: () -> Unit
) {
    val haptic = rememberHapticFeedback()
    Surface(
        modifier = Modifier
            .width(200.dp)
            .height(60.dp)
            .scaleClickable(
                onClick = { 
                    haptic.click()
                    onClick() 
                }
            ),
        shape = RoundedCornerShape(12.dp),
        color = color.copy(alpha = 0.1f),
        border = BorderStroke(1.dp, color.copy(alpha = 0.3f))
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 12.dp, vertical = 8.dp),
            contentAlignment = Alignment.CenterStart
        ) {
            Text(
                text = prompt,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 2,
                lineHeight = 16.sp
            )
        }
    }
}

@Composable
private fun StylePresetsSection(
    onStyleSelected: (StylePreset) -> Unit
) {
    val styles = remember {
        listOf(
            StylePreset(
                name = "Cinematic",
                description = "Movie-like",
                prompt = "cinematic shot, movie still, film grain, dramatic lighting, wide angle lens",
                icon = Icons.Default.Movie,
                gradient = listOf(Color(0xFF1F2937), Color(0xFF374151))
            ),
            StylePreset(
                name = "Anime",
                description = "Japanese art",
                prompt = "anime style, manga art, cel shading, vibrant colors, detailed character design",
                icon = Icons.Default.Animation,
                gradient = listOf(Color(0xFFEC4899), Color(0xFFF472B6))
            ),
            StylePreset(
                name = "3D Render",
                description = "CGI graphics",
                prompt = "3D render, octane render, ray tracing, photorealistic, high detail, studio lighting",
                icon = Icons.Default.ViewInAr,
                gradient = listOf(Color(0xFF3B82F6), Color(0xFF60A5FA))
            ),
            StylePreset(
                name = "Oil Paint",
                description = "Classic art",
                prompt = "oil painting, traditional art, brush strokes visible, museum quality, masterpiece",
                icon = Icons.Default.Palette,
                gradient = listOf(Color(0xFFEF4444), Color(0xFFF87171))
            ),
            StylePreset(
                name = "Sketch",
                description = "Pencil art",
                prompt = "pencil sketch, detailed drawing, graphite on paper, artistic shading, hand drawn",
                icon = Icons.Default.Draw,
                gradient = listOf(Color(0xFF6B7280), Color(0xFF9CA3AF))
            ),
            StylePreset(
                name = "Watercolor",
                description = "Soft painting",
                prompt = "watercolor painting, soft edges, flowing colors, artistic bleeds, paper texture",
                icon = Icons.Default.Brush,
                gradient = listOf(Color(0xFF60A5FA), Color(0xFF93C5FD))
            ),
            StylePreset(
                name = "Comic",
                description = "Comic book",
                prompt = "comic book style, bold outlines, halftone dots, speech bubbles, superhero aesthetic",
                icon = Icons.AutoMirrored.Filled.MenuBook,
                gradient = listOf(Color(0xFFFBBF24), Color(0xFFFDE047))
            ),
            StylePreset(
                name = "Pixel Art",
                description = "8-bit style",
                prompt = "pixel art, 8-bit style, retro game aesthetic, limited color palette, blocky design",
                icon = Icons.Default.Games,
                gradient = listOf(Color(0xFF10B981), Color(0xFF34D399))
            ),
            StylePreset(
                name = "Neon",
                description = "Glowing lights",
                prompt = "neon lights, glowing effects, cyberpunk aesthetic, dark background, vibrant colors",
                icon = Icons.Default.Lightbulb,
                gradient = listOf(Color(0xFFE11D48), Color(0xFFF43F5E))
            ),
            StylePreset(
                name = "Minimal",
                description = "Simple clean",
                prompt = "minimalist style, simple composition, negative space, clean lines, modern aesthetic",
                icon = Icons.Default.CropFree,
                gradient = listOf(Color(0xFF374151), Color(0xFF4B5563))
            ),
            StylePreset(
                name = "Vintage",
                description = "Retro look",
                prompt = "vintage photography, film grain, faded colors, nostalgic mood, old camera effect",
                icon = Icons.Default.PhotoCamera,
                gradient = listOf(Color(0xFF92400E), Color(0xFFB45309))
            ),
            StylePreset(
                name = "HDR",
                description = "High detail",
                prompt = "HDR photography, high dynamic range, vivid colors, sharp details, professional quality",
                icon = Icons.Default.HdrOn,
                gradient = listOf(Color(0xFF7C3AED), Color(0xFF8B5CF6))
            )
        )
    }
    
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        SectionHeader(
            title = "Style Presets",
            subtitle = "Apply to any prompt with ' + style'"
        )
        
        LazyRow(
            contentPadding = PaddingValues(horizontal = ContentHorizontalPadding),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(styles.chunked(2)) { columnStyles ->
                Column(
                    verticalArrangement = Arrangement.spacedBy(ItemSpacing)
                ) {
                    columnStyles.forEach { style ->
                        CompactStyleCard(
                            style = style,
                            onClick = { onStyleSelected(style) }
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun CompactStyleCard(
    style: StylePreset,
    onClick: () -> Unit
) {
    val haptic = rememberHapticFeedback()
    Surface(
        modifier = Modifier
            .width(120.dp)
            .height(50.dp)
            .scaleClickable(
                onClick = { 
                    haptic.click()
                    onClick() 
                }
            ),
        shape = RoundedCornerShape(12.dp),
        color = Color.Transparent
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.linearGradient(colors = style.gradient)
                )
        ) {
            Row(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(ItemSpacing)
            ) {
                Icon(
                    imageVector = style.icon,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(20.dp)
                )
                
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.Center
                ) {
                    Text(
                        text = style.name,
                        style = MaterialTheme.typography.labelLarge,
                        color = Color.White,
                        fontWeight = FontWeight.Medium,
                        maxLines = 1
                    )
                    Text(
                        text = style.description,
                        style = MaterialTheme.typography.labelSmall,
                        color = Color.White.copy(alpha = 0.8f),
                        maxLines = 1
                    )
                }
            }
        }
    }
}

@Composable
private fun PromptModifiersSection() {
    val modifiers = remember {
        listOf(
            // Quality modifiers
            listOf("8K", "4K", "HD", "ultra detailed", "masterpiece", "best quality"),
            // Lighting modifiers
            listOf("studio lighting", "golden hour", "dramatic lighting", "soft light", "backlit", "rim lighting"),
            // Camera modifiers
            listOf("DSLR", "35mm lens", "bokeh", "depth of field", "macro lens", "wide angle"),
            // Mood modifiers
            listOf("peaceful", "dramatic", "mysterious", "energetic", "melancholic", "ethereal"),
            // Composition modifiers
            listOf("rule of thirds", "centered", "symmetrical", "dynamic pose", "close-up", "full body"),
            // Art modifiers
            listOf("trending on artstation", "award winning", "professional", "concept art", "photorealistic", "hyperrealistic")
        )
    }
    
    var selectedCategory by remember { mutableStateOf(0) }
    val categoryNames = listOf("Quality", "Lighting", "Camera", "Mood", "Composition", "Artistic")
    
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        SectionHeader(
            title = "Prompt Modifiers",
            subtitle = "Add these to enhance your prompts"
        )
        
        LazyRow(
            contentPadding = PaddingValues(horizontal = ContentHorizontalPadding),
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            items(categoryNames.size) { index ->
                val haptic = rememberHapticFeedback()
                FilterChip(
                    selected = selectedCategory == index,
                    onClick = { 
                        haptic.click()
                        selectedCategory = index 
                    },
                    modifier = Modifier.height(32.dp),
                    label = {
                        Text(
                            text = categoryNames[index],
                            style = MaterialTheme.typography.labelMedium
                        )
                    }
                )
            }
        }
        
        LazyRow(
            contentPadding = PaddingValues(horizontal = ContentHorizontalPadding),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(modifiers[selectedCategory]) { modifier ->
                ModifierChip(text = modifier)
            }
        }
    }
}

@Composable
private fun ModifierChip(text: String) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.secondaryContainer.copy(alpha = 0.7f),
        modifier = Modifier.height(32.dp)
    ) {
        Box(
            modifier = Modifier.padding(horizontal = 12.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = text,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSecondaryContainer
            )
        }
    }
}

@Composable
private fun Section(
    title: String,
    subtitle: String? = null,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        SectionHeader(title = title, subtitle = subtitle)
        content()
    }
}

@Composable
private fun SectionHeader(
    title: String,
    subtitle: String? = null,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.padding(horizontal = ContentHorizontalPadding),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold
        )
        
        subtitle?.let {
            Text(
                text = it,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

private suspend fun loadRecentImages(context: android.content.Context): List<android.net.Uri> = withContext(Dispatchers.IO) {
    val images = mutableListOf<android.net.Uri>()
    
    val projection = arrayOf(
        MediaStore.Images.Media._ID,
        MediaStore.Images.Media.DATE_MODIFIED
    )
    
    val sortOrder = "${MediaStore.Images.Media.DATE_MODIFIED} DESC"
    
    context.contentResolver.query(
        MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
        projection,
        null,
        null,
        sortOrder
    )?.use { cursor ->
        val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
        
        while (cursor.moveToNext() && images.size < 20) {
            val id = cursor.getLong(idColumn)
            val contentUri = ContentUris.withAppendedId(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                id
            )
            images.add(contentUri)
        }
    }
    
    images
}