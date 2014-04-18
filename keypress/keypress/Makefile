CC = gcc 

CFLAGS = -g -D_WIN32 -m32 -march=i486 -std=c99 -DKEYPRESS
		 #-MT -MD -MP  
		 
INCLUDES =  -I.. -I../unpacker -I. -I/C/MinGW/include
			#-I/C/MinGW/include -I/C/MinGW/include/linux
			# -I/C/MinGW/include -I/C/MinGW/include/linux  -I/C/MinGW/lib/gcc/mingw32/4.6.2/include
			#-isystem c:/mingw/bin/../lib/gcc/mingw32/4.6.2/include-fixed -isystem c:/mingw/bin/../lib/gcc/mingw32/4.6.2/include
			#-I/usr/include/ -I/C/MinGW/include -I/C/MinGW/include/linux 
			
OPTIMIZATION =  -Os
				
SOURCES = main.c 

OBJS = $(SOURCES:.c=.o)

TARGET = kpress.exe

all: $(SOURCES)
	$(CC) -o $(TARGET) $(CFLAGS) $(INCLUDES) $(OPTIMIZATION) $^
	
#	rm $(OBJS