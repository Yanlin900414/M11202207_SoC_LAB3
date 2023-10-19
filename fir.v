(*use_dsp = "no"*)module fir  //test//
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
   
)
(
    output  wire                     awready,
    output  wire                     wready,
    input   wire                     awvalid,
    input   wire [(pADDR_WIDTH-1):0] awaddr,
    input   wire                     wvalid,
    input   wire [(pDATA_WIDTH-1):0] wdata,
    
    output  wire                     arready,
    input   wire                     rready,
    input   wire                     arvalid,
    input   wire [(pADDR_WIDTH-1):0] araddr,
    output  wire                     rvalid,
    output  wire [(pDATA_WIDTH-1):0] rdata,   
     
    input   wire                     ss_tvalid, 
    input   wire [(pDATA_WIDTH-1):0] ss_tdata, 
    input   wire                     ss_tlast, 
    output  wire                     ss_tready, 
    
    input   wire                     sm_tready, 
    output  wire                     sm_tvalid, 
    output  wire [(pDATA_WIDTH-1):0] sm_tdata, 
    output  wire                     sm_tlast, 
    
    // bram for tap RAM
    output  wire [3:0]               tap_WE,
    output  wire                     tap_EN,
    output  wire [(pDATA_WIDTH-1):0] tap_Di,
    output  wire [(pADDR_WIDTH-1):0] tap_A,
    input   wire  [(pDATA_WIDTH-1):0] tap_Do,

    // bram for data RAM
    output  wire [3:0]               data_WE,
    output  wire                     data_EN,
    output  wire [(pDATA_WIDTH-1):0] data_Di,
    output  wire [(pADDR_WIDTH-1):0] data_A,
    input   wire  [(pDATA_WIDTH-1):0] data_Do,

    input   wire                     axis_clk,
    input   wire                     axis_rst_n
);

    reg 										saxi_rvalid;
	 reg                     			saxi_rready;
    reg 										saxi_wready;
    reg 										saxi_awready;
    reg 										saxi_arready;
	 reg [(pDATA_WIDTH-1):0]  			saxi_rdata;
 
    reg                     			axistream_sstready;
    reg                     			axistream_smtlast;
     
    reg                     			bram_tap_EN;
    reg [(pDATA_WIDTH-1):0] 			bram_tap_Di;
    reg [(pADDR_WIDTH-1):0] 			bram_tap_A;
    reg                     			bram_tap_complete;
    reg [3:0]               			bram_tap_WE;
    
    reg                     			bram_data_EN;
    reg [(pDATA_WIDTH-1):0] 			bram_data_Di;
    reg [(pADDR_WIDTH-1):0] 			bram_data_A;
    reg                     			bram_data_complete;
    reg [3:0]              			bram_data_WE;

    reg [2:0]               			bram_tap_counter;
    reg [2:0]               			bram_data_counter;
    
 
   
    reg [3:0]               			bram_data_block;

    wire                    			bram_data_in;
    reg                     			count_complete;
    reg signed [(pDATA_WIDTH-1):0] 	data_return;
    reg [3:0]               			count_tap,count_data;
    
    wire signed [31:0]             	data_plus;
   
    reg                        		initiall_block;
    reg [3:0] 								cal_count;
   
    reg  									done,idle;

    reg 										record;
    reg [3:0]								cal_block;
    reg 										a;
    reg 										buff_2,buff_3,buff_4;
    reg [11:0]								bram_tap_A_1;
    reg 										buff_1;
    reg [11:0]								bram_data_A_1;
    reg 										buff;

    
    assign rvalid = saxi_rvalid;
    assign rdata = saxi_rdata;
    assign arready = saxi_arready;
    
    assign wready = saxi_wready;
    assign awready = saxi_awready;
    

    assign sm_tlast = axistream_smtlast;
    
    assign tap_A = bram_tap_A;
    assign tap_Di = bram_tap_Di;
    assign tap_EN = bram_tap_EN;
    assign tap_WE = bram_tap_WE;
    
    assign data_A = {record==1'd1}?bram_data_A_1: 
                    {record==1'd0}?bram_data_A:12'd0;
    assign data_Di = bram_data_Di;
    assign data_EN = bram_data_EN;
    assign data_WE = bram_data_WE;

    assign ss_tready = {(axis_rst_n && initiall_block==1'd1&&sm_tvalid)||(axis_rst_n&&sm_tlast==1'd1)}?1'd1:1'd0;
    
	 ///use one multiplier and Adder///
    assign data_plus = tap_Do * data_Do + data_return;
	 ///----------------------------///
    
    
    assign sm_tvalid = {data_EN==1'd1&&count_complete==1'd1}?1'd1:1'd0;
    assign sm_tdata = {sm_tvalid}?data_return:32'd0;
    
    always @(posedge axis_clk)begin
        if(!axis_rst_n)begin
            bram_data_EN<=1'd0;
    
        end
        else begin
            if(sm_tlast==1'd0&&axis_rst_n&&awaddr==12'h00&&wdata==32'h01)begin
               bram_data_EN<=1'd1;
            end
            else begin
               bram_data_EN<=1'd0;
            end
        end
    end

     always @(posedge axis_clk)begin //calculate block 
        if(!axis_rst_n)begin
            count_complete<=1'd0;
            data_return<=32'd0;
            cal_count<=4'd0;
            count_tap <= 4'd0;
            axistream_smtlast<=1'd0;
            done<=1'd0;
            idle<=1'd1;
        end
        else begin
				///decide ap_idle & ap_done 1 or 0/// 
            if(ss_tlast==1'd1&&sm_tlast==1'd1&&done==1'd0&&idle==1'd0)begin
                done<=1'd1;
            end
            else if(arready==1'd0&&arvalid==1'd0&&ss_tlast==1'd1&&sm_tlast==1'd1)begin
                done<=1'd0;
                idle<=1'd1;
            end
            else if(awaddr==12'h00&&wdata==32'h01&&ss_tlast==1'd0)begin
                idle<=1'd0;
            end
            else begin
                done<=done;
            end
				///-------------------------------///
				
				///last data calculate complete detect///
            if(ss_tlast==1'd1&& count_complete==1'd1)begin
                 axistream_smtlast<=1'd1;
            end
            else begin
                axistream_smtlast<=axistream_smtlast;
            end
            ///----------------------------------///
				
				///choose convolution data block///
            case(bram_data_block)
                4'd0:begin
                    count_complete<=1'd0;
                   
                end
                4'd2:begin
                    cal_count <= cal_block;
                    data_return<=32'd0;
                    count_tap <= 4'd0; 
                end
                4'd3:begin
                    
                    if(cal_count!=cal_block)begin
                        case(cal_count)  //data_bram  
                            4'd10:begin
                                count_data<=cal_count;
                                cal_count<=4'd9;
                                
                            end
                            4'd9:begin
                                count_data<=cal_count;
                                cal_count<=4'd8;
                            end
                            4'd8:begin
                                count_data<=cal_count;
                                cal_count<=4'd7;
                            end
                            4'd7:begin
                                count_data<=cal_count;
                                cal_count<=4'd6;
                            end
                            4'd6:begin
                                count_data<=cal_count;
                                cal_count<=4'd5;
                            end
                            4'd5:begin
                                count_data<=cal_count;
                                cal_count<=4'd4;
                            end
                            4'd4:begin
                                count_data<=cal_count;
                                cal_count<=4'd3;
                            end
                            4'd3:begin
                                count_data<=cal_count;
                                cal_count<=4'd2;
                            end
                            4'd2:begin
                                count_data<=cal_count;
                                cal_count<=4'd1;
                            end
                            4'd1:begin
                                count_data<=cal_count;
                                cal_count<=4'd0;
                            end
                            4'd0:begin
                                count_data<=cal_count;
                                cal_count<=4'd10;
                            end
                            default:begin
                                cal_count<=cal_count;
                            end
                        
                        endcase
                            
                        case(count_tap)   
                            4'd0:begin
                                data_return<=data_plus;
                                count_tap<=4'd1;
                            end
                            4'd1:begin
                                data_return<=data_plus;
                                count_tap<=4'd2;
                            end
                            4'd2:begin
                                data_return<=data_plus;
                                count_tap<=4'd3;
                            end
                            4'd3:begin
                                data_return<=data_plus;
                                count_tap<=4'd4;
                            end
                            4'd4:begin
                                data_return<=data_plus;
                                count_tap<=4'd5;
                            end
                            4'd5:begin
                                data_return<=data_plus;
                                count_tap<=4'd6;
                            end
                            4'd6:begin
                                data_return<=data_plus;
                                count_tap<=4'd7;
                            end
                            4'd7:begin
                                data_return<=data_plus;
                                count_tap<=4'd8;
                            end
                            4'd8:begin
                                data_return<=data_plus;
                                count_tap<=4'd9;
                            end
                            4'd9:begin
                                data_return<=data_plus;
                                count_tap<=4'd10;
                            end
                            4'd10:begin
                                data_return<=data_plus;
                                count_tap<=4'd0;
                            end
                            
                            default:begin
                                data_return<=32'd0;
                                count_tap<=count_tap;
                            end
                        endcase
                      end
                      else begin
                          count_complete<=1'd1;
                          if(count_complete==1'd1)begin
                            count_complete<=1'd0;
                          end  
                          data_return<=data_plus;
                      end
                end
                default:begin
                    count_complete<=1'd0;
                end
            endcase
				///---------------------------------------------------------///
        end
     end
    
    
    always @(posedge axis_clk)begin
        if(!axis_rst_n)begin
            bram_data_complete<=1'd0;
            initiall_block<=1'd0;
            bram_data_WE<=4'b0000;
            bram_data_Di<=32'd0;
            bram_data_block<=4'd0;
            bram_data_A<=12'd0;
            record<=1'd0;
        
        end
        else begin
        
        
          
            case(bram_data_block)
            4'd0:begin//start state
                if(data_EN==1'd1&&bram_data_complete==1'd0)begin
                    bram_data_block<=4'd1;
                    
                    bram_data_WE<=4'b0000;
                end
                else begin
                    bram_data_block<=4'd0;
                end
                record<=1'd0;
                bram_data_complete<=1'd0;
            end
            4'd1:begin//initiall Bram data
                if(initiall_block==1'd0)begin
                    bram_data_complete<=1'd1;
						  ///write data in Bram///
                    bram_data_WE<=4'b1111;
                    bram_data_Di<=32'd0;
                    bram_data_A<=cal_block<<2;
						  ///-----------------///
                    if(cal_block==4'd10)begin
                        initiall_block<=1'd1; 
                        bram_data_block<=4'd2;
                    end
                    else begin
                        bram_data_block<=4'd1;
                    end
                end
                else begin
                    bram_data_complete<=1'd1;
                    bram_data_block<=4'd2;
                end
                record<=1'd0;
            end

            4'd2:begin//calculate_prepare (data will store in this clock)
                bram_data_block<=4'd3;
                bram_data_WE<=4'b0000;
                bram_data_complete<=1'd0;
                record<=1'd1;
            end
            4'd3:begin//calculate (convolution -> 11clock)
                if(count_complete==1'd1)begin
                    bram_data_block<=4'd2;
                    record<=1'd0;
						  ///write data in Bram///
                    bram_data_WE<=4'b1111;
                    bram_data_Di<=ss_tdata;
                    bram_data_A<=cal_block<<2;
						  ///-----------------///
						  bram_data_complete<=1'd1;
                end
                else begin
                    bram_data_block<=bram_data_block;
                    record<=1'd1;
                    bram_data_complete<=1'd0;
                end
            end
            default:begin
                bram_data_WE<=4'b0000;
            end 
            endcase
            
           
         end
     end
  
    
    always @(posedge axis_clk)begin//call block (initiall bram 11 block counter)
        if(!axis_rst_n)begin
            cal_block<=4'd0;
            buff_4<=1'd0;
        end
        else begin
            if(data_EN==1'd1&&bram_data_complete==1'd1)begin
                if(cal_block>4'd9)begin
                     cal_block<= 4'd0;
                end
                else begin
                    case(cal_block)
                    4'd0:cal_block<=4'd1;
                    4'd1:cal_block<=4'd2;
                    4'd2:cal_block<=4'd3;
                    4'd3:cal_block<=4'd4;
                    4'd4:cal_block<=4'd5;
                    4'd5:cal_block<=4'd6;
                    4'd6:cal_block<=4'd7;
                    4'd7:cal_block<=4'd8;
                    4'd8:cal_block<=4'd9;
                    4'd9:cal_block<=4'd10;
                    default:cal_block<=4'd0;
                    endcase
                end
            end
            else begin
                buff_4<=1'd1;
            end
        end
     end
  
    always @(posedge axis_clk)begin
        if(!axis_rst_n)begin
            saxi_rvalid <= 1'd0;
            saxi_arready <=1'd1;
            buff_2<=1'd0;
            bram_tap_complete <=1'd0;
            bram_tap_EN <= 1'd0;
            bram_tap_counter <= 3'd0;
            buff_3<=1'd0;
        end
        else begin
            case (bram_tap_counter)
                3'd0:begin   
                    
                    if(arvalid==1'd0&&awvalid==1'd0)begin
                        bram_tap_counter<=3'd0;
                    end
                    else if(saxi_wready==1'd1)begin
                        
                        bram_tap_counter<=3'd1;
                        bram_tap_EN <= 1'd1;
                    end
                    else begin
                        bram_tap_counter<=3'd0;
                    end
                end
                3'd1:bram_tap_counter<=3'd0;
                
                    
                default:bram_tap_counter<=3'd0;
            endcase
            
            if(rready==1'd1)begin
                if(arready==1'd1&&arvalid==1'd1)begin
                    saxi_rvalid<=1'd1;
                end
                else begin
                    saxi_rvalid<=1'd0;
                end
             
                if(bram_tap_A>>2==12'd10&&rvalid==1'd0&&arvalid==1'd0||(awaddr==12'h00&&wdata==32'h01))begin
                    bram_tap_complete <=1'd1;
                end
                else begin
                    buff_3<=1'd1;
                end
            end
            else begin
                buff_2<=1'd1;
            end
            if(arvalid==1'd1)begin
                saxi_arready <=1'd0;
            end
            else begin
                saxi_arready <=1'd1;
            end
           
        end
    end
    
   always @(*)begin ///tap bram storage
         
        if(data_EN||sm_tlast==1'd1)begin
            bram_tap_A = bram_tap_A_1;
            bram_tap_WE=4'b0000;
        end
        else begin
            if(rready==1'd1 && bram_tap_complete==1'd0)begin
                bram_tap_A={12'b0000_0111_1111 & araddr};
                bram_tap_WE=4'b0000;
            end 
            case (bram_tap_counter)
            3'd0:begin
                bram_tap_WE=4'b0000;
            end
            3'd1:begin 
                bram_tap_Di=wdata;
                bram_tap_A={12'b0000_0111_1111 & awaddr};
                bram_tap_WE=4'b1111;
            end
            default:begin
                 bram_tap_WE=4'b0000;
            end
            
        endcase
        end
        if(!wvalid || bram_tap_counter==3'd0|| bram_tap_counter==3'd1)begin
            saxi_wready=1'd1;
        end
        else begin
            saxi_wready=1'd0;
        end
        if(!awvalid || bram_tap_counter==3'd0|| bram_tap_counter==3'd1)begin
            saxi_awready=1'd1;
        end 
        else begin
            saxi_awready=1'd0;
        end
        
        
        
    end
   
        always @(*)begin//testing tap_dram
            if(rready==1'd1 && bram_tap_complete==1'd0)begin
                case(bram_tap_A>>2)
                    12'd0:saxi_rdata = tap_Do;
                    12'd1:saxi_rdata = tap_Do;
                    12'd2:saxi_rdata = tap_Do;
                    12'd3:saxi_rdata = tap_Do;
                    12'd4:saxi_rdata = tap_Do;
                    12'd5:saxi_rdata = tap_Do;
                    12'd6:saxi_rdata = tap_Do;
                    12'd7:saxi_rdata = tap_Do;
                    12'd8:saxi_rdata = tap_Do;
                    12'd9:saxi_rdata = tap_Do;
                    12'd10:saxi_rdata = tap_Do;
                    default:saxi_rdata = tap_Do;
                endcase
            end
            else if(axis_rst_n==1'd1&&awaddr!=12'h00&&wdata!=32'h01&&bram_tap_complete!=1'd1)begin
            saxi_rdata = 32'h01; 
        
            end
            else if(awaddr==12'h00&&wdata==32'h01&&ss_tlast==1'd0)begin
                saxi_rdata = 32'h00;
            end
            else if(ss_tlast==1'd1&&axistream_smtlast==1'd1&&idle==1'd0)begin
                saxi_rdata = 32'h02;
            end
            else if(axistream_smtlast==1'd1&&idle==1'd1)begin
                saxi_rdata = 32'h04;
            end
            else if(bram_tap_complete)begin
                saxi_rdata = tap_Do;
            end
            else begin
                saxi_rdata = 32'h00;
            end
        end
        
       always @(*)begin//call tap_bram
        case(count_tap)
            4'd0:bram_tap_A_1=12'd0<<2;
            4'd1:bram_tap_A_1=12'd1<<2;
            4'd2:bram_tap_A_1=12'd2<<2;
            4'd3:bram_tap_A_1=12'd3<<2;
            4'd4:bram_tap_A_1=12'd4<<2;
            4'd5:bram_tap_A_1=12'd5<<2;
            4'd6:bram_tap_A_1=12'd6<<2;
            4'd7:bram_tap_A_1=12'd7<<2;
            4'd8:bram_tap_A_1=12'd8<<2;
            4'd9:bram_tap_A_1=12'd9<<2;
            4'd10:bram_tap_A_1=12'd10<<2;
            default:bram_tap_A_1=12'd0<<2;
        endcase
        
    end
    
    always @(*)begin//call data_bram
        
        if(~axis_rst_n)begin
            bram_data_A_1=12'd0;
        end
        else begin
            buff=1'd0;
        end
			case(count_data)
				 4'd0:bram_data_A_1=12'd0<<2;
				 4'd1:bram_data_A_1=12'd1<<2;
				 4'd2:bram_data_A_1=12'd2<<2;
				 4'd3:bram_data_A_1=12'd3<<2;
				 4'd4:bram_data_A_1=12'd4<<2;
				 4'd5:bram_data_A_1=12'd5<<2;
				 4'd6:bram_data_A_1=12'd6<<2;
				 4'd7:bram_data_A_1=12'd7<<2;
				 4'd8:bram_data_A_1=12'd8<<2;
				 4'd9:bram_data_A_1=12'd9<<2;
				 4'd10:bram_data_A_1=12'd10<<2;
				 default:bram_data_A_1=12'd0<<2;
			endcase
    end
endmodule
