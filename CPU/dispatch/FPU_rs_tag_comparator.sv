module FPU_rs_tag_comparator (
    input  logic [2:0] do_cmp,
    input  logic [4:0] rd_tag, rs1_tag, rs2_tag, rs3_tag,
    input  logic [4:0] current_rd_tag, current_rs1_tag, current_rs2_tag, current_rs3_tag,
    output logic       rs1_rf_sel, rs2_rf_sel, rs3_rf_sel
);
    timeunit 1ns; timeprecision 1ps;

    always_comb begin
        rs1_rf_sel = (rs1_tag != current_rs1_tag) ? 1'b1 : 1'b0;     // 1: temp regfile, 0: main regfile
        rs2_rf_sel = (rs2_tag != current_rs2_tag) ? 1'b1 : 1'b0;     // 1: temp regfile, 0: main regfile
        rs3_rf_sel = (rs3_tag != current_rs3_tag) ? 1'b1 : 1'b0;     // 1: temp regfile, 0: main regfile

        if (do_cmp != 3'd0) begin
            if (do_cmp[0] & (rd_tag == current_rd_tag)) begin
                rs1_rf_sel = 1'b0;
            end
            if (do_cmp[1] & (rd_tag == current_rd_tag)) begin
                rs2_rf_sel = 1'b0;
            end
            if (do_cmp[2] & (rd_tag == current_rd_tag)) begin
                rs3_rf_sel = 1'b0;
            end
        end
    end

endmodule: FPU_rs_tag_comparator