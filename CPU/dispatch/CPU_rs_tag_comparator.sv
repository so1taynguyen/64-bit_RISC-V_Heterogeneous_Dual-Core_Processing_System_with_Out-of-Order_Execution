module CPU_rs_tag_comparator (
    input  logic [1:0] do_cmp,
    input  logic [4:0] rd_tag, rs1_tag, rs2_tag,
    input  logic [4:0] current_rd_tag, current_rs1_tag, current_rs2_tag,
    output logic       rs1_rf_sel, rs2_rf_sel
);
    timeunit 1ns; timeprecision 1ps;

    always_comb begin
        rs1_rf_sel = (rs1_tag != current_rs1_tag) ? 1'b1 : 1'b0;     // 1: temp regfile, 0: main regfile
        rs2_rf_sel = (rs2_tag != current_rs2_tag) ? 1'b1 : 1'b0;     // 1: temp regfile, 0: main regfile

        if (do_cmp != 2'd0) begin
            if (do_cmp[0] & (rd_tag == current_rd_tag)) begin
                rs1_rf_sel = 1'b0;
            end
            if (do_cmp[1] & (rd_tag == current_rd_tag)) begin
                rs2_rf_sel = 1'b0;
            end
        end
    end

endmodule: CPU_rs_tag_comparator