package com.guitaripod.pixie.presentation.admin

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.guitaripod.pixie.data.api.model.*
import com.guitaripod.pixie.data.repository.AdminRepository
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

data class AdminCreditAdjustmentUiState(
    val currentStep: CreditAdjustmentStep = CreditAdjustmentStep.USER_SEARCH,
    val searchQuery: String = "",
    val searchResults: List<UserSearchResult> = emptyList(),
    val selectedUser: UserSearchResult? = null,
    val adjustmentAmount: String = "",
    val adjustmentReason: String = "",
    val isLoading: Boolean = false,
    val error: String? = null,
    val showConfirmationDialog: Boolean = false,
    val adjustmentSuccess: String? = null
)

class AdminCreditAdjustmentViewModel(
    private val adminRepository: AdminRepository
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(AdminCreditAdjustmentUiState())
    val uiState: StateFlow<AdminCreditAdjustmentUiState> = _uiState.asStateFlow()
    
    fun updateSearchQuery(query: String) {
        _uiState.update { it.copy(searchQuery = query) }
    }
    
    fun searchUsers() {
        if (_uiState.value.searchQuery.isBlank()) return
        
        viewModelScope.launch {
            adminRepository.searchUsers(search = _uiState.value.searchQuery).collect { result ->
                when (result) {
                    is NetworkResult.Loading -> {
                        _uiState.update { it.copy(isLoading = true, error = null) }
                    }
                    is NetworkResult.Success -> {
                        _uiState.update { 
                            it.copy(
                                isLoading = false,
                                searchResults = result.data,
                                error = if (result.data.isNullOrEmpty()) "No users found" else null
                            )
                        }
                    }
                    is NetworkResult.Error -> {
                        _uiState.update { 
                            it.copy(
                                isLoading = false,
                                error = result.exception.message ?: "Failed to search users"
                            )
                        }
                    }
                }
            }
        }
    }
    
    fun selectUser(user: UserSearchResult) {
        _uiState.update { 
            it.copy(
                selectedUser = user,
                currentStep = CreditAdjustmentStep.ADJUSTMENT_FORM,
                error = null
            )
        }
    }
    
    fun updateAdjustmentAmount(amount: String) {
        val filtered = amount.filter { it.isDigit() || (it == '-' && amount.indexOf('-') == 0) }
        _uiState.update { it.copy(adjustmentAmount = filtered) }
    }
    
    fun updateAdjustmentReason(reason: String) {
        _uiState.update { it.copy(adjustmentReason = reason) }
    }
    
    fun cancelAdjustment() {
        _uiState.update { 
            it.copy(
                currentStep = CreditAdjustmentStep.USER_SEARCH,
                selectedUser = null,
                adjustmentAmount = "",
                adjustmentReason = "",
                error = null
            )
        }
    }
    
    fun showConfirmationDialog() {
        _uiState.update { it.copy(showConfirmationDialog = true) }
    }
    
    fun hideConfirmationDialog() {
        _uiState.update { it.copy(showConfirmationDialog = false) }
    }
    
    suspend fun submitAdjustment() {
        val user = _uiState.value.selectedUser ?: return
        val amount = _uiState.value.adjustmentAmount.toIntOrNull() ?: return
        val reason = _uiState.value.adjustmentReason
        
        if (reason.isBlank()) return
        
        _uiState.update { it.copy(showConfirmationDialog = false) }
        
        viewModelScope.launch {
            adminRepository.adjustUserCredits(
                AdminCreditAdjustmentRequest(
                    userId = user.id,
                    amount = amount,
                    reason = reason
                )
            ).collect { result ->
                when (result) {
                    is NetworkResult.Loading -> {
                        _uiState.update { it.copy(isLoading = true, error = null) }
                    }
                    is NetworkResult.Success -> {
                        val newBalance = result.data.newBalance
                        _uiState.update { 
                            it.copy(
                                isLoading = false,
                                adjustmentSuccess = "Successfully adjusted credits. New balance: $newBalance credits"
                            )
                        }
                    }
                    is NetworkResult.Error -> {
                        _uiState.update { 
                            it.copy(
                                isLoading = false,
                                error = result.exception.message ?: "Failed to adjust credits"
                            )
                        }
                    }
                }
            }
        }
    }
    
    fun resetForm() {
        _uiState.update { 
            AdminCreditAdjustmentUiState()
        }
    }
}