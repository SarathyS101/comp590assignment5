package ringsystem;

import java.lang.management.ManagementFactory;

public class JvmMon extends Thread {
    public JvmMon() {
        setDaemon(true);
        setName("JvmMon");
    }

    @Override
    public void run() {
        Runtime runtime = Runtime.getRuntime();
        while (true) {
            long totalMem = runtime.totalMemory() / 1024;
            long freeMem = runtime.freeMemory() / 1024;
            long usedMem = totalMem - freeMem;
            int threadCount = ManagementFactory.getThreadMXBean().getThreadCount();

            System.out.printf("[JvmMon] threads=%d, heap_used=%dKB, heap_total=%dKB%n",
                    threadCount, usedMem, totalMem);

            try {
                Thread.sleep(5000);
            } catch (InterruptedException e) {
                break;
            }
        }
    }
}
