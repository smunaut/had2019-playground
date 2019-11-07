// --------------------------------------------------------------------
// >>>>>>>>>>>>>>>>>>>>>>>>> COPYRIGHT NOTICE <<<<<<<<<<<<<<<<<<<<<<<<<
// --------------------------------------------------------------------
// Copyright (c) 2007 by Lattice Semiconductor Corporation
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
// $Header: 
//

`resetall
`timescale 1 ns / 1 ps

`celldefine

module IDDRX1F(D, SCLK, RST, Q0, Q1);

input  D, SCLK, RST;
output Q0, Q1;

   parameter  GSR = "ENABLED";            // "DISABLED", "ENABLED"

wire Db, SCLKb;

reg QP, QN, IP0, IN0;
reg last_SCLKB;
reg SRN;

buf (Db, D);
buf (SCLKB, SCLK);
buf (RSTB1, RST);

buf (Q0, IP0);
buf (Q1, IN0);

tri1 GSR_sig, PUR_sig;
`ifndef mixed_hdl
   assign GSR_sig = GSR_INST.GSRNET;
   assign PUR_sig = PUR_INST.PURNET;
`else
   gsr_pur_assign gsr_pur_assign_inst (GSR_sig, PUR_sig);
`endif

initial
begin
QP = 0;
QN = 0;
IP0 = 0;
IN0 = 0;
end

  always @ (GSR_sig or PUR_sig ) begin
    if (GSR == "ENABLED")
      SRN = GSR_sig & PUR_sig ;
    else if (GSR == "DISABLED")
      SRN = PUR_sig;
  end
                                                                                                      
  not (SR, SRN);
  or INST1 (RSTB2, RSTB1, SR);

initial
begin
last_SCLKB = 1'b0;
end

always @ (SCLKB)
begin
   last_SCLKB <= SCLKB;
end

always @ (SCLKB or RSTB2)     // pos_neg edge
begin
   if (RSTB2 == 1'b1)
   begin
      QP <= 1'b0;
      QN <= 1'b0;
   end
   else
   begin
      if (SCLKB === 1'b1 && last_SCLKB === 1'b0)
      begin
         QP <= Db;
      end
      if (SCLKB === 1'b0 && last_SCLKB === 1'b1)
      begin
         QN <= Db;
      end
   end
end

always @ (SCLKB or RSTB2)     //  edge
begin
   if (RSTB2 == 1'b1)
   begin
      IP0 <= 1'b0;
      IN0 <= 1'b0;
   end
   else
   begin
      if (SCLKB === 1'b1 && last_SCLKB === 1'b0)
      begin
         IP0 <= QP;
         IN0 <= QN;
      end
   end
end

endmodule

`endcelldefine
