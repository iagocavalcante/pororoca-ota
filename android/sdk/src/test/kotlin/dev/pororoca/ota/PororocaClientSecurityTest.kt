package dev.pororoca.ota

import org.junit.Assert.assertThrows
import org.junit.Test

class PororocaClientSecurityTest {
  @Test fun rejectsNonLoopbackHttpServer() {
    assertThrows(IllegalArgumentException::class.java) {
      PororocaClient(
        serverUrl = "http://ota.example",
        apiToken = "pororoca_live_test",
        app = "example-app",
        installId = "install-00000001",
        publicKey = ByteArray(32),
      )
    }
  }
}
