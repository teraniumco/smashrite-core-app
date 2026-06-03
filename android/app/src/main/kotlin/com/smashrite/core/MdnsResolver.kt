// android/app/src/main/kotlin/com/smashrite/core/MdnsResolver.kt
package com.smashrite.core

import android.net.wifi.WifiManager
import android.content.Context
import android.util.Log
import java.net.*

object MdnsResolver {
    private const val TAG = "SmashriteMDNS"
    private const val MDNS_ADDR = "224.0.0.251"
    private const val MDNS_PORT = 5353
    private const val TIMEOUT_MS = 3000

    private var multicastLock: WifiManager.MulticastLock? = null

    fun acquireMulticastLock(context: Context) {
        if (multicastLock?.isHeld == true) return
        val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        multicastLock = wifi.createMulticastLock("smashrite_mdns").apply {
            setReferenceCounted(true)
            acquire()
        }
        Log.d(TAG, "✅ Multicast lock acquired")
    }

    fun releaseMulticastLock() {
        if (multicastLock?.isHeld == true) {
            multicastLock?.release()
            Log.d(TAG, "🔓 Multicast lock released")
        }
    }

    fun resolve(hostname: String): String? {
        // Normalise: ensure single trailing dot for mDNS FQDN
        val fqdn = if (hostname.endsWith(".")) hostname else "$hostname."
        Log.d(TAG, "🔍 Resolving: $fqdn")

        val query = buildQuery(fqdn)
        var socket: MulticastSocket? = null

        return try {
            socket = MulticastSocket(null).apply {
                reuseAddress = true
                soTimeout = TIMEOUT_MS
                bind(InetSocketAddress(0)) // ephemeral port for sending
            }

            val group = InetAddress.getByName(MDNS_ADDR)
            socket.joinGroup(group)

            // Send query
            val sendPacket = DatagramPacket(
                query, query.size,
                InetSocketAddress(MDNS_ADDR, MDNS_PORT)
            )
            socket.send(sendPacket)
            Log.d(TAG, "📤 mDNS query sent for $fqdn")

            // Listen for responses until timeout
            val buf = ByteArray(1024)
            val recvPacket = DatagramPacket(buf, buf.size)
            val deadline = System.currentTimeMillis() + TIMEOUT_MS

            while (System.currentTimeMillis() < deadline) {
                try {
                    socket.receive(recvPacket)
                    val ip = parseARecord(buf, recvPacket.length, fqdn)
                    if (ip != null) {
                        Log.d(TAG, "✅ Resolved $hostname → $ip")
                        return ip
                    }
                } catch (e: SocketTimeoutException) {
                    break
                }
            }

            Log.w(TAG, "⚠️ No A record found for $hostname within ${TIMEOUT_MS}ms")
            null
        } catch (e: Exception) {
            Log.e(TAG, "❌ mDNS resolution error for $hostname: ${e.message}", e)
            null
        } finally {
            try { socket?.leaveGroup(InetAddress.getByName(MDNS_ADDR)) } catch (_: Exception) {}
            socket?.close()
        }
    }

    // ── DNS message builder ──────────────────────────────────────────────────

    private fun buildQuery(fqdn: String): ByteArray {
        val buf = mutableListOf<Byte>()

        // Header: ID=0 (mDNS standard), QR=0 (query), Opcode=0, AA=0, TC=0, RD=0
        // Flags=0x0000, QDCount=1, ANCount=0, NSCount=0, ARCount=0
        buf.addAll(byteArrayOf(0,0, 0,0, 0,1, 0,0, 0,0, 0,0).toList())

        // QNAME: each label prefixed with its length, terminated by 0x00
        fqdn.split(".").filter { it.isNotEmpty() }.forEach { label ->
            buf.add(label.length.toByte())
            label.toByteArray(Charsets.US_ASCII).forEach { buf.add(it) }
        }
        buf.add(0x00) // root label

        // QTYPE=A (0x0001), QCLASS=IN with QU bit set (0x8001) for one-shot query
        buf.addAll(byteArrayOf(0x00, 0x01, 0x80.toByte(), 0x01).toList())

        return buf.toByteArray()
    }

    // ── DNS response parser ──────────────────────────────────────────────────

    private fun parseARecord(buf: ByteArray, len: Int, queriedFqdn: String): String? {
        if (len < 12) return null

        val qdCount = ((buf[4].toInt() and 0xFF) shl 8) or (buf[5].toInt() and 0xFF)
        val anCount = ((buf[6].toInt() and 0xFF) shl 8) or (buf[7].toInt() and 0xFF)

        if (anCount == 0) return null

        var offset = 12

        // Skip question section
        repeat(qdCount) {
            offset = skipName(buf, offset, len)
            offset += 4 // QTYPE + QCLASS
        }

        // Parse answer section
        repeat(anCount) {
            if (offset >= len) return null
            offset = skipName(buf, offset, len) // NAME (may be pointer)

            if (offset + 10 > len) return null
            val type  = ((buf[offset].toInt()   and 0xFF) shl 8) or (buf[offset+1].toInt() and 0xFF)
            // class at offset+2..3, ttl at offset+4..7
            val rdLen = ((buf[offset+8].toInt() and 0xFF) shl 8) or (buf[offset+9].toInt() and 0xFF)
            offset += 10

            if (type == 1 && rdLen == 4 && offset + 4 <= len) {
                // A record — extract IPv4
                return "${buf[offset].toInt() and 0xFF}.${buf[offset+1].toInt() and 0xFF}" +
                       ".${buf[offset+2].toInt() and 0xFF}.${buf[offset+3].toInt() and 0xFF}"
            }
            offset += rdLen
        }
        return null
    }

    /** Advances past a DNS name (handles pointer compression). Returns new offset. */
    private fun skipName(buf: ByteArray, startOffset: Int, len: Int): Int {
        var i = startOffset
        while (i < len) {
            val labelLen = buf[i].toInt() and 0xFF
            when {
                labelLen == 0    -> return i + 1           // root label
                labelLen and 0xC0 == 0xC0 -> return i + 2 // compressed pointer (2 bytes)
                else             -> i += labelLen + 1
            }
        }
        return i
    }
}