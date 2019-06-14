#include <stdio.h>
#include <stdlib.h>

#include <iostream>
#include <unistd.h>

#include "midas.h"
#include "msystem.h"
#include "mcstd.h"
#include "experim.h"

#include <cuda.h>
#include <cuda_runtime_api.h>

#include <sstream>
#include <fstream>

#include "mudaq_device.h"
#include "mfe.h"

using namespace std;

/*-- Globals -------------------------------------------------------*/

/* The frontend name (client name) as seen by other MIDAS clients   */
const char *frontend_name = "Stream Frontend";

/* The frontend file name, don't change it */
const char *frontend_file_name = __FILE__;

/* frontend_loop is called periodically if this variable is TRUE    */
BOOL frontend_call_loop = FALSE;

/* a frontend status page is displayed with this frequency in ms */
INT display_period = 3000;

/* maximum event size produced by this frontend */
INT max_event_size = 1000000;

/* maximum event size for fragmented events (EQ_FRAGMENTED) */
INT max_event_size_frag = 5 * 1024 * 1024;

/* buffer size to hold events */
INT event_buffer_size = 100 * 1000000;

/* DMA Buffer and related */
volatile uint32_t *dma_buf;
size_t dma_buf_size = MUDAQ_DMABUF_DATA_LEN;
uint32_t dma_buf_nwords = dma_buf_size/sizeof(uint32_t);
uint32_t laddr;
uint32_t newdata;
uint32_t readindex;
bool moreevents;
bool firstevent;
ofstream myfile;

int blockNumber;

mudaq::DmaMudaqDevice * mup;
mudaq::DmaMudaqDevice::DataBlock block;

/*-- Function declarations -----------------------------------------*/

INT frontend_init();
INT frontend_exit();
INT begin_of_run(INT run_number, char *error);
INT end_of_run(INT run_number, char *error);
INT pause_run(INT run_number, char *error);
INT resume_run(INT run_number, char *error);
INT frontend_loop();

INT read_stream_event(char *pevent, INT off);
INT read_stream_thread(void *param);

INT poll_event(INT source, INT count, BOOL test);
INT interrupt_configure(INT cmd, INT source, POINTER_T adr);

/*-- Equipment list ------------------------------------------------*/

EQUIPMENT equipment[] = {

   {"Stream",                /* equipment name */
    {1, 0,                   /* event ID, trigger mask */
     "SYSTEM",               /* event buffer */
     EQ_USER,                /* equipment type */
     0,                      /* event source crate 0, all stations */
     "MIDAS",                /* format */
     TRUE,                   /* enabled */
     RO_RUNNING,             /* read only when running */
     100,                    /* poll for 100ms */
     0,                      /* stop run after this event limit */
     0,                      /* number of sub events */
     0,                      /* don't log history */
     "", "", "",},
    NULL,                    /* readout routine */
    },

   {""}
};

/*-- Frontend Init -------------------------------------------------*/

