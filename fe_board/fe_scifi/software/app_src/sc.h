
#include "../../../fe/software/app_src/malibu/malibu_basic_cmd.h"

void sc_callback(volatile alt_u32* data) {
    auto& regs = sc->regs.scifi;

//check spi command register, trigger spi configuration if needed
    alt_u32 d0 = data[0x13];
    if(d0 != 0){
        printf("[sc_callback] SPICTRL_REGISTER = 0x%08X\n", d0);
        printf("SPI: START= %d ASIC=%u\n",(d0>>5)&1, d0&0x0f);
        usleep(1000);
        SPI_configure(d0&0x0f, stic3_config_ALL_OFF);

        data[0x13] = 0;
        printf("SPI: finished...\n");
    }
//check registers and forward to avalon test interface
    if(regs.ctrl.dummy != data[0x10])
        printf("Update value dummyctrl_reg:    0x%08X\n", data[0x10]);
    regs.ctrl.dummy = data[0x10];

    if(regs.ctrl.dp != data[0x11])
        printf("Update value dpctrl_reg:    0x%08X\n", data[0x11]);
    regs.ctrl.dp = data[0x11];

    if(regs.ctrl.reset != data[0x12])
        printf("Update value dummyctrl_reg:    0x%08X\n", data[0x12]);
    regs.ctrl.reset = data[0x12];

}

void menu_sc(volatile alt_u32* data) {
    while(1) {
        printf("  [r] => read sc ram\n");
        printf("  [w] => write sc ram\n");
        printf("  [q] => exit\n");

        printf("Select entry ...\n");
        char cmd = wait_key();
        switch(cmd) {
        case 'r':
            for(int i = 0; i < 32; i++) {
                printf("[0x%04X] = 0x%08X\n", i, data[i]);
            }
            break;
        case 'w':
            for(int i = 0; i < 32; i++) {
                data[i] = i;
            }
            break;
        case 'q':
            return;
        default:
            printf("invalid command: '%c'\n", cmd);
        }
    }
}
