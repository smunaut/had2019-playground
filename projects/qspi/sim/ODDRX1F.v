// --------------------------------------------------------------------
// >>>>>>>>>>>>>>>>>>>>>>>>> COPYRIGHT NOTICE <<<<<<<<<<<<<<<<<<<<<<<<<
// --------------------------------------------------------------------
// Copyright (c) 2005 by Lattice Semiconductor Corporation
// --------------------------------------------------------------------
//
//
//                     Lattice Semiconductor Corporation
//                     5555 NE Moore Court
//                     Hillsboro, OR 97214
//                     U.S.A.
//
//                     TEL: 1-800-Lattice  (USA and Canada)
//                          1-408-826-6000 (other locations)
//
//                     web: http://www.latticesemi.com/
//                     email: techsupport@latticesemi.com
//
// --------------------------------------------------------------------
//
// Simulation Library File for ECP4U
//
// fpga\verilog\pkg\versclibs\data\ecp4\ODDRX1F.v 1.4 20-APR-2011 12:01:39 IALMOHAN
//
`resetall
`timescale 1 ns / 1 ps

`celldefine

module ODDRX1F(D0, D1, RST, SCLK, Q);
   input D0, D1, RST, SCLK;
   output Q;

  parameter GSR = "ENABLED";

   reg Q_b;
   reg QP0, QN0, R0, F0, R0_reg, F0_reg;
   reg last_SCLKB;
   wire QN_sig;
   wire RSTB, SCLKB;
   reg SCLKB1, SCLKB2, SCLKB3;
   reg SRN;

tri1 GSR_sig, PUR_sig;
`ifndef mixed_hdl
   assign GSR_sig = GSR_INST.GSRNET;
   assign PUR_sig = PUR_INST.PURNET;
`else
   gsr_pur_assign gsr_pur_assign_inst (GSR_sig, PUR_sig);
`endif

   assign QN_sig = Q_b; 

   buf (Q, QN_sig);
   buf (OP, D0);
   buf (ON, D1);
   buf (RSTB1, RST);
   buf (SCLKB, SCLK);

      function DataSame;
        input a, b;
        begin
          if (a === b)
            DataSame = a;
          else
            DataSame = 1'bx;
        end
      endfunction

initial
begin
QP0 = 0;
QN0 = 0;
R0 = 0;
F0 = 0;
R0_reg = 0;
F0_reg = 0;
SCLKB1 = 0;
SCLKB2 = 0;
SCLKB3 = 0;
end

initial
begin
last_SCLKB = 1'b0;
end

  always @ (GSR_sig or PUR_sig ) begin
    if (GSR == "ENABLED")
      SRN = GSR_sig & PUR_sig ;
    else if (GSR == "DISABLED")
      SRN = PUR_sig;
  end
                                                                                               
  not (SR, SRN);
  or INST1 (RSTB, RSTB1, SR);

always @ (SCLKB)
begin
   last_SCLKB <= SCLKB;
end

always @ (SCLKB, SCLKB1, SCLKB2)
begin
   SCLKB1 <= SCLKB;
   SCLKB2 <= SCLKB1;
   SCLKB3 <= SCLKB2;
end

always @ (SCLKB or RSTB)
begin
   if (RSTB == 1'b1)
   begin
      QP0 <= 1'b0;
      QN0 <= 1'b0;
   end
   else
   begin
      if (SCLKB === 1'b1 && last_SCLKB === 1'b0)
         begin
            QP0 <= OP;
            QN0 <= ON;
         end
   end
end

always @ (SCLKB or RSTB)
begin
   if (RSTB == 1'b1)
   begin
      R0 <= 1'b0;
      F0 <= 1'b0;
      R0_reg <= 1'b0;
      F0_reg <= 1'b0;
   end
   else
   begin
      if (SCLKB === 1'b1 && last_SCLKB === 1'b0)
      begin
         R0 <= QP0;
         F0 <= QN0;
         F0_reg <= F0;
      end
      if (SCLKB === 1'b0 && last_SCLKB === 1'b1)     // neg
      begin
         R0_reg <= R0;
      end
   end
end

always @ (F0_reg or R0_reg or SCLKB1)
begin
   case (SCLKB1)
        1'b0 :  Q_b = F0_reg;
        1'b1 :  Q_b = R0_reg;
        default Q_b = DataSame(F0_reg, R0_reg);
   endcase
end

endmodule

`endcelldefine
