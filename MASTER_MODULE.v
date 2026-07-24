module master
             (  input clk,
                input rst,
                input W_R,
                input start,
                input stop,
                input [6:0]slv_add,
                input ack,
                input [7:0] m_data,
                output busy,
                output reg data_ready,
                output reg error,
                output reg [7:0] data_out,
                inout sca,
                inout sda
            );
    localparam  S0=3'b000,       //idle
                S1=3'b001,       //START
                S2=3'b010,       //send address
                S3=3'b011,       //ack of address
                S4=3'b100,       //data byte (read or write)
                S5=3'b101,       //ack2
                S6=3'b110;       //stop
    reg sca_reg;
    reg [1:0] clk_counter;
    reg sda_out;
    reg sda_en;
    reg [2:0]counter_m;
    reg [2:0]counter_o;
    reg [2:0]counter_r;
    reg [2:0] next_state;
    reg [2:0] current_state;
    reg [7:0] shifter;
    reg [7:0] data_in_shift;
    reg [7:0] data_out_shift;
    reg ack_slave;

    assign sca=sca_reg? 1'bz : 1'b0;
    assign sda=(sda_en && !sda_out)? 1'b0 : 1'bz;           //had to search for how to deal with inout
    
    always@(posedge clk or negedge rst) begin
        if(!rst) begin
            clk_counter<=0;
            sca_reg<=0;
        end
        else begin
            if(clk_counter==2'b11)                     //kabart el counter 3ashan el 1bit counter kan 3amel mashakel
            begin
                clk_counter<=0;
                sca_reg<=~sca_reg;
            end
            else
            begin
                clk_counter<=clk_counter+1;
            end
        end
    end
    wire change=(clk_counter==2'b01) && !sca_reg;            //el sda data btt8ayer hena
    wire steady=(clk_counter==2'b01) &&  sca_reg;            //hena momken nread el data
    wire scl_fall=(clk_counter==2'b11) &&  sca_reg;       //negedge bta3et el scl
 

    always@(posedge clk or negedge rst)
     begin
        if(!rst)
        begin
            current_state<=S0;
        end
        else
        begin
            current_state<=next_state;
        end
    end

    always@(posedge clk or negedge rst) 
    begin
        if(!rst) begin
            data_ready<=0;
            error<=0;
            data_out<=0;
            next_state<=S0;
            sda_out<=1;
            sda_en<=0;
            ack_slave<=0;
            counter_m<=0;
            counter_o<=0;
            counter_r<=0;
        end
        else begin
            case(current_state)
                S0:begin
                    sda_en<=0;
                    sda_out<=1;
                    if(start && scl_fall)       
                    begin
                    next_state<=S1;
                    shifter<={slv_add,W_R};
                    data_out_shift<=m_data;
                    error<=0;
                    data_ready<=0;
                    ack_slave<=0;
                    counter_m<=0;
                    counter_o<=0;
                    counter_r<=0;
                    end
                end
                S1:begin
                    if(change)
                    begin
                    sda_en<=1;
                    sda_out<=1;   //sda b2a high
                    end
                    if(steady)
                    begin
                     sda_out<=0;   //sda b2a low
                    end
                    if(scl_fall)  
                    begin
                    next_state<=S2;
                    end
                end
                S2:begin                             // address + R/W , MSB first
                    if(change) 
                    begin
                        sda_en<=1;
                        sda_out<=shifter[7];
                        shifter<=shifter<<1'b1;
                    end
                    if(scl_fall) begin
                        if(counter_m==3'b111)
                        begin
                            counter_m<=0;
                            next_state<=S3;
                        end
                        else begin
                            counter_m<=counter_m+1'b1;
                        end
                    end
                end
                S3:begin                     // ack1 el slave ele hayb3t
                    if(change)  sda_en<=0;
                    if(steady)
		begin
		   if(sda==1)
		  begin
		   ack_slave=1;
		   error=1; 
                  end
		   else
		 begin
                   ack_slave=0;
		   error=0;
		  end
		  end
                    if(scl_fall)
                    begin
                        if(ack_slave)
                        begin
                            next_state<=S6;     
                        end
                        else
                        begin
                            next_state<=S4;
                        end
                    end
                end
                S4:begin
                        if ( W_R==0)
		       begin   //writing
                            if(change) 
				begin
                                sda_en<=1;
                                sda_out<=data_out_shift[7];
                                data_out_shift<={data_out_shift[6:0],1'b0};
                                 end
                            if(scl_fall) 
			    begin
                                if(counter_o==3'b111)
                                begin
                                    counter_o<=0;
                                    next_state<=S5;
                                end
                                else 
				begin
                                    counter_o<=counter_o+1'b1;
                                end
                            end
                        end
                        else begin                  //READ
                            if(change) 
                            begin
                                sda_en<=0;           // slave haymsk el line
                                sda_out<=1;
                            end
                            if(steady) 
                            begin
                                data_in_shift<={data_in_shift[6:0],sda};
                            end
                            if(scl_fall) 
                            begin
                            if(counter_r==3'b111)
                            begin
                            counter_r<=3'b0;
                            data_out<=data_in_shift;
                            data_ready<=1;
                            next_state<=S5;
                            end
                            else
                            begin
                            counter_r<=counter_r+1;
                            end
                            end
                        end
                end
                S5:begin
                    if(change) begin
                        if(!W_R) begin   // 5alasat ketaba mstny el rad mn el slave
                        sda_en<=0;
                        sda_out<=1;
                        end
                        else      //2aret wa mstny el rad mn el master
                        begin
                        sda_en<=1;
                        sda_out<=ack;
                        end
                    end
                    if(steady&&!W_R)
                     begin                                //steady wa write 
                        ack_slave<=sda;                  //slave hayrod 
                    if(sda)    
		        error<=1; 
		    else 
			error<=0;
                    end
                    if(scl_fall)
                    begin
                        data_ready<=0;
                        if(!W_R && ack_slave)        //5alasat writing wa slave ack
                        begin
                        next_state<=S6;
                        end
                        else if(W_R && ack)          //5alasat reading wa el master ack
                        begin
                        next_state<=S6;
                        end
                        else if(stop)     
                        begin  
                        next_state<=S6;
                        end
                        else begin
                        data_out_shift<=m_data;
                        next_state<=S4;
                        end
                    end
                end
                S6:begin                          
                    if(change) 
                    begin
                        sda_en<=1;
                        sda_out<=0;
                    end
                    else if(steady) 
                    begin
                        sda_en<=0;
                        sda_out<=1;
                    end
                    if(scl_fall) 
                    begin
                        next_state<=S0;
                    end
                end
                default: next_state<=S0;
            endcase
end
end
    assign busy=(current_state!=S0);  
endmodule
