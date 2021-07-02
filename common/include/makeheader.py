# makeheader.py
# parse a vhdl file with a register map and 
# produce a C/C++ header file with corresponding macros
# Niklaus Berger, 1.3.2017, niberger@uni-mainz.de

import re
import datetime
import sys

def main(fname, outname):
    infile = open (fname, "r")
    lines = infile.readlines()
    infile.close()
    
    pkgindex = -1
    pkgname = ''
    for idx, line in enumerate(lines):
        line = line.strip().upper()
        # ignore VHDL comments 
        if re.search(r'--', line) is not None:
            continue
        
        match = re.search(r'PACKAGE (\w+) IS', line)
        if match is not None:
            print(match.group(1))
            pkgname = match.group(1)
            pkgindex = idx
            break
            
    if pkgindex == -1:
        print('No VHDL package found, aborting!')
        return
    
    del lines[0:pkgindex]
    
    print('Generating ' + outname + '\n')
    file = open(outname, "w")
    file.write(r'/************************************************')
    file.write('\n')
    file.write(r'* Register map header file ')
    file.write('\n')
    file.write(r'* Automatically generated from ' + fname)
    file.write('\n')
    file.write(r'* On ' + datetime.datetime.now().isoformat())
    file.write('\n')
    file.write(r'************************************************/')
    file.write('\n')
    file.write('\n')
    file.write('#ifndef ' + pkgname + '__H \n')
    file.write('#define ' + pkgname + '__H \n')
    file.write('\n')
    file.write('\n')
    for idx, line in enumerate(lines):
        line = line.strip().upper()
        line = " ".join(line.split())
        # ignore VHDL comments 
        if re.search(r'--', line) is not None:
            continue
            
        # match stuff like "constant LED_REGISTER_W :  integer := 16#00#;"	
        match = re.search(r'CONSTANT (\w+_REGISTER\w+) : INTEGER := 16#(\w+)#;', line)
        if match is not None:
            file.write('#define ' + match.group(1) + '\t\t' + '0x' + match.group(2).lower() + '\n')
            continue
        

        # match stuff like "constant DDR3_CONTROL_W :  integer := 16#20#;"
        if len(line.split()) > 1:
            if line.split()[1].endswith("_W") or line.split()[1].endswith("_R") or line.split()[1].endswith("_RW"):
                file.write('#define ' + line.split()[1] + '\t\t' + '0x' + line.split()[-1].split("#")[1].lower() + '\n')
                continue

        # match stuff like "constant SWB_STREAM_FIFO_FULL_PIXEL_CNT :  integer := 16#20#;"
        if len(line.split()) > 1:
            if line.split()[1].endswith("_CNT"):
                file.write('#define ' + line.split()[1] + '\t\t' + '0x' + line.split()[-1].split("#")[1].lower() + '\n')
                continue
            
        # match stuff like "constant RESET_BIT_ALL :  integer := 0;"	
        match = re.search(r'CONSTANT (\w+_BIT\w+) : INTEGER := (\w+);', line)
        if match is not None:
            file.write('#define ' + match.group(1) + '\t\t' + match.group(2) + '\n')
            file.write('#define GET_' + match.group(1) + '(REG) ((REG>>' + match.group(2) + ')& 0x1) \n') 
            file.write('#define SET_' + match.group(1) + '(REG) ((1<<' + match.group(2) + ')| REG) \n')
            file.write('#define UNSET_' + match.group(1) + '(REG) ((~(1<<' + match.group(2) + ')) & REG) \n')
            continue
        else:
            if len(line.split()) > 1:
                if line.split()[1].endswith("_BIT"):
                    file.write('#define ' + line.split()[1] + '\t\t' + line.split()[-1].split(";")[0].lower() + '\n')
                    file.write('#define GET_' + line.split()[1] + '(REG) ((REG>>' + line.split()[-1].split(";")[0].lower() + ')& 0x1) \n')
                    file.write('#define SET_' + line.split()[1] + '(REG) ((1<<' + line.split()[-1].split(";")[0].lower() + ')| REG) \n')
                    file.write('#define UNSET_' + line.split()[1] + '(REG) ((~(1<<' + line.split()[-1].split(";")[0].lower() + '))& REG) \n')
                    continue
            
        # match stuff like "subtype DIPSWITCH_RANGE is integer range 7 downto 0;"
        match = re.search(r'SUBTYPE (\w+_RANGE) IS INTEGER RANGE (\w+) DOWNTO (\w+);', line)
        if match is not None:
            file.write('#define ' + match.group(1) + '_HI\t\t' + match.group(2) + '\n')
            file.write('#define ' + match.group(1) + '_LOW\t\t' + match.group(3) + '\n')
            rsize = int(match.group(2)) - int(match.group(3)) + 1
            if rsize <= 32:
                file.write('#define GET_' + match.group(1) + '(REG) ((REG>>' + match.group(3) + r')&' + hex(2**rsize-1) + ') \n') 
                file.write('#define SET_' + match.group(1) + '(REG, VAL) ((REG & (~(' + hex(2**rsize-1) + '<< ' + match.group(3) 
                + '))) | ((VAL & '+ hex(2**rsize-1) + ')<< ' +match.group(3) + '))  \n')	
            continue
            
        # match stuff like "constant PACKET_TYPE_SC_READ                   : std_logic_vector(1 downto 0)     := "10";"	
        match = re.search(r'CONSTANT (\w+)\s+:\s+STD_LOGIC_VECTOR\((\d+) DOWNTO (\d+)\)\s+:=\s+\"(\d+)\";', line)
        if match is not None:
            nbits = int (match.group(2)) - int(match.group(3)) + 1
            num = int(match.group(4),2)
            file.write('#define ' + match.group(1) + '\t\t' + hex(num) + '\n')
            continue        
                
            
    file.write('\n')
    file.write('\n')
    file.write('#endif  //#ifndef ' + pkgname + '__H \n')
    file.close()

main(sys.argv[1], sys.argv[2]);
