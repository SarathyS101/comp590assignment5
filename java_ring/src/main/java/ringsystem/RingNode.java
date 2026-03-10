package ringsystem;

import java.util.concurrent.LinkedBlockingQueue;

public class RingNode implements Runnable {
    private final RingType ringId;
    private final LinkedBlockingQueue<Object> inbox = new LinkedBlockingQueue<>();
    private final LinkedBlockingQueue<Object> managerQueue;
    private LinkedBlockingQueue<Object> nextInbox;

    public RingNode(RingType ringId, LinkedBlockingQueue<Object> managerQueue) {
        this.ringId = ringId;
        this.managerQueue = managerQueue;
    }

    public void setNext(RingNode next) {
        this.nextInbox = next.inbox;
    }

    public LinkedBlockingQueue<Object> getInbox() {
        return inbox;
    }

    @Override
    public void run() {
        try {
            while (true) {
                Object msg = inbox.take();
                if (msg instanceof String s && s.equals("SHUTDOWN")) {
                    break;
                }
                if (msg instanceof Token token) {
                    if (token.remainingHops <= 0) {
                        managerQueue.put(token);
                    } else {
                        token.currentVal = Transforms.apply(ringId, token.currentVal);
                        token.remainingHops--;
                        nextInbox.put(token);
                    }
                }
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
