all:
	# Build every object file
	gcc -c hello_ada.adb -o hello_ada.o
	gcc -c main.c -o main.o
	gcc -c helper.c -o helper.o

	# Use the binder to create the adafinal and adainit code
	gnatbind -n hello_ada.ali -o init.adb
	gcc -c init.adb -o init.o

	# Create the executable
	gcc main.o helper.o hello_ada.o init.o -lgnat -o hello_ada

clean:
	rm -f *.o *.ali hello_ada init.adb init.ads