INT frontend_init()
{
   HNDLE hDB, hStreamSettings;
   
   set_equipment_status(equipment[0].name, "Initializing...", "var(--myellow)");
   
   // Get database
   cm_get_experiment_database(&hDB, NULL);
   
   // Map /equipment/Stream/Settings (structure defined in experim.h)
   char set_str[255];
   STREAM_SETTINGS_STR(stream_settings_str);

   sprintf(set_str, "/Equipment/Stream/Settings");
   int status = db_create_record(hDB, 0, set_str, strcomb(stream_settings_str));
   status = db_find_key (hDB, 0, set_str, &hStreamSettings);
   if (status != DB_SUCCESS){
      cm_msg(MINFO,"frontend_init","Key %s not found", set_str);
      return status;
   }
   
   // Allocate memory for the DMA buffer - this can fail!
   if(cudaMallocHost( (void**)&dma_buf, dma_buf_size ) != cudaSuccess){
      cout << "Allocation failed, aborting!" << endl;
      cm_msg(MERROR, "frontend_init" , "Allocation failed, aborting!");
      return FE_ERR_DRIVER;
   }
   
   // initialize to zero
   for (int i = 0; i <  dma_buf_nwords ; i++) {
      (dma_buf)[i] = 0;
   }
   
   mup = new mudaq::DmaMudaqDevice("/dev/mudaq0");
   if ( !mup->open() ) {
      cout << "Could not open device " << endl;
      cm_msg(MERROR, "frontend_init" , "Could not open device");
      return FE_ERR_DRIVER;
   }
   
   if ( !mup->is_ok() )
      return FE_ERR_DRIVER;
   
   cm_msg(MINFO, "frontend_init" , "Mudaq device is ok");
   cout << "Mudaq device is ok " << endl;
   
   struct mesg user_message;
   user_message.address = dma_buf;
   user_message.size = dma_buf_size;
   
   // map memory to bus addresses for FPGA
   int ret_val = mup->map_pinned_dma_mem( user_message );
   
   if (ret_val < 0) {
      cout << "Mapping failed " << endl;
      cm_msg(MERROR, "frontend_init" , "Mapping failed");
      mup->disable();
      mup->close();
      free( (void *)dma_buf );
      delete mup;
      return FE_ERR_DRIVER;
   }
   
   // switch off and reset DMA for now
   mup->disable();
   
   // switch off the data generator (just in case..)
   mup->write_register(DATAGENERATOR_REGISTER_W, 0x0);
   usleep(2000);
   mup->write_register(LED_REGISTER_W,0x0);
   usleep(5000);
   
   // create ring buffer for readout thread
   create_event_rb(0);
   
   // create readout thread
   ss_thread_create(read_stream_thread, NULL);
      
   set_equipment_status(equipment[0].name, "Ready for running", "var(--mgreen)");
   
   return SUCCESS;
}

/*-- Frontend Exit -------------------------------------------------*/

INT frontend_exit()
{
   if (mup) {
      mup->disable();
      mup->close();
      delete mup;
   }

   // following code crashes the frontend, please fix!
   // free( (void *)dma_buf );
   
   return SUCCESS;
}

/*-- Begin of Run --------------------------------------------------*/

INT begin_of_run(INT run_number, char *error)
{ 
   set_equipment_status(equipment[0].name, "Starting run", "var(--myellow)");
   
   mudaq::DmaMudaqDevice & mu = *mup;
   
   // Reset last written address used for polling
   laddr = mu.last_written_addr();
   newdata = 0;
   readindex = 0;
   moreevents = false;
   firstevent = true;
   blockNumber = 0;
   
   // Reset dma part and data generator
   uint32_t reset_reg =0;
   reset_reg = SET_RESET_BIT_DATAGEN(reset_reg);
   mu.write_register_wait(RESET_REGISTER_W, reset_reg,100);
   mu.write_register_wait(RESET_REGISTER_W, 0x0,100);
   
   // Enable register on FPGA for continous readout
   mu.enable_continous_readout(0);
   
   // Get ODB settings for this equipment
   HNDLE hDB, hStreamSettings;
   INT status, size;
   char set_str[256];
   STREAM_SETTINGS settings;  // defined in experim.h
   
   /* Get current  settings */
   cm_get_experiment_database(&hDB, NULL);
   sprintf(set_str, "/Equipment/Stream/Settings");
   status = db_find_key (hDB, 0, set_str, &hStreamSettings);
   if (status != DB_SUCCESS) {
      cm_msg(MERROR, "begin_of_run", "cannot find stream settings record from ODB");
      return status;
   }
   size = sizeof(settings);
   status = db_get_record(hDB, hStreamSettings, &settings, &size, 0);
   if (status != DB_SUCCESS) {
      cm_msg(MERROR, "begin_of_run", "cannot retrieve stream settings from ODB");
      return status;
   }
   
   /* Set up data generator */
   mu.write_register(DATAGENERATOR_DIVIDER_REGISTER_W, settings.datagenerator.divider);
   
   uint32_t datagen_setup = 0;
   if (settings.datagenerator.enable_pixel)
      datagen_setup = SET_DATAGENERATOR_BIT_ENABLE_PIXEL(datagen_setup);
   if (settings.datagenerator.enable_fibre)
      datagen_setup = SET_DATAGENERATOR_BIT_ENABLE_FIBRE(datagen_setup);
   if (settings.datagenerator.enable_tile)
      datagen_setup = SET_DATAGENERATOR_BIT_ENABLE_TILE(datagen_setup);
   datagen_setup = SET_DATAGENERATOR_NPIXEL_RANGE(datagen_setup, settings.datagenerator.npixel);
   datagen_setup = SET_DATAGENERATOR_NFIBRE_RANGE(datagen_setup, settings.datagenerator.nfibre);
   datagen_setup = SET_DATAGENERATOR_NTILE_RANGE(datagen_setup, settings.datagenerator.ntile);
   if (settings.datagenerator.enable)
      datagen_setup = SET_DATAGENERATOR_BIT_ENABLE(datagen_setup);
   
   //cm_msg(MINFO, "begin_of_run" , "addr 0x%x" , mu.last_written_addr());
   // mu.write_register(DATAGENERATOR_REGISTER_W, datagen_setup);
   mu.write_register(DATAGENERATOR_REGISTER_W, 0xffffffff);// start data generator
   //mu.write_register(LED_REGISTER_W,0x0000ffff);
   
   set_equipment_status(equipment[0].name, "Running", "var(--mgreen)");
   
   return SUCCESS;
}

