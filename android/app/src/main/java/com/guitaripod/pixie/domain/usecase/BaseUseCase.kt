package com.guitaripod.pixie.domain.usecase

import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

abstract class BaseUseCase<in P, R> {
    
    protected open val dispatcher: CoroutineDispatcher = Dispatchers.IO
    
    suspend operator fun invoke(params: P): Result<R> = withContext(dispatcher) {
        try {
            Result.success(execute(params))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    protected abstract suspend fun execute(params: P): R
}

// For use cases without parameters
abstract class NoParamsUseCase<R> : BaseUseCase<Unit, R>() {
    suspend operator fun invoke(): Result<R> = invoke(Unit)
}