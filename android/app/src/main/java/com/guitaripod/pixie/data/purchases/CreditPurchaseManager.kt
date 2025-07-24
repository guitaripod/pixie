package com.guitaripod.pixie.data.purchases

import android.app.Activity
import android.util.Log
import com.guitaripod.pixie.data.api.PixieApiService
import com.guitaripod.pixie.data.api.model.*
import com.guitaripod.pixie.data.repository.CreditsRepository
import com.revenuecat.purchases.Package
import kotlinx.coroutines.flow.*
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
            val request = GooglePlayPurchaseValidationRequest(
                packId = packId,
                purchaseToken = purchaseToken,
                productId = productId
            )
            
            val response = apiService.validateGooglePlayPurchase(request)
            
            if (response.isSuccessful) {
                response.body()?.let { validationResponse ->
                    if (validationResponse.success) {
                        // Refresh balance will be handled by the UI layer
                        
                        Result.success(
                            CreditPurchaseResult(
                                purchaseId = validationResponse.purchaseId,
                                credits = validationResponse.creditsAdded,
                                newBalance = validationResponse.newBalance,
                                amountUsd = "$%.2f".format(validationResponse.creditsAdded * 0.01)
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
                                    purchaseDate = entitlement.latestPurchaseDate?.toString() ?: "",
                                    expirationDate = entitlement.expirationDate?.toString()
                                )
                            )
                        }
                    }
                }
            }
            
            if (restoredPurchases.isNotEmpty()) {
                // Balance refresh handled by UI
            }
            
            Result.success(restoredPurchases)
        } catch (e: Exception) {
            Log.e(TAG, "Error restoring purchases", e)
            Result.failure(e)
        }
    }
    
    fun getCreditPacksWithPricing(): Flow<List<CreditPackWithPrice>> {
        return offerings.map { revenueCatOfferings ->
            val defaultOffering = revenueCatOfferings?.current ?: revenueCatOfferings?.all?.values?.firstOrNull()
            
            defaultOffering?.availablePackages?.mapNotNull { rcPackage ->
                // Map RevenueCat package to our credit pack structure
                val packId = rcPackage.identifier
                val credits = when (packId) {
                    "starter" -> 299
                    "basic" -> 1250
                    "popular" -> 3250
                    "business" -> 6800
                    "enterprise" -> 15000
                    else -> null
                }
                
                credits?.let {
                    val (baseCredits, bonusCredits) = when (packId) {
                        "starter" -> 299 to 0
                        "basic" -> 1000 to 250
                        "popular" -> 2500 to 750
                        "business" -> 5000 to 1800
                        "enterprise" -> 10000 to 5000
                        else -> it to 0
                    }
                    
                    CreditPackWithPrice(
                        creditPack = CreditPack(
                            id = packId,
                            name = rcPackage.product.title,
                            credits = baseCredits,
                            bonusCredits = bonusCredits,
                            priceUsdCents = (rcPackage.product.price.amountMicros / 10000).toInt(),
                            description = rcPackage.product.description,
                            popular = packId == "popular"
                        ),
                        rcPackage = rcPackage,
                        localizedPrice = rcPackage.product.price.formatted
                    )
                }
            } ?: emptyList()
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

data class GooglePlayPurchaseValidationRequest(
    val packId: String,
    val purchaseToken: String,
    val productId: String
)

data class GooglePlayPurchaseValidationResponse(
    val success: Boolean,
    val purchaseId: String,
    val creditsAdded: Int,
    val newBalance: Int
)