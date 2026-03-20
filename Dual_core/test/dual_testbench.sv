`include "../test/header.svh"

module dual_testbench;
    timeunit 1ns; timeprecision 1ps;
    
    localparam CLK_PERIOD = 4ns;

    logic sys_clk, reset;
    int lines;
    bit start_simulation, end_simlulation;
    dual_core_model dual_core_t;
    logic [63:0] received_cpu_rf[32], received_fpu_rf[32];
    logic [255:0] received_mem_data[32];
    bit err_count;
    integer report_handle;

    dual_top #(.NO_RESERV(16)) DUT (
        .clk(sys_clk),
        .rst_n(reset)
    );

    initial begin: initial_task_calling
        initial_task();
    end

    initial begin: comparing_tasks
        wait (end_simlulation);

        received_cpu_rf   = DUT.dual_core_inst.dual_core.CPU.rf.registers[0];
        received_fpu_rf   = DUT.dual_core_inst.dual_core.FPU.fp_regfile.regs[0];
        foreach (received_mem_data[i]) begin
            received_mem_data[i] = DUT.dual_core_inst.dual_core.MMU.D_Cache.d_data_array.data[i][0];
        end

        cpu_rf_compare(received_cpu_rf, dual_core_t.cpu_rf);
        fpu_rf_compare(received_fpu_rf, dual_core_t.fpu_rf);
        mem_data_compare(received_mem_data, dual_core_t.data_mem);

        `disp(("======== Finished comparing tasks with %0d error(s)========", err_count));
    end

    task automatic initial_task();
        fork
            begin: create_log
                report_handle = $fopen($sformatf("./my_work_dir/dual_testbench.log"), "w");
            end
            begin: clock_generate
                sys_clk = 1'b0;
                forever begin
                    #(CLK_PERIOD/2);
                    sys_clk = ~sys_clk;
                end
            end
            begin: reading_imem
                $readmemh("../mem/ALL_test.mem", DUT.sdram_inst.i_mem_inst.mem);
            end
            begin: dump_waveform
                $dumpfile("dump.vcd");
                $dumpvars(0, dual_testbench);
            end
            begin: reset_generate
                #(CLK_PERIOD) reset = 1'b1;
                #(CLK_PERIOD) reset = 1'b0;
                #(3*CLK_PERIOD) reset = 1'b1;
                start_simulation = 1'b1;
            end
            begin: ending_simulation
                string filename = "../mem/ALL_test.mem";
                lines = count_lines(filename);
                
                `disp(("There are %0d instructions in this simulation\n", lines));
                
                wait (start_simulation);
                
                repeat (lines*36) begin
                    @(posedge sys_clk);
                end

                reset = 1'b0;
                end_simlulation = 1'b1;
                
                repeat (50) begin
                    @(posedge sys_clk);
                end

                $finish;
            end
            begin: start_reference_model
                #1ps;
                dual_core_t = new(lines, report_handle);
                wait (start_simulation);
                dual_core_t.main_phase();
            end
        join
    endtask: initial_task

    function automatic int count_lines(string filename);
        int fd;
        int line_count;
        string line;
    
        line_count = 0;
    
        fd = $fopen(filename, "r");
        if (fd == 0) begin
            $error("Cannot open file: %s", filename);
            return -1;
        end
    
        while (!$feof(fd)) begin
            if ($fgets(line, fd))
                line_count++;
        end
    
        $fclose(fd);
        return line_count;
    endfunction: count_lines

    function automatic void cpu_rf_compare(logic [63:0] rtl_cpu[32], logic [63:0] model_cpu[32]);
        `disp(("Entering cpu_rf_compare task"));
        
        foreach (rtl_cpu[i]) begin
            if (rtl_cpu[i] !== model_cpu[i]) begin
                `disp(("\t[TB ERROR] Wrong value at cpu_rf['h%0h] === Received data: 'h%0h, Expected data: 'h%0h", i, rtl_cpu[i], model_cpu[i]));
                err_count++;
            end
            else begin
                `disp(("\tCorrect value at cpu_rf['h%0h] = 'h%h", i, rtl_cpu[i]));
            end
        end
    endfunction: cpu_rf_compare

    function automatic void fpu_rf_compare(logic [63:0] rtl_fpu[32], logic [63:0] model_fpu[32]);
        int unsigned ulp;
        int tol;
    
        `disp(("Entering fpu_rf_compare task"));
    
        foreach (rtl_fpu[i]) begin
            ulp = ulp_diff(rtl_fpu[i], model_fpu[i]);
    
            tol = 4;
    
            if (ulp > tol) begin
                `disp(("\t[TB ERROR] Wrong value at fpu_rf['h%0h] === Received data: 'h%h, Expected data: 'h%h, ULP = 'd%0d", i, rtl_fpu[i], model_fpu[i], ulp));
                err_count++;
            end
            else begin
                `disp(("\tCorrect value at fpu_rf['h%0h] = 'h%h, ULP = 'd%0d, 'h%h", i, rtl_fpu[i], ulp, model_fpu[i]));
            end
        end
    endfunction: fpu_rf_compare

    function automatic void mem_data_compare(logic [255:0] rtl_mem[32], logic [63:0] model_mem[128]);
        logic [63:0] rtl_word;
        int unsigned ulp;
        int tol;
        int line, w;
        int idx;
        int i;
    
        tol = 4;
    
        `disp(("Entering mem_data_compare task"));
    
        for (line = 0; line < 32; line++) begin
            i = 0;
            for (w = 3; w >= 0; w--) begin
                idx = line*4 + i;
                rtl_word = rtl_mem[line][w*64 +: 64];
    
                ulp = ulp_diff(rtl_word, model_mem[idx]);
    
                if (ulp > tol) begin
                    `disp(("\t[TB ERROR] Wrong value at mem['h%0h] === Received data: 'h%h, Expected data: 'h%h, ULP = 'd%0d", idx, rtl_word, model_mem[idx], ulp));
                    err_count++;
                end
                else begin
                    `disp(("\tCorrect value at mem['h%0h] = 'h%h, ULP = 'd%0d", idx, rtl_word, ulp));
                end
                i++;
            end
        end
    endfunction: mem_data_compare
    
    function automatic longint ulp_diff(logic [63:0] a, logic [63:0] b);
        longint ia, ib;
    
        ia = longint'(a);
        ib = longint'(b);
    
        if (ia < 0) ia = 64'h8000_0000_0000_0000 - ia;
        if (ib < 0) ib = 64'h8000_0000_0000_0000 - ib;
    
        ulp_diff = (ia > ib) ? (ia - ib) : (ib - ia);
    endfunction

endmodule: dual_testbench