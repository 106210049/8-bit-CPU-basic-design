"""
CPU assembler 

History
-------
+---------+---------+-----------------------+----------------------------------+
| Version | Date    | Author                | Description                      |
+---------+---------+-----------------------+----------------------------------+
| v0p1    | 230714  | duytrinh              | First version                    |
|         |         |                       |                                  |
+---------+---------+-----------------------+----------------------------------+

Notes
-----
- This assembler does 2 round of compilation:
  - Sweeps through the commands to mark the labels' address
  - Compile each commands to generate binary code

Limitation
----------
- The behavior in "Note" section is infficiency because we need 2 rounds for translating the code. Idea to improve:
  - When seeing an undefined label, start storing commands from that point to temporary memory.
  - When seeing the label, replace the undefined one and print out binary code to output file. Flush the temporary memory.
  - When there are more than 1 undefined label:
    - If the defined label is the first one, print out the binary until seeing undefined one again. Flush memory to that point.
    - If the defined label is not the first one, just replace it and continue.

"""
import logging
import numpy as np
import re
import getopt
import sys

options, remainder = getopt.getopt(sys.argv[1:], 'vi:o:', ['verbose','input=','output='])

print ('OPTIONS :', options)

verbose = 0

for opt, arg in options:
  if opt in ('-v', '--verbose'):
    verbose = 1
  elif opt in ('-i', '--input'):
    fin = arg
  elif opt in ('-o', '--output'):
    fout = arg

# Command table
# | Command | Length |   7   |   6   |   5   |   4   |  3:2  |  1:0  | Description                            |
# | :------ | :----- | :---: | :---: | :---: | :---: | :---: | :---: | :-------------- |
# | ADD     | 1      |   1   |   0   |   0   |   0   |  RA   |  RB   | ADD RA and RB then put result into RB  |
# | SHR     | 1      |   1   |   0   |   0   |   1   |  RA   |  RB   | SHIFT RA LEFT them put result into RB  |
# | SHL     | 1      |   1   |   0   |   1   |   0   |  RA   |  RB   | SHIFT RA RIGHT them put result into RB |
# | NOT     | 1      |   1   |   0   |   1   |   1   |  RA   |  RB   | NOT RA then put result into RB         |
# | AND     | 1      |   1   |   1   |   0   |   0   |  RA   |  RB   | AND RA with RB then put result into RB |
# | OR      | 1      |   1   |   1   |   0   |   1   |  RA   |  RB   | OR RA with RB then put result into RB  |
# | XOR     | 1      |   1   |   1   |   1   |   0   |  RA   |  RB   | XOR RA with RB then put result into RB |
# | CMP     | 1      |   1   |   1   |   1   |   1   |  RA   |  RB   | COMPARE RA with RB                     |
# | LD      | 1      |   0   |   0   |   0   |   0   |  RA   |  RB   | LOAD from RAM address in RA to register RB |
# | ST      | 1      |   0   |   0   |   0   |   1   |  RA   |  RB   | STORE RB to RAM address in RA              |
# | DATA    | 2      |   0   |   0   |   1   |   0   |  NA   |  RB   | LOAD 8 bits in next address into RB        |
# | JMPR    | 1      |   0   |   0   |   1   |   1   |  NA   |  RB   | JUMP TO address in RB                      |
# | JMP     | 2      |   0   |   1   |   0   |   0   |  NA   |  NA   | JUMP TO address in next byte               |
# | JZ      | 2      |   0   |   1   |   0   |   1   |  00   |  01   | JUMP IF answer is zero                     |
# | JE      | 2      |   0   |   1   |   0   |   1   |  00   |  10   | JUMP IF A equals B                         |
# | JA      | 2      |   0   |   1   |   0   |   1   |  01   |  00   | JUMP IF A is larger than B                 |
# | JC      | 2      |   0   |   1   |   0   |   1   |  10   |  00   | JUMP IF CARRY is on                        |
# | JCA     | 2      |   0   |   1   |   0   |   1   |  11   |  00   | JUMP IF CARRY or A larger                  |
# | JCE     | 2      |   0   |   1   |   0   |   1   |  10   |  10   | JUMP IF CARRY or A equal B                 |
# | JCZ     | 2      |   0   |   1   |   0   |   1   |  10   |  01   | JUMP IF CARRY or answer is zero            |
# | JAE     | 2      |   0   |   1   |   0   |   1   |  01   |  10   | JUMP IF A is larger or equal to B          |
# | JAZ     | 2      |   0   |   1   |   0   |   1   |  01   |  01   | JUMP IF A is larger or answer is zero      |
# | JEZ     | 2      |   0   |   1   |   0   |   1   |  00   |  11   | JUMP IF A equals B or answer is zero       |
# | JCAE    | 2      |   0   |   1   |   0   |   1   |  11   |  10   | JUMP IF CARRY or A larger or equal to B    |
# | JCAZ    | 2      |   0   |   1   |   0   |   1   |  11   |  01   | JUMP IF CARRY or A larger or zero          |
# | JCEZ    | 2      |   0   |   1   |   0   |   1   |  10   |  11   | JUMP IF CARRY or A equals B or zero        |
# | JAEZ    | 2      |   0   |   1   |   0   |   1   |  01   |  11   | JUMP IF A larger or equal to B or zero     |
# | JCAEZ   | 2      |   0   |   1   |   0   |   1   |  11   |  11   | JUMP IF CARRY or A larger or equal or zero |
# | CLF     | 1      |   0   |   1   |   1   |   0   |  NA   |  NA   | CLEAR ALL FLAGS |
# | END     | 1      |   1   |   1   |   0   |   0   |  11   |  11   | END             |