/*-- End of Run ----------------------------------------------------*/

INT end_of_run(INT run_number, char *error)
{
   mudaq::DmaMudaqDevice & mu = *mup;
   
   uint32_t datagen_setup = mu.read_register_rw(DATAGENERATOR_REGISTER_W);
   datagen_setup = UNSET_DATAGENERATOR_BIT_ENABLE(datagen_setup);
   //mu.write_register_wait(DATAGENERATOR_REGISTER_W, datagen_setup,1000);
   mu.write_register(LED_REGISTER_W,0x0);
   mu.write_register(DATAGENERATOR_REGISTER_W, 0x0);
   usleep(100000); // wait for remianing data to be pushed
   mu.disable(); // disable DMA
   set_equipment_status(equipment[0].name, "Ready for running", "var(--mgreen)");
   
   return SUCCESS;
}

/*-- Pause Run -----------------------------------------------------*/

INT pause_run(INT run_number, char *error)
{
   mudaq::DmaMudaqDevice & mu = *mup;
   
   uint32_t datagen_setup = mu.read_register_rw(DATAGENERATOR_REGISTER_W);
   datagen_setup = UNSET_DATAGENERATOR_BIT_ENABLE(datagen_setup);
   mu.write_register_wait(DATAGENERATOR_REGISTER_W, datagen_setup,1000);
   
   set_equipment_status(equipment[0].name, "Paused", "var(--myellow)");
   
   return SUCCESS;
}

/*-- Resume Run ----------------------------------------------------*/

INT resume_run(INT run_number, char *error)
{
   mudaq::DmaMudaqDevice & mu = *mup;
   
   uint32_t datagen_setup = mu.read_register_rw(DATAGENERATOR_REGISTER_W);
   datagen_setup = SET_DATAGENERATOR_BIT_ENABLE(datagen_setup);
   mu.write_register_wait(DATAGENERATOR_REGISTER_W, datagen_setup,1000);
   
   set_equipment_status(equipment[0].name, "Running", "var(--mgreen)");
   
   return SUCCESS;
}

/*-- Frontend Loop -------------------------------------------------*/

INT frontend_loop()
{
   /* if frontend_call_loop is true, this routine gets called when
      the frontend is idle or once between every event */
   return SUCCESS;
}

/*-- Trigger event routines ----------------------------------------*/

