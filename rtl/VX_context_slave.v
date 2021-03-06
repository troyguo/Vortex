
`include "VX_define.v"

module VX_context_slave (
  input wire           clk,
  input wire               in_warp,
  input wire               in_wb_warp,
  input wire[`NT_M1:0]     in_valid,
  input wire               in_write_register,
  input wire[4:0]          in_rd,
  input wire[(`NT*32)-1:0] in_write_data,
  input wire[4:0]          in_src1,
  input wire[4:0]          in_src2,
  input wire[31:0]         in_curr_PC,
  input wire               in_is_clone,
  input wire               in_is_jal,
  input wire               in_src1_fwd,
  input wire[(`NT*32)-1:0] in_src1_fwd_data,
  input wire               in_src2_fwd,
  input wire[(`NT*32)-1:0] in_src2_fwd_data,
  input wire[(32*32)-1:0]  in_wspawn_regs,
  input wire               in_wspawn,

  output wire[(`NT*32)-1:0] out_a_reg_data,
  output wire[(`NT*32)-1:0] out_b_reg_data,
  output wire               out_clone_stall
	
);
		wire[(`NT*32)-1:0] rd1_register;
		wire[(`NT*32)-1:0] rd2_register;
		wire[(32*32)-1:0]  clone_regsiters;


		// wire[31:0] array_in_write_data[`NT_M1:0];
		// wire[31:0] array_in_src1_fwd[`NT_M1:0];
		// wire[31:0] array_in_src2_fwd[`NT_M1:0];
		// wire[31:0] array_out_reg_a[`NT_M1:0];
		// wire[31:0] array_out_reg_b[`NT_M1:0];

		// integer i;

		// for (i=0;i<`NT;i=i+1) begin
		// 	assign array_in_write_data[i] = in_write_data[(32*i)+31:(32*i)];
		// 	assign array_in_src1_fwd[i] = in_write_data[(32*i)+31:(32*i)];
		// 	assign array_in_src2_fwd[i] = in_write_data[(32*i)+31:(32*i)];
		// 	assign array_out_reg_a[i] = in_write_data[(32*i)+31:(32*i)];
		// 	assign array_out_reg_b[i] = in_write_data[(32*i)+31:(32*i)];
		// end


		reg[5:0] clone_state_stall = 0;
		reg[5:0] wspawn_state_stall = 0;

		initial begin
			clone_state_stall  = 0;
			wspawn_state_stall = 0;
		end


		wire to_wspawn = wspawn_state_stall == 2;
		// always @(*) begin
		// 	if (to_wspawn)
		// 		$display("-----> to_wspawn == 1");
		// end
		VX_register_file_master_slave vx_register_file_master(
			.clk               (clk),
			.in_wb_warp        (in_wb_warp),
			.in_valid          (in_valid[0]),
			.in_write_register (in_write_register),
			.in_rd             (in_rd),
			.in_data           (in_write_data[31:0]),
			.in_src1           (in_src1),
			.in_src2           (in_src2),
			.in_wspawn         (in_wspawn),
			.in_to_wspawn      (to_wspawn),
			.in_wspawn_regs    (in_wspawn_regs),
			.out_regs          (clone_regsiters),
			.out_src1_data     (rd1_register[31:0]),
			.out_src2_data     (rd2_register[31:0])
		);

		genvar index;
		generate  
		for (index=1; index < `NT; index=index+1)  
		  begin: gen_code_label  
			wire to_clone;
		  	assign to_clone = (index == rd1_register[31:0]) && (clone_state_stall == 1);
			VX_register_file_slave vx_register_file_slave(
				.clk               (clk),
				.in_warp           (in_warp),
				.in_wb_warp        (in_wb_warp),
				.in_valid          (in_valid[index]),
				.in_write_register (in_write_register),
				.in_rd             (in_rd),
				.in_data           (in_write_data[(32*index)+31:(32*index)]),
				.in_src1           (in_src1),
				.in_src2           (in_src2),
				.in_clone          (in_is_clone),
				.in_to_clone       (to_clone),
				.in_regs           (clone_regsiters),
				.out_src1_data     (rd1_register[(32*index)+31:(32*index)]),
				.out_src2_data     (rd2_register[(32*index)+31:(32*index)])
			);
		  end
		endgenerate

		// always @(*) begin
		// 	if (in_valid[0] && in_valid[1]) begin
		// 		$display("Reg write: %h %h", in_write_data[0], in_write_data[1]);
		// 	end else if (in_valid[0]) begin
		// 		$display("Reg write: %h", in_write_data[0]);
		// 	end
		// end


		// for clone
		always @(posedge clk) begin
			if ((in_is_clone) && clone_state_stall == 0) begin
				clone_state_stall <= 10;
				// $display("CLONEEE BITCH %d, 1 =? %h = %h -- %d", clone_state_stall, rd1_register[0], to_clone_1, in_is_clone);
			end else if (clone_state_stall == 1) begin
				// $display("ENDING CLONE, 1 =? %h = %h -- %d", rd1_register[0], to_clone_1, in_is_clone);
				clone_state_stall <= 0;
			end else if (clone_state_stall > 0) begin
				clone_state_stall <= clone_state_stall - 1;
				// $display("CLONEEE BITCH %d, 1 =? %h = %h -- %d", clone_state_stall, rd1_register[0], to_clone_1, in_is_clone);
			end
		end


		// for wspawn
		always @(posedge clk) begin
			if ((in_wspawn) && wspawn_state_stall == 0) begin
				wspawn_state_stall <= 10;
				// $display("starting wspawn stalling -- in_wspawn: %d -- stall %d", in_wspawn, wspwan_stall);
			end else if (wspawn_state_stall == 1) begin
				// $display("ENDING wspawn stalling -- in_wspawn %d -- stall: %d", in_wspawn, wspwan_stall);
				wspawn_state_stall <= 0;
			end else if (wspawn_state_stall > 0) begin
				wspawn_state_stall <= wspawn_state_stall - 1;
				// $display("wspawn state: %d  in_wspawn: %d -- stall: %d", wspawn_state_stall, in_wspawn, wspwan_stall);
			end
		end


		genvar index_out_reg;
		generate
			for (index_out_reg = 0; index_out_reg < `NT; index_out_reg = index_out_reg + 1)
				begin
					assign out_a_reg_data[(32*index_out_reg)+31:(32*index_out_reg)]   = (    (in_is_jal == 1'b1) ? in_curr_PC : ((in_src1_fwd == 1'b1) ? in_src1_fwd_data[(32*index_out_reg)+31:(32*index_out_reg)] : rd1_register[(32*index_out_reg)+31:(32*index_out_reg)]));
					assign out_b_reg_data[(32*index_out_reg)+31:(32*index_out_reg)]   = (in_src2_fwd == 1'b1) ?  in_src2_fwd_data[(32*index_out_reg)+31:(32*index_out_reg)] : rd2_register[(32*index_out_reg)+31:(32*index_out_reg)];
				end
		endgenerate

		wire clone_stall  = ((clone_state_stall  == 0) && in_is_clone) || ((clone_state_stall  != 1) && in_is_clone);
		wire wspwan_stall = ((wspawn_state_stall == 0) && in_wspawn)   || (wspawn_state_stall   > 1);

		assign out_clone_stall = clone_stall || wspwan_stall;

endmodule