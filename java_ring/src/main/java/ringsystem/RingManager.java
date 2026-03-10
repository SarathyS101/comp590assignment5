package ringsystem;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.List;
import java.util.Queue;
import java.util.concurrent.LinkedBlockingQueue;

public class RingManager implements Runnable {
    private final RingType ringId;
    private final int n;
    private final LinkedBlockingQueue<Object> commandQueue = new LinkedBlockingQueue<>();
    private final Coordinator coordinator;
    private final List<RingNode> nodes = new ArrayList<>();
    private final List<Thread> nodeThreads = new ArrayList<>();
    private final Queue<Token> waitQueue = new ArrayDeque<>();
    private boolean inFlight = false;

    // Command types
    public record EnqueueCmd(Token token) {}
    public record ShutdownCmd() {}

    public RingManager(RingType ringId, int n, Coordinator coordinator) {
        this.ringId = ringId;
        this.n = n;
        this.coordinator = coordinator;
    }

    public void enqueue(Token token) {
        commandQueue.add(new EnqueueCmd(token));
    }

    public void shutdown() {
        commandQueue.add(new ShutdownCmd());
    }

    @Override
    public void run() {
        // Create and wire nodes
        for (int i = 0; i < n; i++) {
            RingNode node = new RingNode(ringId, commandQueue);
            nodes.add(node);
        }
        for (int i = 0; i < n; i++) {
            nodes.get(i).setNext(nodes.get((i + 1) % n));
        }
        for (RingNode node : nodes) {
            Thread t = new Thread(node, ringId + "-node");
            t.setDaemon(true);
            t.start();
            nodeThreads.add(t);
        }

        // Event loop
        try {
            while (true) {
                Object msg = commandQueue.take();

                if (msg instanceof EnqueueCmd cmd) {
                    if (inFlight) {
                        waitQueue.add(cmd.token());
                    } else {
                        dispatch(cmd.token());
                        inFlight = true;
                    }
                } else if (msg instanceof Token token) {
                    // Completed token from a ring node
                    coordinator.onResult(token);
                    Token next = waitQueue.poll();
                    if (next != null) {
                        dispatch(next);
                    } else {
                        inFlight = false;
                    }
                } else if (msg instanceof ShutdownCmd) {
                    // Drain remaining queued tokens
                    while (inFlight) {
                        Object completion = commandQueue.take();
                        if (completion instanceof Token t) {
                            coordinator.onResult(t);
                            Token nextToken = waitQueue.poll();
                            if (nextToken != null) {
                                dispatch(nextToken);
                            } else {
                                inFlight = false;
                            }
                        }
                    }
                    // Shut down nodes
                    for (RingNode node : nodes) {
                        node.getInbox().put("SHUTDOWN");
                    }
                    break;
                }
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    private void dispatch(Token token) {
        nodes.get(0).getInbox().add(token);
    }
}
