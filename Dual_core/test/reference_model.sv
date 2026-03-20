class dual_core_model;
    logic [31:0] instr_mem[512];
    logic [63:0] data_mem[128];
    logic [63:0] cpu_rf[32];
    logic [63:0] fpu_rf[32];
    int pc;
    int end_pc;
    int lines;
    string filename = "../mem/ALL_test.mem";
    bit no_cpu, no_fpu;
    integer report_handle;

    function new(int lines=0, integer report_handle=0);
        this.lines         = lines;
        this.report_handle = report_handle;
        instr_mem          = '{default: '0};
        data_mem           = '{default: '0};
        cpu_rf             = '{default: '0};
        fpu_rf             = '{default: '0};
    endfunction: new
    
    function void main_phase();
        end_pc = lines*4;
        $readmemh(filename, instr_mem);
        
        while (pc < end_pc) begin
            logic [31:0] instr;
            pc    = {pc[31:1], 1'b0};
            instr = instr_mem[pc[12:2]];
            `disp(("program counter = 'h%0h - Instruction: 'h%h", pc, instr));
            
            exec_int(instr);
            exec_float(instr);

            if (no_cpu & no_fpu) begin
                `disp(("Invalid instruction at pc = 'h%0h - Instruction: 'h%h", pc, instr));
                pc += 4;
            end
        end

        `disp(("Finished running RV64IMD reference model"));
    endfunction: main_phase

    function void exec_int(
        input logic [31:0] instr
    );
        logic [6:0] opcode, funct7;
        logic [2:0] funct3;
        logic [63:0] result;
        logic [63:0] rs1;
        logic [63:0] rs2;
        bit [63:0] imm;
        bit [5:0] rd_addr, rs1_addr, rs2_addr;
        bit rd_wren;

        opcode   = instr[6:0];
        funct3   = instr[14:12];
        funct7   = instr[31:25];
        rd_addr  = instr[11:7];
        rs1_addr = instr[19:15];
        rs2_addr = instr[24:20];
        rs1      = cpu_rf[rs1_addr];
        rs2      = cpu_rf[rs2_addr];
        imm      = imm_decode(instr, opcode, funct3);

        result = 64'b0;
        no_cpu = 0;

        case (opcode)
            // ----------- OP -----------
            7'b0110011: begin
                rd_wren = 1'b1;
                pc += 4;

                case ({funct7,funct3})
                    {7'b0000000,3'b000}: result = rs1 + rs2; // ADD
                    {7'b0100000,3'b000}: result = rs1 - rs2; // SUB
                    {7'b0000000,3'b111}: result = rs1 & rs2; // AND
                    {7'b0000000,3'b110}: result = rs1 | rs2; // OR
                    {7'b0000000,3'b100}: result = rs1 ^ rs2; // XOR
                    {7'b0000000,3'b001}: result = rs1 << rs2[5:0]; // SLL
                    {7'b0000000,3'b101}: result = rs1 >> rs2[5:0]; // SRL
                    {7'b0100000,3'b101}: result = $signed(rs1) >>> rs2[5:0]; // SRA
                    {7'b0000000,3'b010}: begin // SLT
                        result = ($signed(rs1) < $signed(rs2)) ? 64'd1 : 64'd0;
                    end
                    {7'b0000000,3'b011}: begin // SLTU
                        result = ($unsigned(rs1) < $unsigned(rs2)) ? 64'd1 : 64'd0;
                    end

                    // ---- MUL/DIV ----
                    {7'b0000001,3'b000}: result = rs1 * rs2; // MUL
                    {7'b0000001,3'b001}: begin
                        logic signed [127:0] prod;
                        prod = $signed(rs1) * $signed(rs2);
                        result = prod[127:64]; // MULH
                    end
                    {7'b0000001,3'b010}: begin
                        logic signed [127:0] prod;
                        prod = $signed(rs1) * $unsigned(rs2);
                        result = prod[127:64]; // MULHSU
                    end
                    {7'b0000001,3'b011}: begin
                        logic unsigned [127:0] prod;
                        prod = $unsigned(rs1) * $unsigned(rs2);
                        result = prod[127:64]; // MULHU
                    end
                    {7'b0000001,3'b100}: result = $signed(rs1) / $signed(rs2); // DIV
                    {7'b0000001,3'b101}: result = rs1 / rs2; // DIVU
                    {7'b0000001,3'b110}: result = $signed(rs1) % $signed(rs2); // REM
                    {7'b0000001,3'b111}: result = rs1 % rs2; // REMU
                endcase
            end

            // ---------- OP-W ----------
            7'b0111011: begin
                logic signed [31:0] a, b;
                a = rs1[31:0];
                b = rs2[31:0];
                rd_wren = 1'b1;
                pc += 4;

                case ({funct7,funct3})
                    {7'b0000000,3'b000}: begin
                        logic [31:0] r;
                        r = a+b;
                        result = {{32{r[31]}}, r}; // ADDW
                    end
                    {7'b0100000,3'b000}: begin
                        logic [31:0] r;
                        r = a-b;
                        result = {{32{r[31]}}, r}; // SUBW
                    end
                    {7'b0000000,3'b001}: begin // SLLW
                        logic [31:0] sh, r;
                        sh = rs2[4:0];
                        r = rs1[31:0] << sh;
                        result = {{32{r[31]}},r};
                    end
                    {7'b0000000,3'b101}: begin // SRLW
                        logic [31:0] sh;
                        logic [31:0] r;
                        sh = rs2[4:0];
                        r  = rs1[31:0] >> sh;
                        result = {{32{r[31]}}, r};
                    end
                    {7'b0100000,3'b101}: begin // SRAW
                        logic [31:0] sh;
                        logic signed [31:0] r;
                        sh = rs2[4:0];
                        r  = $signed(rs1[31:0]) >>> sh;
                        result = {{32{r[31]}}, r};
                    end
                    {7'b0000001,3'b000}: begin
                        logic signed [31:0] r;
                        r = a*b;
                        result = {{32{r[31]}}, r}; // MULW
                    end
                    {7'b0000001,3'b100}: begin
                        logic [31:0] r;
                        r = a/b;
                        result = {{32{r[31]}}, r}; // DIVW
                    end
                    {7'b0000001,3'b101}: begin // DIVUW
                        logic [31:0] ua, ub, q;
                        ua = rs1[31:0];
                        ub = rs2[31:0];
                        q  = ua / ub;
                        result = {{32{q[31]}}, q};
                    end
                    {7'b0000001,3'b110}: begin // REMW
                        logic signed [31:0] r;
                        r = a % b;
                        result = {{32{r[31]}}, r};
                    end
                    {7'b0000001,3'b111}: begin // REMUW
                        logic [31:0] ua, ub, r;
                        ua = rs1[31:0];
                        ub = rs2[31:0];
                        r  = ua % ub;
                        result = {{32{r[31]}}, r};
                    end
                endcase
            end

            // ---------- OP-I ----------
            7'b0010011: begin
                rd_wren = 1'b1;
                pc += 4;

                case (funct3)
                    3'b000: begin   // ADDI
                        result = rs1 + imm;
                    end
                    3'b010: begin   // SLTI
                        result = ($signed(rs1) < $signed(imm)) ? 64'd1 : 64'd0;
                    end
                    3'b011: begin   // SLTIU
                        result = ($unsigned(rs1) < $unsigned(imm)) ? 64'd1 : 64'd0;
                    end
                    3'b100: begin   // XORI
                        result = rs1 ^ imm;
                    end
                    3'b110: begin   // ORI
                        result = rs1 | imm;
                    end
                    3'b111: begin   // ANDI
                        result = rs1 & imm;
                    end
                    3'b001: begin   // SLLI
                        if (funct7 == 7'b0000000) begin
                            logic [5:0] sh;
                            sh = instr[25:20];
                            result = rs1 << sh;
                        end
                    end
                    3'b101: begin
                        logic [5:0] sh;
                        sh = instr[25:20];
                        if (funct7 == 7'b0000000) begin
                            result = rs1 >> sh;             // SRLI
                        end 
                        else if (funct7 == 7'b0100000) begin
                            result = $signed(rs1) >>> sh;   // SRAI
                        end
                    end
                endcase
            end

            // ---------- OP-IW ---------
            7'b0011011: begin
                rd_wren = 1'b1;
                pc += 4;

                case (funct3)
                    // ADDIW
                    3'b000: begin
                        logic signed [31:0] r;
                        r = rs1[31:0] + imm[31:0];
                        result = {{32{r[31]}}, r};
                    end
            
                    // SLLIW
                    3'b001: begin
                        if (funct7 == 7'b0000000) begin
                            logic [4:0] sh;
                            logic signed [31:0] r;
                            sh = instr[24:20];
                            r  = rs1[31:0] << sh;
                            result = {{32{r[31]}}, r};
                        end
                    end
            
                    // SRLIW / SRAIW
                    3'b101: begin
                        logic [4:0] sh;
                        sh = instr[24:20];
            
                        if (funct7 == 7'b0000000) begin
                            logic [31:0] r;
                            r = rs1[31:0] >> sh;              // SRLIW
                            result = {{32{r[31]}}, r};
                        end
                        else if (funct7 == 7'b0100000) begin
                            logic signed [31:0] r;
                            r = $signed(rs1[31:0]) >>> sh;   // SRAIW
                            result = {{32{r[31]}}, r};
                        end
                    end
                endcase
            end

            // -------- OP-Load --------
            7'b0000011: begin
                logic [63:0] addr;
                logic [63:0] ld_word;
                
                rd_wren = 1'b1;
                pc += 4;
                addr    = rs1 + imm;
                ld_word = data_mem[addr[5:0]];
            
                case (funct3)
                    3'b000: begin // LB
                        result = {{56{ld_word[7]}}, ld_word[7:0]};
                    end
            
                    3'b001: begin // LH
                        result = {{48{ld_word[15]}}, ld_word[15:0]};
                    end
            
                    3'b010: begin // LW
                        result = {{32{ld_word[31]}}, ld_word[31:0]};
                    end
            
                    3'b011: begin // LD
                        result = ld_word;
                    end
            
                    3'b100: begin // LBU
                        result = {56'b0, ld_word[7:0]};
                    end
            
                    3'b101: begin // LHU
                        result = {48'b0, ld_word[15:0]};
                    end
            
                    3'b110: begin // LWU
                        result = {32'b0, ld_word[31:0]};
                    end
                endcase
            end

            // -------- OP-Store -------
            7'b0100011: begin
                logic [63:0] addr;

                rd_wren = 1'b0;
                addr = rs1 + imm;
                pc += 4;
            
                case (funct3)
                    3'b000: data_mem[addr[5:0]][7:0]   = rs2[7:0];    // SB
                    3'b001: data_mem[addr[5:0]][15:0]  = rs2[15:0];   // SH
                    3'b010: data_mem[addr[5:0]][31:0]  = rs2[31:0];   // SW
                    3'b011: data_mem[addr[5:0]]        = rs2;         // SD
                endcase
            end

            // ------- OP-Branch -------
            7'b1100011: begin
                rd_wren = 1'b0;

                case (funct3)
                    3'b000: begin // BEQ
                        if (rs1 == rs2) begin
                            pc = pc + imm;
                        end
                        else begin
                            pc += 4;
                        end
                    end

                    3'b001: begin // BNE
                        if (rs1 != rs2) begin
                            pc = pc + imm;
                        end
                        else begin
                            pc += 4;
                        end
                    end

                    3'b100: begin // BLT
                        if ($signed(rs1) < $signed(rs2)) begin
                            pc = pc + imm;
                        end
                        else begin
                            pc += 4;
                        end
                    end

                    3'b101: begin // BGE
                        if ($signed(rs1) >= $signed(rs2)) begin
                            pc = pc + imm;
                        end
                        else begin
                            pc += 4;
                        end
                    end

                    3'b110: begin // BLTU
                        if ($unsigned(rs1) < $unsigned(rs2)) begin
                            pc = pc + imm;
                        end
                        else begin
                            pc += 4;
                        end
                    end

                    3'b111: begin // BGEU
                        if ($unsigned(rs1) >= $unsigned(rs2)) begin
                            pc = pc + imm;
                        end
                        else begin
                            pc += 4;
                        end
                    end

                    default: pc += 4;
                endcase
            end

            // LUI
            7'b0110111: begin
                rd_wren = 1'b1;
                result  = imm;
                pc     += 4;
            end

            // AUIPC
            7'b0010111: begin
                rd_wren = 1'b1;
                result  = pc + imm;
                pc     += 4;
            end

            // JAL
            7'b1101111: begin
                rd_wren = 1'b1;
                result  = pc + 4;
                pc      = pc + imm;
            end

            // JALR
            7'b1100111: begin
                if (funct3 != 3'b000) begin
                    pc += 4;
                end 
                else begin
                    rd_wren = 1'b1;
                    result  = pc + 4;
                    pc      = (rs1 + imm) & ~64'd1;
                end
            end

            // NOP
            7'b1111111: begin
                pc += 4;
            end

            default: begin
                no_cpu = 1;
            end
        endcase

        if (rd_wren) begin
            cpu_rf[rd_addr] = result;
        end

    endfunction: exec_int

    function void exec_float(
        input logic [31:0] instr
    );
        logic [6:0] opcode, funct7;
        logic [2:0] funct3;
        logic [4:0] rd, rs1, rs2, rs3;
        logic [63:0] addr;
        logic signed [63:0] imm;
        real f_rs1, f_rs2, f_rs3, f_res;

        opcode = instr[6:0];
        funct3 = instr[14:12];
        funct7 = instr[31:25];
        rd     = instr[11:7];
        rs1    = instr[19:15];
        rs2    = instr[24:20];
        rs3    = instr[31:27];
        
        if (opcode == 7'b0000111) begin
            imm = {{52{instr[31]}}, instr[31:20]};
        end
        else begin
            imm = {{52{instr[31]}}, funct7, rd};
        end

        no_fpu = 0;

        case (opcode)
            // ---------------- FLD ----------------
            7'b0000111: begin
                if (funct3 != 3'b011) begin
                    no_fpu = 1;
                end
                else begin
                    addr = cpu_rf[rs1] + imm;
                    fpu_rf[rd] = data_mem[addr[5:0]];
                    pc += 4;
                end
            end

            // ---------------- FSD ----------------
            7'b0100111: begin
                if (funct3 != 3'b011) begin
                    no_fpu = 1;
                end
                else begin
                    addr = cpu_rf[rs1] + imm;
                    data_mem[addr[5:0]] = fpu_rf[rs2];
                    pc += 4;
                end
            end

            // ----------- FMADD / FMSUB / FNMSUB / FNMADD -----------
            7'b1000011,
            7'b1000111,
            7'b1001011,
            7'b1001111: begin
                f_rs1 = $bitstoreal(fpu_rf[rs1]);
                f_rs2 = $bitstoreal(fpu_rf[rs2]);
                f_rs3 = $bitstoreal(fpu_rf[rs3]);

                case (opcode)
                    7'b1000011: f_res =  (f_rs1 * f_rs2) + f_rs3; // FMADD
                    7'b1000111: f_res =  (f_rs1 * f_rs2) - f_rs3; // FMSUB
                    7'b1001011: f_res = -(f_rs1 * f_rs2) + f_rs3; // FNMSUB
                    7'b1001111: f_res = -(f_rs1 * f_rs2) - f_rs3; // FNMADD
                endcase

                fpu_rf[rd] = $realtobits(f_res);
                pc += 4;
            end

            // ---------------- FP ALU ----------------
            7'b1010011: begin
                f_rs1 = $bitstoreal(fpu_rf[rs1]);
                f_rs2 = $bitstoreal(fpu_rf[rs2]);
                pc += 4;

                case (funct7)
                    // FADD.D
                    7'b0000001: begin
                        f_res = f_rs1 + f_rs2;
                        fpu_rf[rd] = $realtobits(f_res);
                    end

                    // FSUB.D
                    7'b0000101: begin
                        f_res = f_rs1 - f_rs2;
                        fpu_rf[rd] = $realtobits(f_res);
                    end

                    // FMUL.D
                    7'b0001001: begin
                        f_res = f_rs1 * f_rs2;
                        fpu_rf[rd] = $realtobits(f_res);
                    end

                    // FDIV.D
                    7'b0001101: begin
                        f_res = f_rs1 / f_rs2;
                        fpu_rf[rd] = $realtobits(f_res);
                    end

                    // FSQRT.D
                    7'b0101101: begin
                        f_res = $sqrt(f_rs1);
                        fpu_rf[rd] = $realtobits(f_res);
                    end

                    // FSGNJ / FSGNJN / FSGNJX
                    7'b0010001: begin
                        case (funct3)
                            3'b000: fpu_rf[rd] = {fpu_rf[rs2][63], fpu_rf[rs1][62:0]};
                            3'b001: fpu_rf[rd] = {~fpu_rf[rs2][63], fpu_rf[rs1][62:0]};
                            3'b010: fpu_rf[rd] = {fpu_rf[rs1][63] ^ fpu_rf[rs2][63], fpu_rf[rs1][62:0]};
                            default: no_fpu = 1;
                        endcase
                    end

                    // FMIN / FMAX
                    7'b0010101: begin
                        case (funct3)
                            3'b000: fpu_rf[rd] = ($bitstoreal(fpu_rf[rs1]) < $bitstoreal(fpu_rf[rs2])) ? fpu_rf[rs1] : fpu_rf[rs2];
                            3'b001: fpu_rf[rd] = ($bitstoreal(fpu_rf[rs1]) > $bitstoreal(fpu_rf[rs2])) ? fpu_rf[rs1] : fpu_rf[rs2];
                            default: no_fpu = 1;
                        endcase
                    end

                    // FEQ / FLT / FLE
                    7'b1010001: begin
                        case (funct3)
                            3'b010: cpu_rf[rd] = (f_rs1 == f_rs2);
                            3'b001: cpu_rf[rd] = (f_rs1 <  f_rs2);
                            3'b000: cpu_rf[rd] = (f_rs1 <= f_rs2);
                            default: no_fpu = 1;
                        endcase
                    end

                    // FCVT.W.D / FCVT.WU.D / FCVT.L.D / FCVT.LU.D
                    7'b1100001: begin
                        case (instr[24:20])
                            // FCVT.W.D
                            5'b00000: begin
                                longint signed tmp;
                                tmp = $rtoi(f_rs1);
                                cpu_rf[rd] = tmp;
                            end
                    
                            // FCVT.WU.D
                            5'b00001: begin
                                int unsigned tmp;
                                tmp = $rtoi(f_rs1);
                                cpu_rf[rd] = longint'(tmp);
                            end
                    
                            // FCVT.L.D
                            5'b00010: begin
                                longint signed tmp;
                                tmp = $rtoi(f_rs1);
                                cpu_rf[rd] = tmp;
                            end
                    
                            // FCVT.LU.D
                            5'b00011: begin
                                longint unsigned tmp;
                                tmp = $rtoi(f_rs1);
                                cpu_rf[rd] = tmp;
                            end
                    
                            default: no_fpu = 1;
                        endcase
                    end

                    // FCVT.D.W / FCVT.D.WU / FCVT.D.L / FCVT.D.LU
                    7'b1101001: begin
                        case (instr[24:20])
                            5'b00000: fpu_rf[rd] = $realtobits($itor($signed(cpu_rf[rs1])));
                            5'b00001: fpu_rf[rd] = $realtobits($itor($unsigned(cpu_rf[rs1])));
                            5'b00010: fpu_rf[rd] = $realtobits($itor($signed(cpu_rf[rs1])));
                            5'b00011: fpu_rf[rd] = $realtobits($itor($unsigned(cpu_rf[rs1])));
                            default: no_fpu = 1;
                        endcase
                    end

                    // FMV.X.D
                    7'b1110001: begin
                        if (funct3 == 3'b000) begin
                            cpu_rf[rd] = fpu_rf[rs1];
                        end
                        else if (funct3 == 3'b001) begin
                            logic sign;
                            logic [10:0] exp;
                            logic [51:0] frac;
                            logic [63:0] v;
                            logic [63:0] cls;
                    
                            v    = fpu_rf[rs1];
                            sign = v[63];
                            exp  = v[62:52];
                            frac = v[51:0];
                            cls  = 64'b0;
                    
                            if (exp == 11'h7FF) begin
                                if (frac == 0) begin
                                    cls[sign ? 0 : 7] = 1'b1; // -inf or +inf
                                end
                                else begin
                                    cls[frac[51] ? 9 : 8] = 1'b1; // qNaN / sNaN
                                end
                            end
                            else if (exp == 0) begin
                                if (frac == 0) begin
                                    cls[sign ? 3 : 4] = 1'b1; // -0 / +0
                                end
                                else begin
                                    cls[sign ? 2 : 5] = 1'b1; // subnormal
                                end
                            end
                            else begin
                                cls[sign ? 1 : 6] = 1'b1; // normal
                            end
                    
                            cpu_rf[rd] = cls;
                        end
                        else begin
                            no_fpu = 1;
                        end
                    end

                    // FMV.D.X
                    7'b1111001: begin
                        fpu_rf[rd] = cpu_rf[rs1];
                    end

                    // FCVT.S.D
                    7'b0100000: begin
                        if (instr[24:20] == 5'b00001) begin
                            shortreal f32;
                            real f64;
                            f64 = $bitstoreal(fpu_rf[rs1]);
                            f32 = f64;
                            fpu_rf[rd] = {32'b0, $shortrealtobits(f32)};
                        end
                        else begin
                            no_fpu = 1;
                        end
                    end

                    // FCVT.D.S
                    7'b0100001: begin
                        if (instr[24:20] == 5'b00000) begin
                            shortreal f32;
                            real f64;
                            f32 = $bitstoshortreal(fpu_rf[rs1][31:0]);
                            f64 = f32; // float -> double
                            fpu_rf[rd] = $realtobits(f64);
                        end
                        else begin
                            no_fpu = 1;
                        end
                    end

                    default: no_fpu = 1;
                endcase
            end
            
            default: begin
                no_fpu = 1;
            end
        endcase
    endfunction: exec_float

    function bit [63:0] imm_decode(
        input logic [31:0] instr,
        input logic [6:0]  opcode,
        input logic [2:0]  funct3
    );
        logic [31:0] imm_32bit;
        logic [19:0] iU;
        logic [20:0] iJ;
        logic [11:0] iI, iS;
        logic [12:0] iB;
        logic [4:0]  shamt;
        logic [5:0]  shamt_RV64;

        iU = instr[31:12];
        iJ = {instr[31],instr[19:12],instr[20],instr[30:21],1'b0};
        iI = instr[31:20];
        iS = {instr[31:25],instr[11:7]};
        iB = {instr[31],instr[7],instr[30:25],instr[11:8],1'b0};
        shamt      = instr[24:20];
        shamt_RV64 = instr[25:20];

        if (opcode == 7'b0110111 || opcode == 7'b0010111) begin
            imm_32bit = {iU, 12'b0};                         // LUI / AUIPC
        end
        else if (opcode == 7'b1101111) begin
            imm_32bit = {{11{iJ[20]}}, iJ};                   // JAL
        end
        else if (opcode == 7'b1100111 || opcode == 7'b0000011 ||
                (opcode == 7'b0010011 &&
                (funct3 == 3'b000 || funct3 == 3'b010 ||
                 funct3 == 3'b100 || funct3 == 3'b110 ||
                 funct3 == 3'b111))) begin
            imm_32bit = {{20{iI[11]}}, iI};                   // ADDI/SLTI/XORI/ORI/ANDI, LOAD, JALR
        end
        else if (opcode == 7'b0010011 && funct3 == 3'b011) begin
            imm_32bit = {20'b0, iI};                          // SLTIU
        end
        else if (opcode == 7'b0010011 &&
                (funct3 == 3'b001 || funct3 == 3'b101)) begin
            imm_32bit = {26'b0, shamt_RV64};                  // SLLI / SRLI / SRAI (RV64)
        end
        else if (opcode == 7'b1100011) begin
            imm_32bit = {{19{iB[12]}}, iB};                   // BRANCH
        end
        else if (opcode == 7'b0100011) begin
            imm_32bit = {{20{iS[11]}}, iS};                   // STORE
        end
        else if (opcode == 7'b0011011 && funct3 == 3'b000) begin
            imm_32bit = {{20{iI[11]}}, iI};                   // ADDIW
        end
        else if (opcode == 7'b0011011 &&
                (funct3 == 3'b001 || funct3 == 3'b101)) begin
            imm_32bit = {27'b0, shamt};                       // SLLIW / SRLIW / SRAIW
        end
        else begin
            imm_32bit = 32'b0;
        end

        imm_decode = {{32{imm_32bit[31]}}, imm_32bit};
    endfunction: imm_decode
endclass: dual_core_model