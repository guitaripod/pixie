package com.guitaripod.pixie.data.purchases

import android.app.Activity
import android.app.Application
import android.util.Log
import com.guitaripod.pixie.BuildConfig
import com.revenuecat.purchases.*
import com.revenuecat.purchases.interfaces.*
import com.revenuecat.purchases.models.*
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.*
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class RevenueCatManager @Inject constructor(
    private val application: Application
) {
    companion object {
        private const val TAG = "RevenueCatManager"
        // RevenueCat Public SDK Key - safe to hardcode
        private const val REVENUECAT_API_KEY = "goog_ekJVbyRpZsNCENTFOjDAzePvssD"
    }
    
    private val _purchaseState = MutableStateFlow<PurchaseState>(PurchaseState.Idle)
    val purchaseState: StateFlow<PurchaseState> = _purchaseState.asStateFlow()
    
    private val _offerings = MutableStateFlow<Offerings?>(null)
    val offerings: StateFlow<Offerings?> = _offerings.asStateFlow()
    
    init {
        setupRevenueCat()
    }
    
    private fun setupRevenueCat() {
        Purchases.debugLogsEnabled = BuildConfig.DEBUG
        
        Purchases.configure(
            PurchasesConfiguration.Builder(application, REVENUECAT_API_KEY)
                .observerMode(false)
                .build()
        )
        
        fetchOfferings()
    }
    
    fun setUserId(userId: String) {
        Purchases.sharedInstance.logIn(
            userId,
            object : LogInCallback {
                override fun onReceived(customerInfo: CustomerInfo, created: Boolean) {
                    Log.d(TAG, "User logged in: $userId, created: $created")
                }
                
                override fun onError(error: PurchasesError) {
                    Log.e(TAG, "Error logging in user: ${error.message}")
                }
            }
        )
    }
    
    fun fetchOfferings() {
        Purchases.sharedInstance.getOfferings(object : ReceiveOfferingsCallback {
            override fun onReceived(offerings: Offerings) {
                _offerings.value = offerings
                Log.d(TAG, "Offerings fetched: ${offerings.all.size} offerings")
            }
            
            override fun onError(error: PurchasesError) {
                Log.e(TAG, "Error fetching offerings: ${error.message}")
                _purchaseState.value = PurchaseState.Error(error.message)
            }
        })
    }
    
    fun purchaseCreditPack(
        activity: Activity,
        packageToPurchase: Package
    ) {
        _purchaseState.value = PurchaseState.Loading
        
        Purchases.sharedInstance.purchase(
            PurchaseParams.Builder(activity, packageToPurchase).build(),
            object : PurchaseCallback {
                override fun onCompleted(
                    storeTransaction: StoreTransaction,
                    customerInfo: CustomerInfo
                ) {
                    val purchaseToken = storeTransaction.purchaseToken
                    val productId = storeTransaction.productIds.firstOrNull() ?: ""
                    
                    _purchaseState.value = PurchaseState.Success(
                        purchaseToken = purchaseToken,
                        productId = productId,
                        packageId = packageToPurchase.identifier
                    )
                    
                    Log.d(TAG, "Purchase successful: $productId")
                }
                
                override fun onError(error: PurchasesError, userCancelled: Boolean) {
                    if (userCancelled) {
                        _purchaseState.value = PurchaseState.Cancelled
                        Log.d(TAG, "Purchase cancelled by user")
                    } else {
                        _purchaseState.value = PurchaseState.Error(error.message)
                        Log.e(TAG, "Purchase error: ${error.message}")
                    }
                }
            }
        )
    }
    
    fun restorePurchases(onComplete: (CustomerInfo?) -> Unit) {
        Purchases.sharedInstance.restorePurchases(object : ReceiveCustomerInfoCallback {
            override fun onReceived(customerInfo: CustomerInfo) {
                Log.d(TAG, "Restore successful")
                onComplete(customerInfo)
            }
            
            override fun onError(error: PurchasesError) {
                Log.e(TAG, "Restore error: ${error.message}")
                onComplete(null)
            }
        })
    }
    
    fun getCustomerInfo(): Flow<CustomerInfo?> = callbackFlow {
        Purchases.sharedInstance.getCustomerInfo(object : ReceiveCustomerInfoCallback {
            override fun onReceived(customerInfo: CustomerInfo) {
                trySend(customerInfo)
            }
            
            override fun onError(error: PurchasesError) {
                Log.e(TAG, "Error getting customer info: ${error.message}")
                trySend(null)
            }
        })
        
        val listener = UpdatedCustomerInfoListener { customerInfo ->
            trySend(customerInfo)
        }
        
        Purchases.sharedInstance.updatedCustomerInfoListener = listener
        
        awaitClose {
            Purchases.sharedInstance.updatedCustomerInfoListener = null
        }
    }
    
    fun resetPurchaseState() {
        _purchaseState.value = PurchaseState.Idle
    }
}

sealed class PurchaseState {
    object Idle : PurchaseState()
    object Loading : PurchaseState()
    data class Success(
        val purchaseToken: String,
        val productId: String,
        val packageId: String
    ) : PurchaseState()
    data class Error(val message: String) : PurchaseState()
    object Cancelled : PurchaseState()
}