package com.rayy.app

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

/** Error answer of the API: code 401 = not signed in / session expired. */
class ApiException(val code: Int, message: String) : Exception(message)

/**
 * Talks to the PHP API (server/rayy/api) with plain HTTP + JSON.
 * Uses only classes built into Android (HttpURLConnection, org.json): no extra library.
 */
class ApiClient(var token: String?) {

    /** GET (body = null) or POST a JSON body. Runs on a background thread. */
    suspend fun call(path: String, body: JSONObject? = null): JSONObject = withContext(Dispatchers.IO) {
        val conn = URL("$SERVER_URL/$path").openConnection() as HttpURLConnection
        try {
            conn.connectTimeout = 5000
            conn.readTimeout = 8000
            conn.setRequestProperty("Content-Type", "application/json")
            token?.let { conn.setRequestProperty("X-Auth-Token", it) }
            if (body != null) {
                conn.requestMethod = "POST"
                conn.doOutput = true
                conn.outputStream.use { it.write(body.toString().toByteArray()) }
            }
            val code = conn.responseCode
            val text = (if (code in 200..299) conn.inputStream else conn.errorStream)
                ?.bufferedReader()?.use { it.readText() } ?: ""
            val json = runCatching { JSONObject(text) }.getOrElse { JSONObject() }
            if (code !in 200..299 || !json.optBoolean("ok")) {
                throw ApiException(code, json.optString("error").ifEmpty { "HTTP $code" })
            }
            json
        } finally {
            conn.disconnect()
        }
    }
}
