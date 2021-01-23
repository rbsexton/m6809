run: obj_dir/Vm6809_integration
	obj_dir/Vm6809_integration +trace | head -100

obj_dir/Vm6809_integration: ../m6809_integration.v sim_main.cpp
	verilator -Wall --trace -I..  --cc m6809_integration.v --exe sim_main.cpp
	make -C obj_dir -j -f Vm6809_integration.mk Vm6809_integration
