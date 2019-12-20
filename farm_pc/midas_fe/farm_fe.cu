#include <stdio.h>
#include <stdlib.h>

#include <iostream>
#include <unistd.h>

#include "midas.h"
#include "msystem.h"
#include "mcstd.h"
#include "experim.h"
#include "switching_constants.h"

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
INT display_period = 0;

/* maximum event size produced by this frontend */
INT max_event_size = 10000;

/* maximum event size for fragmented events (EQ_FRAGMENTED) */
INT max_event_size_frag = 5 * 1024 * 1024;

/* buffer size to hold events */
INT event_buffer_size = 10000 * max_event_size;

/* DMA Buffer and related */
volatile uint32_t *dma_buf;
size_t dma_buf_size = MUDAQ_DMABUF_DATA_LEN;
uint32_t dma_buf_nwords = dma_buf_size/sizeof(uint32_t);
uint32_t laddr;
uint32_t newdata;
uint32_t readindex;
uint32_t lastreadindex;
uint32_t lastlastWritten;
bool moreevents;
bool firstevent;

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

void speed_settings_changed(HNDLE, HNDLE, int, void *);
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
   cout<<"DMA_BUF_LENGTH: "<<dma_buf_size<<"  dma_buf_nwords: "<<dma_buf_nwords<<endl; 
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
   cm_set_transition_sequence(TR_START,300);
   cm_set_transition_sequence(TR_STOP,700);
   // add custom page to ODB
   db_create_key(hDB, 0, "Custom/Farm&", TID_STRING);
   const char * name = "farm.html";
   db_set_value(hDB,0,"Custom/Farm&",name, sizeof(name), 1,TID_STRING);

   HNDLE hKey;

   // create Settings structure in ODB
   db_find_key(hDB, 0, "/Equipment/Stream/Settings/Datagenerator", &hKey);
   assert(hKey);
   db_watch(hDB, hKey, speed_settings_changed, nullptr);

   
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
   lastlastWritten = 0;
   
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
   // DMA_CONTROL_W
   mup->write_register(0x5,0x0);
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

void speed_settings_changed(HNDLE hDB, HNDLE hKey, INT, void *)
{
    KEY key;
    db_get_key(hDB, hKey, &key);

    if (std::string(key.name) == "Divider") {
       int value;
       int size = sizeof(value);
       db_get_data(hDB, hKey, &value, &size, TID_INT);
       cm_msg(MINFO, "speed_settings_changed", "Set divider to %d", value);
      // mu.write_register_wait(DMA_SLOW_DOWN_REGISTER_W,value,100);
    }
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

   // reset all
   uint32_t reset_reg = 0;
   reset_reg |= 1<<RESET_BIT_EVENT_COUNTER;
   reset_reg |= 1<<RESET_BIT_DATAGEN;

   mu.write_register_wait(RESET_REGISTER_W, reset_reg, 100);
   // Enable register on FPGA for continous readout and enable dma
   lastlastWritten = mu.last_written_addr();
   mu.enable_continous_readout(0);
   usleep(10);
   mu.write_register_wait(RESET_REGISTER_W, 0x0, 100);

   // Set up data generator
   uint32_t datagen_setup = 0;
    mu.write_register_wait(DMA_SLOW_DOWN_REGISTER_W, 0x3E8, 100);//3E8); // slow down to 64 MBit/s
    datagen_setup = SET_DATAGENERATOR_BIT_ENABLE_PIXEL(datagen_setup);
    mu.write_register_wait(DATAGENERATOR_REGISTER_W, datagen_setup, 100);

    // Enable all links
    mu.write_register_wait(FEB_ENABLE_REGISTER_W, 0xF, 100);
   
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
   
   set_equipment_status(equipment[0].name, "Running", "var(--mgreen)");
   
   return SUCCESS;
}

/*-- End of Run ----------------------------------------------------*/

