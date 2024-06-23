# USER DEFINE
# Syntax
# dict set wave <hier> <depth>
set top $::env(SIM_TB)
set wave_file $::env(WAVE_FILE)
dict set wave $top 0

# DON'T TOUCH
scope $top
# Storing waveforms
dump -file $wave_file
dict for {hier depth} $wave {
  echo "wave.tcl INFO: Dump wave $hier depth $depth"
  dump -add $hier -depth $depth -fsdb_opt +all
#  dump -filter
}
#dump -autoflush on
run

