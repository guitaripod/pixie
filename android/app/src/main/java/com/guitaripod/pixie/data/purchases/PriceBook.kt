package com.guitaripod.pixie.data.purchases

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * The Play prices the credit packs screen shows, by pack id. Loads run one at a time, each applied after the one
 * started before it, so a slow load that started first can never put back prices a later load replaced.
 */
class PriceBook {
    private val loading = Mutex()
    private val shown = MutableStateFlow<Map<String, StoreProduct>>(emptyMap())

    val prices: StateFlow<Map<String, StoreProduct>> = shown.asStateFlow()

    /** Runs one load and applies its prices (`pricesAfter`): an empty load keeps what is shown. */
    suspend fun load(fetch: suspend () -> Map<String, StoreProduct>) {
        loading.withLock {
            val loaded = fetch()
            shown.value = pricesAfter(shown.value, loaded)
        }
    }
}
