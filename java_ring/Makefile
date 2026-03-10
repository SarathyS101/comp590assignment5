SRCDIR = src/main/java
OUTDIR = out
SOURCES = $(shell find $(SRCDIR) -name '*.java')

.PHONY: all clean run

all: $(OUTDIR)/ringsystem/Main.class

$(OUTDIR)/ringsystem/Main.class: $(SOURCES)
	mkdir -p $(OUTDIR)
	javac -d $(OUTDIR) $(SOURCES)

run: all
	java -cp $(OUTDIR) ringsystem.Main $(ARGS)

clean:
	rm -rf $(OUTDIR)