INT end_of_run(INT run_number, char *error)
{

   mudaq::DmaMudaqDevice & mu = *mup;
   printf("farm_fe: Waiting for buffers to empty\n");
   uint16_t timeout_cnt = 0;
   while(! mu.read_register_ro(BUFFER_STATUS_REGISTER_R) & 1<<0/* TODO right bit */ &&
         timeout_cnt++ < 50) {
      printf("Waiting for buffers to empty %d/50\n", timeout_cnt);
      timeout_cnt++;
      usleep(1000);
   };

//   if(timeout_cnt>=50) {
//      cm_msg(MERROR,"farm_fe","Buffers on Switching Board not empty at end of run");
//      set_equipment_status(equipment[0].name, "Not OK", "var(--mred)");
//      return CM_TRANSITION_CANCELED;
//   }
   printf("Buffers all empty\n");


   // TODO: Find a better way to see when DMA is finished.

   printf("Waiting for DMA to finish\n");
   usleep(1000); // Wait for DMA to finish
   timeout_cnt = 0;
   while(mu.last_written_addr() != (readindex % dma_buf_nwords) &&
         timeout_cnt++ < 50) {
      printf("Waiting for DMA to finish %d/50\n", timeout_cnt);
      timeout_cnt++;
      usleep(1000);
   };

//   if(timeout_cnt>=50) {
//      cm_msg(MERROR,"farm_fe","DMA did not finish");
//      set_equipment_status(equipment[0].name, "Not OK", "var(--mred)");
//      return CM_TRANSITION_CANCELED;
//   }
   printf("DMA is finished\n");

    // stop generator
   uint32_t datagen_setup = 0;
   datagen_setup = UNSET_DATAGENERATOR_BIT_ENABLE(datagen_setup);
   mu.write_register_wait(DATAGENERATOR_REGISTER_W, datagen_setup, 100);
   mu.write_register_wait(DMA_SLOW_DOWN_REGISTER_W, 0x0, 100);

   // disable DMA
   mu.disable();

   set_equipment_status(equipment[0].name, "Ready for running", "var(--mgreen)");
   
   return SUCCESS;
}

/*-- Pause Run -----------------------------------------------------*/

INT pause_run(INT run_number, char *error)
{
   mudaq::DmaMudaqDevice & mu = *mup;
   
//   uint32_t datagen_setup = mu.read_register_rw(DATAGENERATOR_REGISTER_W);
//   datagen_setup = UNSET_DATAGENERATOR_BIT_ENABLE(datagen_setup);
//   mu.write_register_wait(DATAGENERATOR_REGISTER_W, datagen_setup,1000);

   // disable DMA
   mu.disable(); // Marius Koeppel: not sure if this works
   
   set_equipment_status(equipment[0].name, "Paused", "var(--myellow)");
   
   return SUCCESS;
}

/*-- Resume Run ----------------------------------------------------*/

