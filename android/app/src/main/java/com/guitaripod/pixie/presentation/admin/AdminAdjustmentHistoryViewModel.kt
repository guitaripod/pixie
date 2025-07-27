package com.guitaripod.pixie.presentation.admin

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.guitaripod.pixie.data.api.model.*
import com.guitaripod.pixie.data.repository.AdminRepository
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

data class AdminAdjustmentHistoryUiState(
    val adjustments: List<AdjustmentHistoryItem> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null
)

class AdminAdjustmentHistoryViewModel(
    private val adminRepository: AdminRepository
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(AdminAdjustmentHistoryUiState())
    val uiState: StateFlow<AdminAdjustmentHistoryUiState> = _uiState.asStateFlow()
    
    private var searchJob: Job? = null
    
    init {
        loadAllHistory()
    }
    
    fun loadAllHistory() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            
            _uiState.update { 
                it.copy(
                    isLoading = false,
                    adjustments = emptyList(),
                    error = "Adjustment history for all users is not yet available"
                )
            }
        }
    }
    
    fun searchHistory(userId: String) {
        searchJob?.cancel()
        
        if (userId.isBlank()) {
            loadAllHistory()
            return
        }
        
        searchJob = viewModelScope.launch {
            delay(500) // Debounce search
            
            adminRepository.getAdjustmentHistory(userId).collect { result ->
                when (result) {
                    is NetworkResult.Loading -> {
                        _uiState.update { it.copy(isLoading = true, error = null) }
                    }
                    is NetworkResult.Success -> {
                        _uiState.update { 
                            it.copy(
                                isLoading = false,
                                adjustments = result.data.adjustments,
                                error = null
                            )
                        }
                    }
                    is NetworkResult.Error -> {
                        _uiState.update { 
                            it.copy(
                                isLoading = false,
                                error = result.exception.message ?: "Failed to load adjustment history"
                            )
                        }
                    }
                }
            }
        }
    }
}