module rs2d_mux (
	input  [63:0] rs2_dataD, alu_dataE, alu_dataM, ld_dataM, wb_dataW, bridge_wr_dataM, bridge_wr_dataW,
	input   [2:0] rs2d_sel,
	output logic [63:0] rs2d_out
);
    timeunit 1ns; timeprecision 1ps;
	
    assign rs2d_out = (rs2d_sel == 3'b000) ? rs2_dataD :
                      (rs2d_sel == 3'b001) ? alu_dataE :
                      (rs2d_sel == 3'b010) ? alu_dataM : 
                      (rs2d_sel == 3'b011) ? ld_dataM  : 
                      (rs2d_sel == 3'b100) ? wb_dataW  : 
                      (rs2d_sel == 3'b101) ? bridge_wr_dataM : bridge_wr_dataW;

endmodule