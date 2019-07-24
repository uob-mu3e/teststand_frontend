/*
Malibu board init procedure:
- Set clock and test inputs
- Enable 3.3V supplies
- Disable 1.8 supplies for all ASICs 
- Set CS lines for all ASICs
-* Power monitor chips not initialized
-* I2C multiplexers not initialized

GPIO[0]: Init
        All 3.3V power off
        SEL_sysCLK->CK_FPGA0 (Mainboard)
        SEL_pllCLK->CK_SI1 (Mainboard)
        SEL_pllTEST->PLL_TEST (Mainboard)
        PLLtest disabled
        Configure GPIO, all output
Write Reg1 00001100 = 0x0C
Write Reg3 0x00

GPIO[1..7]: Init ASICs
        All CS high, All 1.8V power off
        All output
Write Reg1 11001100 = 0xCC
Write Reg3 0x00
*/

typedef alt_u8 uint8_t;
typedef alt_u16 uint16_t;

struct malibu_t {

    ALT_AVALON_I2C_DEV_t* i2c_dev = i2c.dev;

    alt_u8 I2C_read(alt_u8 slave, alt_u8 addr) {
        i2c_t::write(i2c_dev, slave, &addr, 1);
        alt_u8 data;
        i2c_t::read(i2c_dev, slave, &data, 1);
        printf("i2c_read: 0x%02X[0x%02X] is 0x%02X\n", slave, addr, data);
        return data;
    }

    void I2C_write(alt_u8 slave, alt_u8 addr, alt_u8 data) {
        printf("i2c_write: 0x%02X[0x%02X] <= 0x%02X\n", slave, addr, data);
        alt_u8 w[] = { addr, data };
        i2c_t::write(i2c_dev, slave, w, 2);
    }

    struct i2c_reg_t {
        alt_u8 slave;
        alt_u8 addr;
        alt_u8 data;
    };

    alt_u8 spi_write(alt_u8 w) {
        alt_u8 r = 0xCC;
//        printf("spi_write: 0x%02X\n", w);
        alt_avalon_spi_command(SPI_BASE, 1, 1, &w, 0, &r, 0);
        r = IORD_8DIRECT(SPI_BASE, 0);
//        printf("spi_read: 0x%02X\n", r);
        return r;
    }

    i2c_reg_t malibu_init_regs[18] = {
	{0x38,0x01,0x0C^0x20},
	{0x38,0x03,0x00},
	{0x38,0x01,0x0D^0x20},
	{0xff,0x00,0x00},
	{0x38,0x01,0x0F^0x20},
	{0xff,0x00,0x00},
	{0x39,0x01,0x3C},
	{0x39,0x03,0x00},
	{0x3a,0x01,0x3C},
	{0x3a,0x03,0x00},
	{0x3b,0x01,0x3C},
	{0x3b,0x03,0x00},
	{0x3c,0x01,0x3C},
	{0x3c,0x03,0x00},
	{0x3d,0x01,0x3C},
	{0x3d,0x03,0x00},
	{0x3f,0x01,0x3C},
	{0x3f,0x03,0x00}
    };

    /**
     * Power down cycle:
     * - Power down each ASIC (both 1.8V supplies at the same time)
     * - Power down 3.3V supplies
    */
    i2c_reg_t malibu_powerdown_regs[17] = {
	{0x3f,0x01,0x3C},
	{0xff,0x00,0x00},
	{0x3e,0x01,0x3C},
	{0xff,0x00,0x00},
	{0x3d,0x01,0x3C},
	{0xff,0x00,0x00},
	{0x3c,0x01,0x3C},
	{0xff,0x00,0x00},
	{0x3b,0x01,0x3C},
	{0xff,0x00,0x00},
	{0x3a,0x01,0x3C},
	{0xff,0x00,0x00},
	{0x39,0x01,0x3C},
	{0xff,0x00,0x00},
	{0x38,0x01,0x0D},
	{0xff,0x00,0x00},
	{0x38,0x01,0x0C}
    };

    void i2c_write_regs(const i2c_reg_t* regs, int n) {
        for(int i = 0; i < n; i++) {
            auto& reg = regs[i];
            if(reg.slave == 0xFF) {
                usleep(1000);
                continue;
            }
            I2C_write(reg.slave, reg.addr, reg.data);
        }
    }

