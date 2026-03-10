package ringsystem;

import java.util.EnumMap;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.atomic.AtomicInteger;

public class Coordinator {
    private final int n;
    private final int h;
    private final Map<RingType, RingManager> rings = new EnumMap<>(RingType.class);
    private final Map<RingType, Thread> ringThreads = new EnumMap<>(RingType.class);
    private final AtomicInteger pendingCount = new AtomicInteger(0);
    private final AtomicInteger tokenCounter = new AtomicInteger(0);
    private final CountDownLatch doneLatch = new CountDownLatch(1);
    private final PerfTracker perfTracker = new PerfTracker();
    private volatile boolean doneReading = false;

    public Coordinator(int n, int h) {
        this.n = n;
        this.h = h;
    }

    public void start() {
        for (RingType type : RingType.values()) {
            RingManager manager = new RingManager(type, n, this);
            rings.put(type, manager);
            Thread t = new Thread(manager, type + "-manager");
            t.start();
            ringThreads.put(type, t);
        }
    }

    public void submitInput(long value) {
        RingType type = RingType.classify(value);
        int id = tokenCounter.incrementAndGet();
        Token token = new Token(id, type, value, h);
        pendingCount.incrementAndGet();
        rings.get(type).enqueue(token);
    }

    public void onResult(Token token) {
        long elapsedNanos = System.nanoTime() - token.startTimeNanos;
        long elapsedUs = elapsedNanos / 1000;
        perfTracker.recordLatency(elapsedUs);

        System.out.printf("Token #%d: input=%d, ring=%s, result=%d, hops=%d, latency=%dus%n",
                token.tokenId, token.origInput, token.ringId, token.currentVal, h, elapsedUs);

        if (pendingCount.decrementAndGet() == 0 && doneReading) {
            shutdownAll();
        }
    }

    public void doneReading() {
        doneReading = true;
        if (pendingCount.get() == 0) {
            shutdownAll();
        }
    }

    private void shutdownAll() {
        perfTracker.printSummary();
        for (RingManager manager : rings.values()) {
            manager.shutdown();
        }
        doneLatch.countDown();
    }

    public void awaitCompletion() throws InterruptedException {
        doneLatch.await();
        for (Thread t : ringThreads.values()) {
            t.join(5000);
        }
    }
}