cmd_dict = {
    'ADD'  : {'val':'1000'    , 'size':1, 'param_no':2, 'param1_type':'REG' , 'param2_type':'REG' }
  , 'SHR'  : {'val':'1001'    , 'size':1, 'param_no':2, 'param1_type':'REG' , 'param2_type':'REG' }
  , 'SHL'  : {'val':'1010'    , 'size':1, 'param_no':2, 'param1_type':'REG' , 'param2_type':'REG' }
  , 'NOT'  : {'val':'1011'    , 'size':1, 'param_no':2, 'param1_type':'REG' , 'param2_type':'REG' }
  , 'AND'  : {'val':'1100'    , 'size':1, 'param_no':2, 'param1_type':'REG' , 'param2_type':'REG' }
  , 'OR'   : {'val':'1101'    , 'size':1, 'param_no':2, 'param1_type':'REG' , 'param2_type':'REG' }
  , 'XOR'  : {'val':'1110'    , 'size':1, 'param_no':2, 'param1_type':'REG' , 'param2_type':'REG' }
  , 'CMP'  : {'val':'1111'    , 'size':1, 'param_no':2, 'param1_type':'REG' , 'param2_type':'REG' }
  , 'LD'   : {'val':'0000'    , 'size':1, 'param_no':2, 'param1_type':'REG' , 'param2_type':'REG' }
  , 'ST'   : {'val':'0001'    , 'size':1, 'param_no':2, 'param1_type':'REG' , 'param2_type':'REG' }
  , 'DATA' : {'val':'001000'  , 'size':2, 'param_no':2, 'param1_type':'REG' , 'param2_type':'DATA'}
  , 'JMPR' : {'val':'0011'    , 'size':1, 'param_no':1, 'param1_type':'REG' , 'param2_type':np.NaN}
  , 'JMP'  : {'val':'01000000', 'size':2, 'param_no':1, 'param1_type':'ADDR', 'param2_type':np.NaN}
  , 'JZ'   : {'val':'01010001', 'size':2, 'param_no':1, 'param1_type':'ADDR', 'param2_type':np.NaN}
  , 'JE'   : {'val':'01010010', 'size':2, 'param_no':1, 'param1_type':'ADDR', 'param2_type':np.NaN}
  , 'JA'   : {'val':'01010100', 'size':2, 'param_no':1, 'param1_type':'ADDR', 'param2_type':np.NaN}
  , 'JC'   : {'val':'01011000', 'size':2, 'param_no':1, 'param1_type':'ADDR', 'param2_type':np.NaN}
  , 'JCA'  : {'val':'01011100', 'size':2, 'param_no':1, 'param1_type':'ADDR', 'param2_type':np.NaN}
  , 'JCE'  : {'val':'01011010', 'size':2, 'param_no':1, 'param1_type':'ADDR', 'param2_type':np.NaN}
  , 'JCZ'  : {'val':'01011001', 'size':2, 'param_no':1, 'param1_type':'ADDR', 'param2_type':np.NaN}
  , 'JAE'  : {'val':'01010110', 'size':2, 'param_no':1, 'param1_type':'ADDR', 'param2_type':np.NaN}
  , 'JAZ'  : {'val':'01010101', 'size':2, 'param_no':1, 'param1_type':'ADDR', 'param2_type':np.NaN}
  , 'JEZ'  : {'val':'01010011', 'size':2, 'param_no':1, 'param1_type':'ADDR', 'param2_type':np.NaN}
  , 'JCAE' : {'val':'01011110', 'size':2, 'param_no':1, 'param1_type':'ADDR', 'param2_type':np.NaN}
  , 'JCAZ' : {'val':'01011101', 'size':2, 'param_no':1, 'param1_type':'ADDR', 'param2_type':np.NaN}
  , 'JCEZ' : {'val':'01011011', 'size':2, 'param_no':1, 'param1_type':'ADDR', 'param2_type':np.NaN}
  , 'JAEZ' : {'val':'01010111', 'size':2, 'param_no':1, 'param1_type':'ADDR', 'param2_type':np.NaN}
  , 'JCAEZ': {'val':'01011111', 'size':2, 'param_no':1, 'param1_type':'ADDR', 'param2_type':np.NaN}
  , 'CLF'  : {'val':'01100000', 'size':1, 'param_no':0, 'param1_type':np.NaN, 'param2_type':np.NaN}
  , 'END'  : {'val':'11001111', 'size':1, 'param_no':0, 'param1_type':np.NaN, 'param2_type':np.NaN}
}
reg_dict = {'R0':0, 'R1':1, 'R2':2, 'R3':3}