    void powerup() {
        printf("[malibu] powerup\n");
        i2c_write_regs(malibu_init_regs, sizeof(malibu_init_regs) / sizeof(malibu_init_regs[0]));
        printf("[malibu] powerup DONE\n");
    }

    void powerdown() {
        printf("[malibu] powerdown\n");
        i2c_write_regs(malibu_powerdown_regs, sizeof(malibu_powerdown_regs) / sizeof(malibu_powerdown_regs[0]));
        printf("[malibu] powerdown DONE\n");
    }

    int PowerUpASIC(unsigned char n);
    int SPI_write_pattern(const unsigned char* bitpattern);
    int SPI_configure(unsigned char n, const unsigned char* bitpattern);
};

//Slow control pattern for stic3, pattern length and alloff configuration
#include "ALL_OFF.h"
#include "PLL_TEST_ch0to6_noGenIDLE.h"

//write slow control pattern over SPI, returns 0 if readback value matches written, otherwise -1. Does not include CSn line switching.
int malibu_t::SPI_write_pattern(const unsigned char* bitpattern) {
	int status=0;
	uint16_t rx_pre=0xff00;
	for(int nb=STIC3_CONFIG_LEN_BYTES-1; nb>=0; nb--){
		unsigned char rx=spi_write(bitpattern[nb]);
		//pattern is not in full units of bytes, so shift back while receiving to check the correct configuration state
		unsigned char rx_check= (rx_pre | rx ) >> (8-STIC3_CONFIG_LEN_BITS%8);
		if(nb==STIC3_CONFIG_LEN_BYTES-1){
			rx_check &= 0xff>>(8-STIC3_CONFIG_LEN_BITS%8);
		};

		if(rx_check!=stic3_config_ALL_OFF[nb]){
//			printf("Error in byte %d: received %2.2x expected %2.2x\n",nb,rx_check,bitpattern[nb]);
			status=-1;
		}
		rx_pre=rx<<8;
	}
	return status;
}

//configure a specific ASIC returns 0 if configuration is correct, -1 otherwise.
int malibu_t::SPI_configure(unsigned char n, const unsigned char* bitpattern) {
	//pull low CS line of the given ASIC
	char gpio_value = I2C_read(0x39+n/2, 0x01);
	gpio_value ^= 1<<(2+n%2*4);
	I2C_write(0x39+n/2, 0x01, gpio_value);

	//configure SPI. Note: pattern is not in full bytes, so validation gets a bit more complicated. Shifting out all bytes, and need to realign after.
	//This is to be done still
	int ret;
	ret=SPI_write_pattern(bitpattern);
	ret=SPI_write_pattern(bitpattern);

	//pull high CS line of the given ASIC
	gpio_value ^= 1<<(2+n%2*4);
	I2C_write(0x39+n/2, 0x01, gpio_value);
	return ret;
}


/*
Power up cycle for single ASIC
- Power digital 1.8V domain
- Configure ALL_OFF pattern two times
- Validate read back configuration
- If correct: Power up 1.8V analog domain
- else power down 1.8V digital domain
*/


int malibu_t::PowerUpASIC(unsigned char n) {
	printf("[malibu] powerup ASIC %u\n", n);
	char gpio_value=I2C_read(0x39+n/2,0x01);

	// enable 1.8V digital
	gpio_value |= 1<<(1+n%2*4);
	I2C_write(0x39+n/2, 0x01, gpio_value);
	int ret;
	ret=SPI_configure(n,stic3_config_ALL_OFF);
	ret=SPI_configure(n,stic3_config_ALL_OFF);
	if(ret != 0) { // configuration error, switch off again
		printf("Configuration mismatch, powering off again\n");
		gpio_value ^= 1<<(1+n%2*4);
		I2C_write(0x39+n/2,0x01,gpio_value);
		return -1;	
	}
	// enable 1.8V analog
	gpio_value |= 1<<(0+n%2*4);
	I2C_write(0x39+n/2, 0x01, gpio_value);
	printf("DONE\n");
	return 0;
}
