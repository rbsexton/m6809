#include <iostream>

#include "Vm6809_integration_m6809_core.h"
#include "Vm6809_integration_m6809_integration.h"
#include "Vm6809_integration.h"


#include "verilated.h"

int main(int argc, char **argv, char **env)
{
        Verilated::commandArgs(argc, argv);
        Vm6809_integration *top = new Vm6809_integration;

        top->reset_b = 0;
        top->clk     = 0;        
        top->eval();
        
      
        for ( int i = 0; i < 1000; i++ ) {
          if (top->clk)
              printf("Addr: %04x\n", top->m6809_integration->ucore->get_core_addr());
              
                  // std::cout << " Addr:" << top->m6809_integration->ucore->get_core_addr() << std::endl;
          top->clk ^= 1;
          top->eval();
                  
        }
        
        //while (!Verilated::gotFinish())
        //{
        //        if (top->clk)
        //                std::cout << " Line" << top->m6809_integration->ucore->get_core_addr() << std::endl;
        //        top->clk ^= 1;
        //        top->eval();
        // }
        delete top;
        exit(0);
}
