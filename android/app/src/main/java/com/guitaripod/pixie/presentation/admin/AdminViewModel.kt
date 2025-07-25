package com.guitaripod.pixie.presentation.admin

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.guitaripod.pixie.data.api.model.*
import com.guitaripod.pixie.data.repository.AdminRepository
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

data class AdminUiState(
    val isLoading: Boolean = false,
    val error: String? = null
)

class AdminViewModel(
    private val adminRepository: AdminRepository
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(AdminUiState())
    val uiState: StateFlow<AdminUiState> = _uiState.asStateFlow()
    
    init {
        checkAdminStatus()
    }
    
    private fun checkAdminStatus() {
        viewModelScope.launch {
            val isAdmin = adminRepository.checkAdminStatus()
            if (!isAdmin) {
                _uiState.update { it.copy(error = "You do not have admin privileges") }
            }
        }
    }
}