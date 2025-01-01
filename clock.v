module clock (
    input CLOCK_50,         // 50MHz 時鐘輸入
    input [3:0] KEY,        // 按鈕輸入 (active low)
    input [17:0] SW,        // 開關
    
    // LCD 介面
    output reg LCD_EN,      // LCD Enable
    output reg LCD_RS,      // LCD Command/Data Select
    output reg LCD_RW,      // LCD Read/Write
    output [7:0] LCD_DATA,  // LCD Data Bus
    
    // LED輸出
    output reg [17:0] LEDR, // 紅色LED
    output reg [8:0] LEDG,  // 綠色LED
    
    // 七段顯示器
    output reg [6:0] HEX0,  // 秒個位
    output reg [6:0] HEX1,  // 秒十位
    output reg [6:0] HEX2,  // 分個位
    output reg [6:0] HEX3,  // 分十位
    output reg [6:0] HEX4,  // 時個位
    output reg [6:0] HEX5   // 時十位
);

    // 時鐘參數
    reg [5:0] clock_seconds = 6'd1;    // 時鐘秒 (初始值)
    reg [5:0] clock_minutes = 6'd2;    // 時鐘分 (初始值)
    reg [4:0] clock_hours = 5'd11;     // 時鐘時 (初始值)
    
    // 計時器參數
    reg [5:0] timer_seconds;
    reg [5:0] timer_minutes;
    reg [4:0] timer_hours;
    
    // 系統控制
    reg [31:0] counter;           // 分頻計數器
    reg timer_running;            // 計時器運行標誌
    reg [1:0] mode;              // 0:時鐘模式, 1:計時器模式, 2:時間設置
    reg [1:0] set_position;      // 0:小時, 1:分鐘, 2:秒
    
    // LCD控制
    reg [7:0] lcd_data_out;
    reg [7:0] lcd_state;
    reg [19:0] delay_cnt;
    
    // LCD輸出控制
    assign LCD_DATA = (LCD_RW) ? 8'hzz : lcd_data_out;

    // LCD命令定義
    parameter LCD_INIT1  = 8'h38;  // 8-bit, 2-line, 5x7 dots
    parameter LCD_INIT2  = 8'h0C;  // Display ON, cursor OFF
    parameter LCD_INIT3  = 8'h06;  // Auto increment address
    parameter LCD_INIT4  = 8'h01;  // Clear display
    parameter LCD_INIT5  = 8'h80;  // Set DDRAM address

    // 模式和按鈕控制
    always @(posedge CLOCK_50 or negedge KEY[0]) begin
        if (!KEY[0]) begin
            // 系統復位
            mode <= 2'b00;
            timer_running <= 0;
            timer_seconds <= 0;
            timer_minutes <= 0;
            timer_hours <= 0;
            clock_seconds <= 6'd1;
            clock_minutes <= 6'd2;
            clock_hours <= 5'd11;
            counter <= 0;
            set_position <= 0;
        end else begin
            // 計數器更新
            if (counter >= 50000000 - 1) begin
                counter <= 0;
                
                // 時鐘模式更新
                if (mode == 2'b00) begin
                    if (clock_seconds == 59) begin
                        clock_seconds <= 0;
                        if (clock_minutes == 59) begin
                            clock_minutes <= 0;
                            if (clock_hours == 23)
                                clock_hours <= 0;
                            else
                                clock_hours <= clock_hours + 1;
                        end else
                            clock_minutes <= clock_minutes + 1;
                    end else
                        clock_seconds <= clock_seconds + 1;
                end
                
                // 計時器模式更新
                if (mode == 2'b01 && timer_running) begin
                    if (timer_seconds == 59) begin
                        timer_seconds <= 0;
                        if (timer_minutes == 59) begin
                            timer_minutes <= 0;
                            timer_hours <= timer_hours + 1;
                        end else
                            timer_minutes <= timer_minutes + 1;
                    end else
                        timer_seconds <= timer_seconds + 1;
                end
            end else
                counter <= counter + 1;

            // 按鈕控制
            if (!KEY[1] && !timer_running) begin  // MODE
                mode <= mode + 1;
                if (mode == 2'b10) mode <= 2'b00;
            end
            
            if (!KEY[2]) begin  // START/STOP
                if (mode == 2'b01)  // 計時器模式
                    timer_running <= !timer_running;
            end
            
            if (!KEY[3]) begin  // RESET/SET
                if (mode == 2'b01) begin  // 計時器模式
                    timer_seconds <= 0;
                    timer_minutes <= 0;
                    timer_hours <= 0;
                    timer_running <= 0;
                end else if (mode == 2'b10) begin  // 設置模式
                    set_position <= set_position + 1;
                    if (set_position == 2'b10) set_position <= 2'b00;
                end
            end
        end
    end

    // 時間設置控制
    always @(posedge CLOCK_50) begin
        if (mode == 2'b10) begin  // 設置模式
            case (set_position)
                2'b00: clock_hours <= SW[4:0];    // 設置小時
                2'b01: clock_minutes <= SW[5:0];  // 設置分鐘
                2'b10: clock_seconds <= SW[5:0];  // 設置秒
            endcase
        end
    end

    // LED顯示控制
    always @(posedge CLOCK_50) begin
        case (mode)
            2'b00: begin  // 時鐘模式
                LEDG <= 9'b000000001;
                LEDR <= (1 << clock_seconds[4:0]);
            end
            2'b01: begin  // 計時器模式
                LEDG <= timer_running ? 9'b000000010 : 9'b000000100;
                LEDR <= (1 << timer_seconds[4:0]);
            end
            2'b10: begin  // 設置模式
                LEDG <= 9'b000001000;
                LEDR <= SW[17:0];
            end
        endcase
    end

    // 七段顯示更新
    reg [22:0] blink_counter;
    wire blink_state;
    
    always @(posedge CLOCK_50) begin
        blink_counter <= blink_counter + 1;
    end
    
    assign blink_state = blink_counter[22];

    // 七段顯示解碼函數
    function [6:0] seven_seg;
        input [3:0] digit;
        begin
            case (digit)
                4'h0: seven_seg = 7'b1000000;
                4'h1: seven_seg = 7'b1111001;
                4'h2: seven_seg = 7'b0100100;
                4'h3: seven_seg = 7'b0110000;
                4'h4: seven_seg = 7'b0011001;
                4'h5: seven_seg = 7'b0010010;
                4'h6: seven_seg = 7'b0000010;
                4'h7: seven_seg = 7'b1111000;
                4'h8: seven_seg = 7'b0000000;
                4'h9: seven_seg = 7'b0010000;
                default: seven_seg = 7'b1111111;
            endcase
        end
    endfunction

    // 七段顯示器更新
    always @(posedge CLOCK_50) begin
        case (mode)
            2'b00: begin  // 時鐘模式
                HEX0 <= seven_seg(clock_seconds % 10);
                HEX1 <= seven_seg(clock_seconds / 10);
                HEX2 <= seven_seg(clock_minutes % 10);
                HEX3 <= seven_seg(clock_minutes / 10);
                HEX4 <= seven_seg(clock_hours % 10);
                HEX5 <= seven_seg(clock_hours / 10);
            end
            2'b01: begin  // 計時器模式
                HEX0 <= seven_seg(timer_seconds % 10);
                HEX1 <= seven_seg(timer_seconds / 10);
                HEX2 <= seven_seg(timer_minutes % 10);
                HEX3 <= seven_seg(timer_minutes / 10);
                HEX4 <= seven_seg(timer_hours % 10);
                HEX5 <= seven_seg(timer_hours / 10);
            end
            2'b10: begin  // 設置模式
                case (set_position)
                    2'b00: begin  // 設置小時
                        HEX0 <= seven_seg(clock_seconds % 10);
                        HEX1 <= seven_seg(clock_seconds / 10);
                        HEX2 <= seven_seg(clock_minutes % 10);
                        HEX3 <= seven_seg(clock_minutes / 10);
                        HEX4 <= blink_state ? seven_seg(SW[4:0] % 10) : 7'b1111111;
                        HEX5 <= blink_state ? seven_seg(SW[4:0] / 10) : 7'b1111111;
                    end
                    2'b01: begin  // 設置分鐘
                        HEX0 <= seven_seg(clock_seconds % 10);
                        HEX1 <= seven_seg(clock_seconds / 10);
                        HEX2 <= blink_state ? seven_seg(SW[5:0] % 10) : 7'b1111111;
                        HEX3 <= blink_state ? seven_seg(SW[5:0] / 10) : 7'b1111111;
                        HEX4 <= seven_seg(clock_hours % 10);
                        HEX5 <= seven_seg(clock_hours / 10);
                    end
                    2'b10: begin  // 設置秒
                        HEX0 <= blink_state ? seven_seg(SW[5:0] % 10) : 7'b1111111;
                        HEX1 <= blink_state ? seven_seg(SW[5:0] / 10) : 7'b1111111;
                        HEX2 <= seven_seg(clock_minutes % 10);
                        HEX3 <= seven_seg(clock_minutes / 10);
                        HEX4 <= seven_seg(clock_hours % 10);
                        HEX5 <= seven_seg(clock_hours / 10);
                    end
                endcase
            end
        endcase
    end

    // [LCD控制代碼與之前相同，但顯示內容需要根據模式更改]

endmodule