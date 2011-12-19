
BSTC=bstc
BSTL=bstl

SPIN_LIBRARY_PATH?=~/propeller-library

CURL?=curl

YBOX2_ADDRESS?=172.30.96.90
YBOX2_USERNAME?=admin
YBOX2_PASSWORD?=bubba31337
YBOX2_BASEURL?=http://$(YBOX2_USERNAME):$(YBOX2_PASSWORD)@$(YBOX2_ADDRESS)/

BAUD_RATE?=19200

SERIAL_PORT?=/dev/tty.usbserial-pplu*

%.binary: %.spin
	$(BSTC) -L $(SPIN_LIBRARY_PATH) -b $<

%.load-ram: %.binary
	$(BSTL) $<

%.load-eeprom: %.binary
	$(BSTL) -p 3 $<

%.load-ybox2: %.binary
	$(CURL) --anyauth $(YBOX2_BASEURL)stage2.eeprom?boot -T $<

%.term: %.load-ram
	screen $(SERIAL_PORT) $(BAUD_RATE)

%.cu: %.load-ram
	# We do this weird sleep thing here so we can kill the terminal
	# easily with a CTRL-C. Without it, 'cu' eats the CTRL-C.
	sleep 100000 | cu -l $(SERIAL_PORT) -s $(BAUD_RATE)

all: bootloader.binary

load-ram: bootloader.load-ram

load-eeprom: bootloader.load-eeprom

load-ybox2: bootloader.load-ybox2

ybox2-bootloader:
	$(CURL) --anyauth $(YBOX2_BASEURL)reboot?bootloader

term: bootloader.term

cu: bootloader.cu

clean:
	$(RM) -f bootloader.binary

###############################
# Dependencies listed below
#

bootloader.binary: bootloader.spin api_telnet_serial.spin driver_socket.spin driver_enc28j60.spin pause.spin settings.spin Fast_I2C_Driver.spin qring.spin TV_Text.spin tv.spin subsys.spin http.spin auth_digest.spin base16.spin MD5.spin


