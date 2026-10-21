package com.alburooj.app.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.Business
import androidx.compose.material.icons.filled.Explore
import androidx.compose.material.icons.automirrored.filled.Help
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.Policy
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Description
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.DrawerValue
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalDrawerSheet
import androidx.compose.material3.ModalNavigationDrawer
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationRail
import androidx.compose.material3.NavigationRailItem
import androidx.compose.material3.NavigationRailItemDefaults
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberDrawerState
import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.core.content.ContextCompat
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.alburooj.app.constants.AppConstants
import com.alburooj.app.managers.LocationManager
import com.alburooj.app.ui.screens.AdhanSoundSelectionScreen
import com.alburooj.app.ui.screens.DashboardHeader
import com.alburooj.app.ui.screens.DashboardScreen
import com.alburooj.app.ui.screens.EulaScreen
import com.alburooj.app.ui.screens.LegalDocument
import com.alburooj.app.ui.screens.LegalDocumentScreen
import com.alburooj.app.ui.screens.MasjidScreen
import com.alburooj.app.ui.screens.QiblaScreen
import com.alburooj.app.ui.screens.SettingsScreen
import com.alburooj.app.ui.theme.ThemeColor
import kotlinx.coroutines.launch

private class Tab(val route: String, val title: String, val icon: ImageVector)

private val Tabs = listOf(
    Tab("dashboard", "Dashboard", Icons.Filled.AccessTime),
    Tab("qibla", "Qibla", Icons.Filled.Explore),
    Tab("masjid", "Masjid", Icons.Filled.Business),
    Tab("settings", "Settings", Icons.Filled.Settings)
)

private val SubTitles = mapOf("adhanSound" to "Adhan Sound", "terms" to "Terms of Use", "privacy" to "Privacy Policy")

