package com.guitaripod.pixie.data.purchases

import android.app.Activity
import android.util.Log
import com.guitaripod.pixie.data.api.PixieApiService
import com.guitaripod.pixie.data.api.model.*
import com.guitaripod.pixie.data.repository.CreditsRepository
import com.revenuecat.purchases.Package
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Singleton
import java.util.Date

@Singleton
class CreditPurchaseManager @Inject constructor(
    private val revenueCatManager: RevenueCatManager,
    private val apiService: PixieApiService,
    private val creditsRepository: CreditsRepository
) {
    companion object {
        private const val TAG = "CreditPurchaseManager"
        
        private val PACKAGE_TO_PACK_ID = mapOf(
            "starter" to "starter",
            "basic" to "basic",
            "popular" to "popular",
            "business" to "business",
            "enterprise" to "enterprise"
        )
    }
    
    val purchaseState = revenueCatManager.purchaseState
    val offerings = revenueCatManager.offerings
    
    suspend fun purchaseCreditPack(
        activity: Activity,
        packageToPurchase: Package
    ): Result<CreditPurchaseResult> {
        revenueCatManager.purchaseCreditPack(activity, packageToPurchase)
        
        return purchaseState.filterNotNull()
            .filter { it !is PurchaseState.Loading }
            .take(1)
            .map { state ->
                when (state) {
                    is PurchaseState.Success -> {
                        val packId = PACKAGE_TO_PACK_ID[state.packageId] ?: state.packageId
                        validateAndRecordPurchase(
                            packId = packId,
                            purchaseToken = state.purchaseToken,
                            productId = state.productId
                        )
                    }
                    is PurchaseState.Error -> {
                        Result.failure(Exception(state.message))
                    }
                    is PurchaseState.Cancelled -> {
                        Result.failure(PurchaseCancelledException())
                    }
                    else -> {
                        Result.failure(Exception("Unexpected purchase state"))
                    }
                }
            }
            .first()
    }
    
    private suspend fun validateAndRecordPurchase(
        packId: String,
        purchaseToken: String,
        productId: String
    ): Result<CreditPurchaseResult> {
        return try {
            val request = RevenueCatPurchaseValidationRequest(
                packId = packId,
                purchaseToken = purchaseToken,
                productId = productId,
                platform = "android"
            )
            
            val response = apiService.validateRevenueCatPurchase(request)
            
            if (response.isSuccessful) {
                response.body()?.let { validationResponse ->
                    if (validationResponse.success) {
                        
                        Result.success(
                            CreditPurchaseResult(
                                purchaseId = validationResponse.purchaseId,
                                credits = validationResponse.creditsAdded,
                                newBalance = validationResponse.newBalance,
                                amountUsd = ""
                            )
                        )
                    } else {
                        Result.failure(Exception("Purchase validation failed"))
                    }
                } ?: Result.failure(Exception("Empty response from server"))
            } else {
                val errorBody = response.errorBody()?.string()
                Log.e(TAG, "Purchase validation failed: $errorBody")
                Result.failure(Exception("Purchase validation failed: ${response.code()}"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error recording purchase", e)
            Result.failure(e)
        }
    }
    
    suspend fun restorePurchases(): Result<List<RestoredPurchase>> {
        return try {
            val restoredPurchases = mutableListOf<RestoredPurchase>()
            
            revenueCatManager.restorePurchases { customerInfo ->
                customerInfo?.let { info ->
                    info.entitlements.all.forEach { (_, entitlement) ->
                        if (entitlement.isActive) {
                            val productId = entitlement.productIdentifier
                            restoredPurchases.add(
                                RestoredPurchase(
                                    productId = productId,
                                    purchaseDate = entitlement.latestPurchaseDate.toString(),
                                    expirationDate = entitlement.expirationDate?.toString()
                                )
                            )
                        }
                    }
                }
            }
            
            if (restoredPurchases.isNotEmpty()) {
            }
            
            Result.success(restoredPurchases)
        } catch (e: Exception) {
            Log.e(TAG, "Error restoring purchases", e)
            Result.failure(e)
        }
    }
    
    // Backend credit packs - single source of truth
    private val _backendCreditPacks = MutableStateFlow<List<CreditPack>>(emptyList())
    
    init {
        // Fetch credit packs from backend on initialization
        fetchBackendCreditPacks()
    }
    
    private fun fetchBackendCreditPacks() {
        // Launch in a coroutine scope
        kotlinx.coroutines.GlobalScope.launch {
            try {
                val response = apiService.getCreditPacks()
                if (response.isSuccessful) {
                    response.body()?.let { packsResponse ->
                        _backendCreditPacks.value = packsResponse.packs
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error fetching backend credit packs", e)
            }
        }
    }
    
    fun getCreditPacksWithPricing(): Flow<List<CreditPackWithPrice>> {
        // Combine backend credit packs with RevenueCat offerings
        // Backend is the single source of truth
        return combine(
            _backendCreditPacks,
            offerings
        ) { backendPacks, revenueCatOfferings ->
            // If backend data is not available, return empty list
            if (backendPacks.isEmpty()) {
                return@combine emptyList<CreditPackWithPrice>()
            }
            
            val defaultOffering = revenueCatOfferings?.current ?: revenueCatOfferings?.all?.values?.firstOrNull()
            val packages = defaultOffering?.availablePackages ?: emptyList()
            
            // Map backend packs to RevenueCat packages
            backendPacks.mapNotNull { pack ->
                // Find matching RevenueCat package
                packages.firstOrNull { it.identifier == pack.id }?.let { rcPackage ->
                    CreditPackWithPrice(
                        creditPack = CreditPack(
                            id = pack.id,
                            name = pack.name,  // Use backend name
                            credits = pack.credits,  // Use backend credits
                            bonusCredits = pack.bonusCredits,  // Use backend bonus
                            priceUsdCents = pack.priceUsdCents,  // Use backend price
                            description = pack.description,  // Use backend description
                            popular = pack.id == "popular"
                        ),
                        rcPackage = rcPackage,
                        localizedPrice = rcPackage.product.price.formatted
                    )
                }
            }.sortedBy { it.creditPack.priceUsdCents }
        }
    }
    
    fun resetPurchaseState() {
        revenueCatManager.resetPurchaseState()
    }
}

data class CreditPurchaseResult(
    val purchaseId: String,
    val credits: Int,
    val newBalance: Int,
    val amountUsd: String
)

data class RestoredPurchase(
    val productId: String,
    val purchaseDate: String,
    val expirationDate: String?
)

data class CreditPackWithPrice(
    val creditPack: CreditPack,
    val rcPackage: Package,
    val localizedPrice: String
)

class PurchaseCancelledException : Exception("Purchase cancelled by user")

data class CreditPurchaseRequest(
    val packId: String,
    val paymentProvider: String,
    val paymentId: String,
    val productId: String
)

data class CreditPurchaseResponse(
    val purchaseId: String,
    val credits: Int,
    val newBalance: Int,
    val amountUsd: String,
    val status: String
)

data class RevenueCatPurchaseValidationRequest(
    val packId: String,
    val purchaseToken: String,
    val productId: String,
    val platform: String
)

data class RevenueCatPurchaseValidationResponse(
    val success: Boolean,
    val purchaseId: String,
    val creditsAdded: Int,
    val newBalance: Int
)