INT resume_run(INT run_number, char *error)
{
   mudaq::DmaMudaqDevice & mu = *mup;
   
//   uint32_t datagen_setup = mu.read_register_rw(DATAGENERATOR_REGISTER_W);
//   datagen_setup = SET_DATAGENERATOR_BIT_ENABLE(datagen_setup);
//   mu.write_register_wait(DATAGENERATOR_REGISTER_W, datagen_setup,1000);

   // enable DMA
   mu.enable_continous_readout(0); // Marius Koeppel: not sure if this works
   
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

INT check_event(volatile uint32_t * buffer, uint32_t idx_eoe, bool rp_before_wp)
{
    // rp_before_wp no event check here ...
    if ( rp_before_wp ) return 0;

    // check if the event is good
    EVENT_HEADER* eh=(EVENT_HEADER*)(&buffer[((idx_eoe+1)*8+1)%dma_buf_nwords]);
    BANK_HEADER* bh=(BANK_HEADER*)(&buffer[((idx_eoe+1)*8+5)%dma_buf_nwords]);
    BANK32* ba=(BANK32*)(&buffer[((idx_eoe+1)*8+7)%dma_buf_nwords]);

    if ( eh->event_id != 0x0 ) return -1;
    if ( eh->trigger_mask != 0x1 ) return -1;
    if ( bh->flags != 0x11 ) return -1;
    //if ( ba->type != 0x6 ) return -1;

    printf("EID=%4.4x TM=%4.4x SERNO=%8.8x TS=%8.8x EDsiz=%8.8x\n",eh->event_id,eh->trigger_mask,eh->serial_number,eh->time_stamp,eh->data_size);
    printf("DAsiz=%8.8x FLAG=%8.8x\n",bh->data_size,bh->flags);
//    printf("BAname=%8.8x TYP=%8.8x BAsiz=%8.8x\n",ba->name,ba->type,ba->data_size);

    return 0;
}


/*-- Event readout -------------------------------------------------*/

INT read_stream_thread(void *param)
{
   // we are at mu.last_written_addr() ...  ask for a new bunch of x 256-bit words
   // get mudaq and set readindex to last written addr
   mudaq::DmaMudaqDevice & mu = *mup;
   //readindex = mu.last_written_addr()+1;
/* ---KB
   EVENT_HEADER *pEventHeader;
*/
   uint32_t* pdata;
   // dummy data
   uint32_t SERIAL = 0x00000001;
   uint32_t TIME = 0x00000001;
   bool use_dmmy_data = false;
   // dummy data
   uint32_t lastWritten = 0;
   uint32_t lastEndOfEvent = 0;
   int status;

   // tell framework that we are alive
   signal_readout_thread_active(0, TRUE);
   
   // obtain ring buffer for inter-thread data exchange
   int rbh = get_event_rbh(0);
   bool starting=false;
   while (is_readout_thread_enabled()) {
      
      // obtain buffer space
      status = rb_get_wp(rbh, (void **)&pdata, 10);

      // just sleep and try again if buffer has no space
      if (status == DB_TIMEOUT) {
         set_equipment_status(equipment[0].name, "Buffer full", "var(--myellow)");
         //TODO: throw data here?
         //readindex = ((mu.last_endofevent_addr() + 1) * 8) % dma_buf_nwords;
         continue;
      }

      if (status != DB_SUCCESS){
         cout << "!DB_SUCCESS" << endl;
         break;
      }

      // don't readout events if we are not running
      if (run_state != STATE_RUNNING) {
        set_equipment_status(equipment[0].name, "Not running", "var(--myellow)");
        //cout << "!STATE_RUNNING" << endl;
        ss_sleep(100);
        //TODO: signalling from main thread?
        continue;
      }


      // dummy data
      if (use_dmmy_data == true) {
          uint32_t dma_buf_dummy[48];

          for (int i = 0; i<2; i++) {
          // event header
          dma_buf_dummy[0+i*24] = 0x00010000; // Trigger and Event ID
          dma_buf_dummy[1+i*24] = SERIAL; // Serial number
          dma_buf_dummy[2+i*24] = TIME; // time
          dma_buf_dummy[3+i*24] = 24*4; // event size
          dma_buf_dummy[4+i*24] = 24*4-4*4; // all bank size
          dma_buf_dummy[5+i*24] = 0x11; // flags
          // bank 0
          dma_buf_dummy[6+i*24] = 0x0; // bank name
          dma_buf_dummy[7+i*24] = 0x6; // bank type TID_DWORD
          dma_buf_dummy[8+i*24] = 0x3*4; // data size
          dma_buf_dummy[9+i*24] = 0xAFFEAFFE; // data
          dma_buf_dummy[10+i*24] = 0xAFFEAFFE; // data
          dma_buf_dummy[11+i*24] = 0xAFFEAFFE; // data
          // bank 1
          dma_buf_dummy[12+i*24] = 0x1; // bank name
          dma_buf_dummy[13+i*24] = 0x6; // bank type TID_DWORD
          dma_buf_dummy[14+i*24] = 0x3*4; // data size
          dma_buf_dummy[15+i*24] = 0xAFFEAFFE; // data
          dma_buf_dummy[16+i*24] = 0xAFFEAFFE; // data
          dma_buf_dummy[17+i*24] = 0xAFFEAFFE; // data
          // bank 2
          dma_buf_dummy[18+i*24] = 0x2; // bank name
          dma_buf_dummy[19+i*24] = 0x6; // bank type TID_DWORD
          dma_buf_dummy[20+i*24] = 0x3*4; // data size
          dma_buf_dummy[21+i*24] = 0xAFFEAFFE; // data
          dma_buf_dummy[22+i*24] = 0xAFFEAFFE; // data
          dma_buf_dummy[23+i*24] = 0xAFFEAFFE; // data
          SERIAL += 1;
          TIME += 1;
          }

          volatile uint32_t * dma_buf_volatile;
          dma_buf_volatile = dma_buf_dummy;

          copy_n(&dma_buf_volatile[0], 48, pdata);
          for (int i = 0; i<48; i++){
              cout << hex << pdata[i] << endl;
          }

          EVENT_HEADER* eh=(EVENT_HEADER*)(&pdata[0]);
          BANK_HEADER* bh=(BANK_HEADER*)(&pdata[4]);
          BANK32* ba=(BANK32*)(&pdata[6]);
          printf("EID=%4.4x TM=%4.4x SERNO=%8.8x TS=%8.8x EDsiz=%8.8x\n",eh->event_id,eh->trigger_mask,eh->serial_number,eh->time_stamp,eh->data_size);
          printf("DAsiz=%8.8x FLAG=%8.8x\n",bh->data_size,bh->flags);
          printf("BAname=%8.8x TYP=%8.8x BAsiz=%8.8x\n",ba->name,ba->type,ba->data_size);
          pdata+=sizeof(dma_buf_dummy);
          rb_increment_wp(rbh, sizeof(dma_buf_dummy));
          ss_sleep(1000);
          continue;
      }


      if (mu.last_written_addr() == 0) continue;
      if (mu.last_written_addr() == lastlastWritten) continue;
      if (mu.last_written_addr() == lastWritten) continue;

      lastWritten = mu.last_written_addr();
      lastEndOfEvent = mu.last_endofevent_addr();

      // not so sure if we need this
      if(lastWritten==readindex) continue;


     // in the FPGA the endofevent is one off, since it can be that
     // the end of event does not fit into the 4kB anymore so we have
     // to check this here. Also the endofevent is in 256 bit words
     // so we have to multiply by 8 to get to 32 bit words
     // here we check if the lastWritten is aligned with the end of event
     // this is not really a problem but later we need to check somehow if
     // we are at the end of the event so for now we continue if they are equal
     if (((lastEndOfEvent+1)*8)%dma_buf_nwords == lastWritten) {
         ss_sleep(100);
         continue;
     }

     // only to make it save that we are at the end. Sometimes it fails and
     // the end of event is off so we would then take the next one
     if (((dma_buf[((lastEndOfEvent+1)*8)%dma_buf_nwords] == 0xAFFEAFFE) or
             (dma_buf[((lastEndOfEvent+1)*8)%dma_buf_nwords] == 0x0000009c)) and
         (dma_buf[((lastEndOfEvent+1)*8+1)%dma_buf_nwords] == 0x00010000)
             ){

         if(readindex < ((lastEndOfEvent+1)*8)%dma_buf_nwords){
            if ( check_event(dma_buf, lastEndOfEvent, false) != 0 ) continue;

            //WP before RP. Complete copy
            size_t wlen = ((lastEndOfEvent+1)*8)%dma_buf_nwords - readindex; // len in 32 bit words
            copy_n(&dma_buf[readindex], wlen, pdata);
            pdata += wlen;
            readindex += wlen+1;
            readindex = readindex%dma_buf_nwords;
            rb_increment_wp(rbh, wlen);
         }else{
            if ( check_event(dma_buf, lastEndOfEvent, true) != 0 ) continue;

            //RP before WP. May wrap
            //copy with wrapping
            //#1
            copy_n(&dma_buf[readindex],(dma_buf_nwords-readindex),pdata); // len in 32 bit words
            pdata += (dma_buf_nwords-readindex);
            //#2
            readindex=0;
            size_t wlen = ((lastEndOfEvent+1)*8)%dma_buf_nwords; // len in 32 bit words
            copy_n(&dma_buf[readindex], wlen, pdata);
            pdata += wlen;
            rb_increment_wp(rbh, (wlen + dma_buf_nwords - readindex));
            readindex += wlen+1;
            readindex = readindex%dma_buf_nwords;
          }
     }
   }
   // tell framework that we finished
   signal_readout_thread_active(0, FALSE);
   return 0;
}