/** Mapped from ContentView.swift: five tabs under a maroon bar with a hamburger drawer. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainScreen(locationManager: LocationManager) {
    val navController = rememberNavController()
    val drawerState = rememberDrawerState(DrawerValue.Closed)
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    var header by remember { mutableStateOf(DashboardHeader("", "")) }

    // Location drives the locally calculated adhan times, so ask for it app-wide at launch.
    var hasLocation by remember {
        mutableStateOf(ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED)
    }
    val locationLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { hasLocation = it }
    LaunchedEffect(Unit) { if (!hasLocation) locationLauncher.launch(Manifest.permission.ACCESS_FINE_LOCATION) }
    DisposableEffect(hasLocation) {
        if (hasLocation) locationManager.start()
        onDispose { locationManager.stop() }
    }

    val backStack by navController.currentBackStackEntryAsState()
    val route = backStack?.destination?.route ?: "dashboard"
    val isSubScreen = route in SubTitles
    val config = LocalConfiguration.current
    val isWide = config.screenWidthDp >= 600
    // A rail needs height for its items; a phone held sideways keeps the bottom bar.
    val useRail = isWide && config.screenHeightDp >= 480
    val navigateToTab = { tabRoute: String ->
        navController.navigate(tabRoute) {
            popUpTo(navController.graph.findStartDestination().id) { saveState = true }
            launchSingleTop = true; restoreState = true
        }
    }

    val title = when {
        isSubScreen -> SubTitles.getValue(route)
        route == "dashboard" -> header.masjidName.ifEmpty { "Dashboard" }
        route == "masjid" -> "Masjid Info"
        else -> Tabs.first { it.route == route }.title
    }

    ModalNavigationDrawer(
        drawerState = drawerState,
        gesturesEnabled = !isSubScreen,
        drawerContent = {
            ModalDrawerSheet {
                DrawerContent(
                    onRate = { open(context, AppConstants.APP_URL) },
                    onShare = {
                        context.startActivity(
                            Intent.createChooser(
                                Intent(Intent.ACTION_SEND).setType("text/plain")
                                    .putExtra(Intent.EXTRA_TEXT, "Check out this amazing Prayer Times app!\n${AppConstants.APP_URL}"),
                                null
                            )
                        )
                    },
                    onHelp = { open(context, "https://x2softinc.com") },
                    onTerms = { navController.navigate("terms") },
                    onPrivacy = { navController.navigate("privacy") },
                    close = { scope.launch { drawerState.close() } }
                )
            }
        }
    ) {
        Scaffold(
            topBar = {
                CenterAlignedTopAppBar(
                    title = { Text(title) },
                    navigationIcon = {
                        if (isSubScreen) {
                            IconButton({ navController.popBackStack() }) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back") }
                        } else {
                            IconButton({ scope.launch { drawerState.open() } }) { Icon(Icons.Filled.Menu, "Menu") }
                        }
                    },
                    actions = {
                        if (route == "dashboard" && header.city.isNotEmpty()) {
                            Text(header.city, Modifier.padding(end = 12.dp), color = Color.White, fontWeight = FontWeight.Medium)
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = ThemeColor, titleContentColor = Color.White,
                        navigationIconContentColor = Color.White, actionIconContentColor = Color.White
                    )
                )
            },
            bottomBar = {
                if (!isSubScreen && !useRail) {
                    NavigationBar {
                        Tabs.forEach { tab ->
                            NavigationBarItem(
                                selected = route == tab.route,
                                onClick = { navigateToTab(tab.route) },
                                icon = { Icon(tab.icon, tab.title) },
                                label = { Text(tab.title) },
                                colors = NavigationBarItemDefaults.colors(selectedIconColor = Color.White, indicatorColor = ThemeColor)
                            )
                        }
                    }
                }
            }
        ) { padding ->
            Row(Modifier.padding(padding).fillMaxSize()) {
                if (useRail && !isSubScreen) {
                    NavigationRail {
                        Spacer(Modifier.weight(1f))
                        Tabs.forEach { tab ->
                            NavigationRailItem(
                                selected = route == tab.route,
                                onClick = { navigateToTab(tab.route) },
                                icon = { Icon(tab.icon, tab.title) },
                                label = { Text(tab.title) },
                                colors = NavigationRailItemDefaults.colors(selectedIconColor = Color.White, indicatorColor = ThemeColor)
                            )
                        }
                        Spacer(Modifier.weight(1f))
                    }
                }
                // On wide screens, keep content readable: the dashboard, masjid info and the hosted privacy page use the whole screen, the rest is centred and capped.
                Box(Modifier.weight(1f).fillMaxHeight(), contentAlignment = Alignment.TopCenter) {
                    val capped = if (isWide && route != "dashboard" && route != "masjid" && route != "privacy") Modifier.widthIn(max = 840.dp) else Modifier
                    NavHost(navController, startDestination = "dashboard", modifier = capped.fillMaxSize()) {
                        composable("dashboard") { DashboardScreen(locationManager = locationManager, onHeader = { header = it }) }
                        composable("qibla") { QiblaScreen(locationManager) }
                        composable("masjid") { MasjidScreen() }
                        composable("settings") {
                            SettingsScreen(
                                onAdhanSound = { navController.navigate("adhanSound") },
                                onTerms = { navController.navigate("terms") },
                                onPrivacy = { navController.navigate("privacy") }
                            )
                        }
                        composable("adhanSound") { AdhanSoundSelectionScreen() }
                        composable("terms") { EulaScreen() }
                        composable("privacy") { LegalDocumentScreen(LegalDocument.PrivacyPolicy) }
                    }
                }
            }
        }
    }
}

private fun open(context: android.content.Context, url: String) {
    context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
}

@Composable
private fun DrawerContent(
    onRate: () -> Unit, onShare: () -> Unit, onHelp: () -> Unit,
    onTerms: () -> Unit, onPrivacy: () -> Unit, close: () -> Unit
) {
    val context = LocalContext.current
    val version = remember { context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: "1.0" }
    Column(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxWidth().background10().padding(20.dp)) {
            Text("Prayer Times", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            Text("Islamic App", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        HorizontalDivider()
        DrawerItem(Icons.Filled.Star, "Rate the App") { close(); onRate() }
        DrawerItem(Icons.Filled.Share, "Share App") { close(); onShare() }
        DrawerItem(Icons.AutoMirrored.Filled.Help, "Help & Support") { close(); onHelp() }
        HorizontalDivider(Modifier.padding(vertical = 8.dp))
        DrawerItem(Icons.Filled.Description, "Terms of Use") { close(); onTerms() }
        DrawerItem(Icons.Filled.Policy, "Privacy Policy") { close(); onPrivacy() }
        Spacer(Modifier.weight(1f))
        Text("Version $version", Modifier.fillMaxWidth().padding(bottom = 20.dp), style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
    }
}

private fun Modifier.background10() = this.then(Modifier.background(ThemeColor.copy(alpha = 0.1f)))

@Composable
private fun DrawerItem(icon: ImageVector, label: String, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().clickable(onClick = onClick).padding(horizontal = 20.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, tint = ThemeColor)
        Text(label, Modifier.padding(start = 16.dp), style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Medium)
    }
}
