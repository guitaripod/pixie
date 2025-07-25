package com.guitaripod.pixie.presentation.admin

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.guitaripod.pixie.data.api.model.NetworkResult
import com.guitaripod.pixie.data.api.model.SystemStatsResponse
import com.guitaripod.pixie.data.repository.AdminRepository
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

data class AdminStatsUiState(
    val isLoading: Boolean = false,
    val stats: SystemStatsResponse? = null,
    val error: String? = null
)

class AdminStatsViewModel(
    private val adminRepository: AdminRepository
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(AdminStatsUiState())
    val uiState: StateFlow<AdminStatsUiState> = _uiState.asStateFlow()
    
    fun loadStats() {
        viewModelScope.launch {
            adminRepository.getSystemStats().collect { result ->
                when (result) {
                    is NetworkResult.Loading -> {
                        _uiState.update { it.copy(isLoading = true, error = null) }
                    }
                    is NetworkResult.Success -> {
                        _uiState.update { 
                            it.copy(
                                isLoading = false, 
                                stats = result.data,
                                error = null
                            )
                        }
                    }
                    is NetworkResult.Error -> {
                        _uiState.update { 
                            it.copy(
                                isLoading = false, 
                                error = result.exception.message ?: "Failed to load statistics"
                            )
                        }
                    }
                }
            }
        }
    }
}