INCDIR=./inc
BINDIR=./bin
OBJDIR=./obj
SRCDIR=./src
TESTDIR=./t

INCS=

CC=gcc
LFLAGS=-g -Wall
CFLAGS=-g -Wall -c

all: $(BINDIR)/driver

$(BINDIR)/driver: $(OBJDIR)/driver.o
	$(CC) $(LFLAGS) -o $@ $^

$(OBJDIR)/driver.o: $(TESTDIR)/driver.c $(INCS)
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -rf $(BINDIR) $(OBJDIR)
	mkdir $(BINDIR) $(OBJDIR)