label_dict = {} 

lvl = logging.WARNING
if verbose==1:
  lvl = logging.DEBUG
logging.basicConfig(level=lvl,
                    format='%(asctime)s %(name)-12s %(levelname)-8s %(message)s',
                    datefmt='%m-%d %H:%M')
#                    filename='log/'+logfile,
#                    filemode='w')
logger = logging.getLogger('log')


def err_msg(code, param_l, line_no):
  if code==1:
    raise Exception("[E1] : Unsupported {} in line {}".format(param_l[0], line_no))
  if code==2:
    raise Exception("[E2] : The number of parameters {} is unexpected, line {}. Expected {}".format(param_l[0], line_no, param_l[1]))
  if code==3:
    raise Exception("[E3] : The parameter {} value is unexpected in line {}".format(param_l[0], line_no))

def param_cvt(cmd, param, param_no, line_no, label_dict, cmd_sweep):
  """Convert parameter to binary

  Parameters
  ----------
  cmd : str
    Current command for the parameter
  param: obj
    Can be number, string, this is the param to convert
  param_no: int
    The index of the parameter to check param type
  line_no: int
    The index of current line in the input file, for logger
  label_dict: dict
    Dictionary that store labels and their values
  cmd_sweep: int
    Only sweep command for label storage (1) or generate binary file (0)

  Return
  ------
  param: int
    Adress increasing step after this convert
  type: int
    Normal type inject to command (0) or special type should be in other byte (1)
  """
  param_type = 'param'+str(param_no)+"_type"
  if cmd_sweep==1:
    if ((cmd_dict[cmd][param_type]=='DATA')|(cmd_dict[cmd][param_type]=='ADDR')):
      return {'param':format(0, '08b'), 'type':1}
    else:
      return {'param':format(0, '08b'), 'type':0}
  else:
    if (cmd_dict[cmd][param_type]=='REG'):
      if param in reg_dict.keys():
        return {'param':format(reg_dict[param], '02b'), 'type':0}
      else:
        err_msg(3, [param], line_no)
    elif ((cmd_dict[cmd][param_type]=='DATA')|(cmd_dict[cmd][param_type]=='ADDR')):
      try:
        if (param[:2]=="0x"):
          param = int(param, 16)
        elif (param[:2]=="0b"):
          param = int(param, 2)
        else:
          param = int(param)
        return {'param':format(param, '08b'), 'type':1}
      except:
        if (cmd_dict[cmd][param_type]=='ADDR'):
          if param in label_dict:
            return {'param':format(label_dict[param], '08b'), 'type':1}
          else:
            err_msg(3, [param], line_no)
        else:
          err_msg(3, [param], line_no)

