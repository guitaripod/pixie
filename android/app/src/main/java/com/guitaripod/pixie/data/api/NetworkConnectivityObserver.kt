package com.guitaripod.pixie.data.api

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.distinctUntilChanged

/**
 * Observes network connectivity status and provides it as a Flow
 */
class NetworkConnectivityObserver(
    private val context: Context
) {
    private val connectivityManager = 
        context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    
    /**
     * Flow that emits network connectivity status
     */
    fun observe(): Flow<ConnectivityStatus> = callbackFlow {
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                super.onAvailable(network)
                trySend(ConnectivityStatus.Available)
            }
            
            override fun onLosing(network: Network, maxMsToLive: Int) {
                super.onLosing(network, maxMsToLive)
                trySend(ConnectivityStatus.Losing)
            }
            
            override fun onLost(network: Network) {
                super.onLost(network)
                trySend(ConnectivityStatus.Lost)
            }
            
            override fun onUnavailable() {
                super.onUnavailable()
                trySend(ConnectivityStatus.Unavailable)
            }
            
            override fun onCapabilitiesChanged(
                network: Network,
                networkCapabilities: NetworkCapabilities
            ) {
                super.onCapabilitiesChanged(network, networkCapabilities)
                val status = when {
                    networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) ->
                        ConnectivityStatus.Available
                    else -> ConnectivityStatus.Unavailable
                }
                trySend(status)
            }
        }
        
        val request = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()
            
        trySend(getCurrentConnectivityStatus())
        
        connectivityManager.registerNetworkCallback(request, callback)
        
        awaitClose {
            connectivityManager.unregisterNetworkCallback(callback)
        }
    }.distinctUntilChanged()
    
    /**
     * Get current connectivity status
     */
    fun getCurrentConnectivityStatus(): ConnectivityStatus {
        val network = connectivityManager.activeNetwork
        val capabilities = connectivityManager.getNetworkCapabilities(network)
        
        return when {
            capabilities == null -> ConnectivityStatus.Unavailable
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) -> 
                ConnectivityStatus.Available
            else -> ConnectivityStatus.Unavailable
        }
    }
    
    /**
     * Check if currently connected to internet
     */
    fun isConnected(): Boolean {
        return getCurrentConnectivityStatus() == ConnectivityStatus.Available
    }
}

/**
 * Network connectivity status
 */
sealed class ConnectivityStatus {
    object Available : ConnectivityStatus()
    object Unavailable : ConnectivityStatus()
    object Losing : ConnectivityStatus()
    object Lost : ConnectivityStatus()
}

/**
 * Extension functions for ConnectivityStatus
 */
fun ConnectivityStatus.isConnected(): Boolean {
    return this is ConnectivityStatus.Available
}

fun ConnectivityStatus.isDisconnected(): Boolean {
    return this is ConnectivityStatus.Unavailable || this is ConnectivityStatus.Lost
}