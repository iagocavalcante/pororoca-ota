package dev.pororoca.ota

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class PororocaDocumentTest {
  @Test fun decodesStrictAndroidDocument() {
    val document = PororocaDocument.decode("""{"format":1,"screen":"welcome","platform":"android","requires":{"runtime":"1"},"root":{"t":"text","p":{"value":"Olá"}}}""".encodeToByteArray())
    assertEquals("welcome", document.screen)
  }

  @Test fun rejectsUnknownNode() {
    assertThrows(IllegalArgumentException::class.java) {
      PororocaDocument.decode("""{"format":1,"screen":"welcome","platform":"android","requires":{"runtime":"1"},"root":{"t":"webview"}}""".encodeToByteArray())
    }
  }
}
