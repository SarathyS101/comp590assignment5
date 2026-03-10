package ringsystem;

import java.util.Scanner;

public class Main {
    public static void main(String[] args) {
        int n = 10;
        int h = 10;

        for (int i = 0; i < args.length; i++) {
            switch (args[i]) {
                case "--n" -> n = Integer.parseInt(args[++i]);
                case "--h" -> h = Integer.parseInt(args[++i]);
            }
        }

        System.out.printf("Starting ring system with N=%d nodes per ring, H=%d hops per token%n", n, h);
        System.out.println("Enter integers (one per line). Type 'done' or EOF to finish.\n");

        new JvmMon().start();

        Coordinator coordinator = new Coordinator(n, h);
        coordinator.start();

        Scanner scanner = new Scanner(System.in);
        while (scanner.hasNextLine()) {
            String line = scanner.nextLine().trim();
            if (line.equals("done")) break;
            if (line.isEmpty()) continue;
            try {
                long value = Long.parseLong(line);
                coordinator.submitInput(value);
            } catch (NumberFormatException e) {
                System.out.println("Skipping invalid input: " + line);
            }
        }
        scanner.close();

        coordinator.doneReading();

        try {
            coordinator.awaitCompletion();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
}
