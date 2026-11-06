package com.guitaripod.pixie.data.repository

import com.guitaripod.pixie.data.model.AuthResult
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.toList
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

class SignInHookTest {
    @Test
    fun theHookRunsForEachSuccessAndEveryResultPassesThrough() = runTest {
        var started = 0
        val success = AuthResult.Success(apiKey = "key", userId = "user", provider = "google")
        val results = flowOf(AuthResult.Pending, success, AuthResult.Error("x"), AuthResult.Cancelled)
            .onSignedIn { started++ }
            .toList()
        assertEquals(listOf(AuthResult.Pending, success, AuthResult.Error("x"), AuthResult.Cancelled), results)
        assertEquals(1, started)
    }

    @Test
    fun aFailedSignInStartsNothing() = runTest {
        var started = 0
        flowOf(AuthResult.Pending, AuthResult.Error("denied")).onSignedIn { started++ }.toList()
        assertEquals(0, started)
    }
}