def cmd_cvt(cmd_l, line_no, label_dict, cmd_sweep, dout):
  """Convert command to binary

  Parameters
  ----------
  cmd_l : list
    List that contain command in the first item, parameters in the next ones
  line_no: int
    Current line in the input, for logger
  label_dict: dict
    Label with address dictionary for param convert
  cmd_sweep: int
    Only sweep command for label storage (1) or generate binary file (0)

  Return
  ------
  Integer
    Adress increasing step after this convert
  """

  cmd = cmd_l[0]
  cmd_bin = ''
  data_bin = ''
  adr_jump = 1;
  if cmd in cmd_dict.keys():
    if (len(cmd_l)-1==cmd_dict[cmd]['param_no']):
      cmd_bin += cmd_dict[cmd]['val']
      param_no = 1
      for param in cmd_l[1:]:
        param_rsl = param_cvt(cmd, param, param_no, line_no, label_dict, cmd_sweep)
        if (param_rsl['type']==1):
          data_bin = param_rsl['param']
          adr_jump = 2
        else:
          cmd_bin += param_rsl['param']
        param_no += 1
      if cmd_sweep==0:
        logger.debug(cmd_bin) 
    else :
      err_msg(2, [len(cmd_l)-1, cmd_dict[cmd]['param_no']], line_no)
  else:
    err_msg(1, [cmd], line_no)
  
  if (adr_jump==2)&(cmd_sweep==0):
    logger.debug(data_bin)
  
  if cmd_sweep==0:
    cmd_bin  = int(cmd_bin , 2)
    cmd_bin = hex(cmd_bin)[2:]
    dout.write(cmd_bin+"\n")
    if adr_jump==2:
      data_bin = int(data_bin, 2)
      data_bin = hex(data_bin)[2:]
      dout.write(data_bin+"\n")
  
  if cmd_sweep==0:
    logger.debug(adr_jump)
  return (adr_jump)

def file_process(fin, cmd_sweep):
  try:
    din = open(fin, 'r')
  except:
    logger.error("Can't open file {}".format(fin))
    sys.exit(1)
  
  dout = ''
  if cmd_sweep == 0:
    dout = open(fout, 'w')

  line_no = 0
  cur_addr = 0
  for line in din:
    line_no += 1
    line = re.sub(r'\s+:', ':', line)
    line = re.sub(r'\#.*', '', line)
    line = line.strip()
    cmd = line.split()
    if len(cmd)==0:
      if cmd_sweep==0:
        logger.debug("Blank line, skip")
      continue
    if cmd_sweep==0:
      logger.debug(cmd)
    if (cmd[0][-1]==":"):
      if cmd_sweep==0:
        logger.debug("Label {}".format(cmd[0][:-1]))
      if cmd_sweep==1:
        label_dict[cmd[0][:-1]] = cur_addr
      cur_addr += cmd_cvt(cmd[1:], line_no, label_dict, cmd_sweep, dout)
    else:
      cur_addr += cmd_cvt(cmd, line_no, label_dict, cmd_sweep, dout)
  din.close()
  if (cmd_sweep==0):
    dout.close()


def main():
  file_process(fin, 1)
  file_process(fin, 0)

main()