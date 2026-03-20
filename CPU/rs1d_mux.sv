module rs1d_mux (
	input  [63:0] rs1_dataD, alu_dataE, alu_dataM, ld_dataM, wb_dataW, bridge_wr_dataM, bridge_wr_dataW,
	input   [2:0] rs1d_sel,
	output logic [63:0] rs1d_out
);
    timeunit 1ns; timeprecision 1ps;
	
    assign rs1d_out = (rs1d_sel == 3'b000) ? rs1_dataD :
                      (rs1d_sel == 3'b001) ? alu_dataE :
                      (rs1d_sel == 3'b010) ? alu_dataM : 
                      (rs1d_sel == 3'b011) ? ld_dataM  : 
                      (rs1d_sel == 3'b100) ? wb_dataW  : 
                      (rs1d_sel == 3'b101) ? bridge_wr_dataM : bridge_wr_dataW;

endmodule