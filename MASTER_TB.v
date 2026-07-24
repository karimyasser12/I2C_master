`timescale 1ns/1ps
module master_tb;
    reg clk, rst, W_R, start, stop, ack;
    reg [6:0] slv_add;
    reg [7:0] m_data;
    wire busy, data_ready, error;
    wire [7:0] data_out;
    wire sca, sda;
    pullup(sca);
    pullup(sda);
    master dut (
        .clk(clk),
        .rst(rst),
        .W_R(W_R),
        .start(start),
        .stop(stop),
        .slv_add(slv_add),
        .ack(ack),
        .m_data(m_data),
        .busy(busy),
        .data_ready(data_ready),
        .error(error),
        .data_out(data_out),
        .sca(sca),
        .sda(sda)
    );
    always #10 clk = ~clk;
        reg sda_slave_out;
        reg sda_slave_en;

        assign sda = sda_slave_en ? sda_slave_out : 1'bz;

        initial begin
            clk = 0; rst = 0; start = 0; stop = 0;
            W_R = 0; slv_add = 7'b1010000; m_data = 8'b01010101; ack = 0;
            sda_slave_out = 1;
            sda_slave_en = 0;
            #100;
            rst = 1;
            #200;
            $display("Write");
            start = 1;
            W_R = 0;
            slv_add = 7'b1010000;
            m_data = 8'b01010101;
            stop = 1;
            wait(busy);
            start = 0;				
                          
            repeat(9) @(negedge sca);  //sending address
            sda_slave_en = 1;
            sda_slave_out = 0;         //ack mn el slave
            @(negedge sca);
            sda_slave_en = 0;
            sda_slave_out = 1;      //release line
  
            repeat(8) @(negedge sca); //master writing
            sda_slave_en = 1;         
            sda_slave_out = 0;         //ack mn el slave
            @(negedge sca);
            sda_slave_en = 0;
            sda_slave_out = 1;        //realease
            wait (!busy);
            #200;
            if (error)
                $display("write fail: error=%b", error);
            else
               $display("write pass");
            #500;
            //READ
            $display("--- Read ---");
            start = 1;
            W_R = 1;
            slv_add = 7'b1010000;
            ack = 1; 
            stop = 1;
            wait(busy);
            start = 0;
            //SLAVE WRITING
            repeat(9) @(negedge sca);
            sda_slave_en = 1;               // slave take control of line
            sda_slave_out = 0;
            @(negedge sca);
            sda_slave_en = 1;
            sda_slave_out = 1;
            @(negedge sca);
            sda_slave_en = 1;
            sda_slave_out = 0;
            @(negedge sca);
            sda_slave_en = 1;              //slave bykteb 3la el line
            sda_slave_out = 1;
            @(negedge sca);
            sda_slave_en = 1;
            sda_slave_out = 0;
            @(negedge sca);
            sda_slave_en = 1;
            sda_slave_out = 0;
            @(negedge sca);
            sda_slave_en = 1;
            sda_slave_out = 1;
            @(negedge sca);
            sda_slave_en = 1;
            sda_slave_out = 0;
            @(negedge sca);
            sda_slave_en = 1;
            sda_slave_out = 1;
            @(negedge sca);
            sda_slave_en = 0;               // release the line
            sda_slave_out = 1;
            wait(!busy);
            #200;
           if (data_out == 8'b10100101)
            $display("read pass: data_out = %b", data_out);
              else
             $display("read fail: data_out = %b, expected 10100101", data_out);

            start = 1;
            W_R = 1;
            slv_add = 7'b1010000;
            ack = 1;
            stop = 1;
            sda_slave_en = 0;                        //aken el address 8alat , mafesh slave hyrod fa el pull up gives 1 master reads 1 as NACK and sets error
            sda_slave_out = 1;
            wait(busy);
            start = 0;
            wait(!busy);
            #200;
            if (error)
                $display("NACK READ pass: error=%b (slave not acknowlegd)", error);
            else
                $display("NACK read fail: error=%b (should be 1)", error);
            #500; 
            $finish;
            end
endmodule