INT poll_event(INT source, INT count, BOOL test)
/* Polling routine for events. Returns TRUE if event
 is available. If test equals TRUE, don't return. The test
 flag is used to time the polling */
{
   /*
   if(moreevents && !test)
      return 1;
   
   mudaq::DmaMudaqDevice & mu = *mup;
   
   for (int i = 0; i < count; i++) {
      uint32_t addr = mu.last_written_addr();
      if ((addr != laddr) && !test) {
         if (firstevent) {
            newdata = addr;
            firstevent = false;
         } else {
            if(addr > laddr)
               newdata = addr - laddr;
            else
               newdata = 0x10000 - laddr + addr;
         }
         if (newdata > 0x10000) {
            return 0;
         }
         laddr = addr;
         return 1;
      }
   }
   */
   return 0;
}

/*-- Interrupt configuration ---------------------------------------*/

INT interrupt_configure(INT cmd, INT source, POINTER_T adr)
{
   return SUCCESS;
}

/*-- Event readout -------------------------------------------------*/

INT read_stream_event(char *pevent, INT off)
{
   /*
   bk_init(pevent);
   
   DWORD *pdata;
   uint32_t read = 0;
   bk_create(pevent, "HEAD", TID_DWORD, (void **)&pdata);
   
   for (int i =0; i < 8; i ++) {
      *pdata++ = dma_buf[(++readindex)%dma_buf_nwords];
      read++;
   }
   
   bk_close(pevent, pdata);
   newdata -= read;
   
   if (read < newdata && newdata < 0x10000)
      moreevents = true;
   else
      moreevents = false;
   
   return bk_size(pevent);
   */
   return 0;
}

/*-- Event readout -------------------------------------------------*/

INT read_stream_thread(void *param)
{
   mudaq::DmaMudaqDevice & mu = *mup;
   //uint32_t addr = mu.last_written_addr();
   readindex = 0;
   EVENT_HEADER *pEventHeader;
   void *pEventData;
   DWORD *pdata;
   int status;
   
   
   // tell framework that we are alive
   signal_readout_thread_active(0, TRUE);
   
   // obtain ring buffer for inter-thread data exchange
   int rbh = get_event_rbh(0);
   
   while (is_readout_thread_enabled()) {
      
       if(blockNumber == 8){
           // we are at mu.last_written_addr() ...  ask for a new bunch of x 256-bit words
            readindex = mu.last_written_addr();
            //cout<<"readindex: "<< readindex <<endl;
            mu.write_register(LED_REGISTER_W,0x00010000);
            ss_sleep(10);
            mu.write_register(LED_REGISTER_W,0x0);
            ss_sleep(10);
            blockNumber=0;
      }
      blockNumber++;
      
      // obtain buffer space
      status = rb_get_wp(rbh, (void **)&pEventHeader, 0);
      if (!is_readout_thread_enabled()){
         break;
      }
      if (status == DB_TIMEOUT) {
         // just sleep and try again if buffer has no space
         ss_sleep(10);
         cout<<"DB Timeout"<<endl;
         continue;
      }
      if (status != DB_SUCCESS){
         break;
      }
      // don't readout events if we are not running
      if (run_state != STATE_RUNNING) {
          //cout<<"not running"<<endl;
         ss_sleep(10);

         continue;
      }
      
      // check for new event
      status = TRUE;
      if (status) {
         bm_compose_event(pEventHeader, equipment[0].info.event_id, 0, 0, equipment[0].serial_number++);
         pEventData = (void *)(pEventHeader + 1);
         
         // init bank structure
         bk_init32(pEventData);

         // create "HEAD" bank
         bk_create(pEventData, "HEAD", TID_DWORD, (void **)&pdata);
         //cout<<"creating event"<<endl;
         for (int i=0 ; i< 65536; i++){
            //*pdata++ = rand();
            *pdata++ = dma_buf[(++readindex)%dma_buf_nwords];
         }
         bk_close(pEventData, pdata);
         
         pEventHeader->data_size = bk_size(pEventData);
         rb_increment_wp(rbh, sizeof(EVENT_HEADER) + pEventHeader->data_size);
         // send event to ring buffer
      }
   }
   
   // tell framework that we finished
   signal_readout_thread_active(0, FALSE);
   return 0;
}
