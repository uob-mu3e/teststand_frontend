#ifndef LINK_CONSTANTS_H
#define LINK_CONSTANTS_H

/* Maximum number of  switching boards */
const int MAX_N_SWITCHINGBOARDS = 4;

/* Maximum number of links per switching board */
const int MAX_LINKS_PER_SWITCHINGBOARD = 48;

/* Maximum number of FEBs per switching board */
const int MAX_FEBS_PER_SWITCHINGBOARD = 34;

/* Maximum number of frontenboards */
const int MAX_N_FRONTENDBOARDS = MAX_N_SWITCHINGBOARDS*MAX_LINKS_PER_SWITCHINGBOARD;

/* Number of FEBs in final system */
const int N_FEBS[MAX_N_SWITCHINGBOARDS] = {34, 33, 33, 12};

/* Identification of FEB by subsystem */
enum FEBTYPE {Undefined, Pixel, Fibre, Tile, FibreSecondary};
const std::string FEBTYPE_STR[5]={"Undefined","Pixel","Fibre","Tile", "FibreSecondary"};

/* Status of links */
enum LINKSTATUS {Disabled, OK, Unknown, Fault};

/* Masking of FEBs */
enum FEBLINKMASK {OFF, SCOn, DataOn, ON};


#endif // LINK_CONSTANTS_H
