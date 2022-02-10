// Definitions for the all-powerful integration switching board (all subdetectors)

constexpr int switch_id = 0;
// 0 - Central
// 1 - Recurl US
// 2 - Recurl DS
// 3 - Fibres

constexpr bool has_scifi = true;
constexpr bool has_tiles = true;
constexpr bool has_pixels = true;

const char *frontend_name = "SW Integration";
const string fe_name = "SW Integration";
const string eq_name = "SwitchingIntegration";
const string link_eq_name = "LinksIntegration";
const string scifi_eq_name = "ScifiIntegration";
const string tile_eq_name = "TilesItegration";
const string pixel_eq_name = "PixelsIntegration";

/*-- Equipment list ------------------------------------------------*/
enum EQUIPMENT_ID {Switching=0,Links, SciFi,SciTiles,Mupix};
constexpr int NEQUIPMENT = 5;
EQUIPMENT equipment[NEQUIPMENT+1] = {
   {"SwitchingIntegration",     /* equipment name */
    {110, 0,                    /* event ID, trigger mask */
     "SYSTEM",                  /* event buffer */
     EQ_PERIODIC,               /* equipment type */
     0,                         /* event source */
     "MIDAS",                   /* format */
     TRUE,                      /* enabled */
     RO_ALWAYS | RO_ODB,        /* read always and update ODB */
     1000,                      /* read every 1 sec */
     0,                         /* stop run after this event limit */
     0,                         /* number of sub events */
     1,                         /* log history every event */
     "", "", ""},
     read_sc_event,             /* readout routine */
   },
   {"LinksIntegration",         /* equipment name */
    {110, 0,                    /* event ID, trigger mask */
     "SYSTEM",                  /* event buffer */
     EQ_PERIODIC,               /* equipment type */
     0,                         /* event source */
     "MIDAS",                   /* format */
     TRUE,                      /* enabled */
     RO_ALWAYS | RO_ODB,        /* read always and update ODB */
     1000,                      /* read every 1 sec */
     0,                         /* stop run after this event limit */
     0,                         /* number of sub events */
     1,                         /* log history every event */
     "", "", ""},
     read_sc_event,             /* readout routine */
   },
   {"SciFiIntegration",         /* equipment name */
    {111, 0,                    /* event ID, trigger mask */
     "SYSTEM",                  /* event buffer */
     EQ_PERIODIC,                 /* equipment type */
     0,                         /* event source crate 0, all stations */
     "MIDAS",                   /* format */
     FALSE,                      /* enabled */
     RO_ALWAYS | RO_ODB,        /* read always and update ODB */
     10000,                      /* read every 10 sec */
     0,                         /* stop run after this event limit */
     0,                         /* number of sub events */
     1,                         /* log history every event */
     "", "", "",},
     read_scifi_sc_event,          /* readout routine */
    },
   {"SciTilesIntegration",       /* equipment name */
    {112, 0,                      /* event ID, trigger mask */
     "SYSTEM",                  /* event buffer */
     EQ_PERIODIC,                 /* equipment type */
     0,                         /* event source crate 0, all stations */
     "MIDAS",                   /* format */
     FALSE,                      /* enabled */
     RO_ALWAYS | RO_ODB,        /* read always and update ODB */
     10000,                      /* read every 10 sec */
     0,                         /* stop run after this event limit */
     0,                         /* number of sub events */
     1,                         /* log history every event */
     "", "", "",},
     read_scitiles_sc_event,          /* readout routine */
    },
    {"MupixIntegration",         /* equipment name */
    {113, 0,                      /* event ID, trigger mask */
     "SYSTEM",                  /* event buffer */
     EQ_PERIODIC,                 /* equipment type */
     0,                         /* event source crate 0, all stations */
     "MIDAS",                   /* format */
     TRUE,                      /* enabled */
     RO_ALWAYS | RO_ODB,   /* read during run transitions and update ODB */
     1000,                      /* read every 1 sec */
     0,                         /* stop run after this event limit */
     0,                         /* number of sub events */
     1,                         /* log history every event */
     "", "", "",},
     read_mupix_sc_event,          /* readout routine */
    },
    {""}
};

