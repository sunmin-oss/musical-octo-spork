module clock (
    input CLOCK_50,         // 50MHz 時鐘輸入
    input [3:0] KEY,        // KEY[0]:復位, KEY[1]:模式切換, KEY[2]:啟動/暫停, KEY[3]:計時器重置
    input [17:0] SW,        // 開關
    
    // LCD 介面
    output reg LCD_EN,      
    output reg LCD_RS,      
    output reg LCD_RW,      
    output [7:0] LCD_DATA,  
    
    // LED輸出
    output reg [17:0] LEDR, 
    output reg [8:0] LEDG,  
    
    // 七段顯示器
    output reg [6:0] HEX0,  // 秒個位
    output reg [6:0] HEX1,  // 秒十位
    output reg [6:0] HEX2,  // 分個位
    output reg [6:0] HEX3,  // 分十位
    output reg [6:0] HEX4,  // 時個位
    output reg [6:0] HEX5   // 時十位
);

    // 系統參數
    reg [31:0] clk_divider;     // 分頻計數器
    reg [1:0] mode;             // 00:時鐘, 01:計時器, 10:時間設置
    reg timer_running;          // 計時器運行標誌
    
    // 時鐘計數器
    reg [5:0] clock_seconds;
    reg [5:0] clock_minutes;
    reg [4:0] clock_hours;
    
    // 計時器計數器
    reg [5:0] timer_seconds;
    reg [5:0] timer_minutes;
    reg [4:0] timer_hours;
    
    // LCD控制
    reg [7:0] lcd_data_out;
    reg [3:0] lcd_state;
    reg [19:0] lcd_delay;
    
    // LCD輸出控制
    assign LCD_DATA = (LCD_RW) ? 8'hzz : lcd_data_out;

    // 初始化
    initial begin
        mode = 2'b00;
        timer_running = 0;
        clock_hours = 5'd11;    // 設置初始時間為 11:04:42
        clock_minutes = 6'd04;
        clock_seconds = 6'd42;
        timer_hours = 0;
        timer_minutes = 0;
        timer_seconds = 0;
    end

    // 1Hz時基產生
    always @(posedge CLOCK_50 or negedge KEY[0]) begin
        if (!KEY[0]) begin
            clk_divider <= 0;
        end else begin
            if (clk_divider >= 50000000 - 1)
                clk_divider <= 0;
            else
                clk_divider <= clk_divider + 1;
        end
    end

    // 模式控制和時間更新
    always @(posedge CLOCK_50 or negedge KEY[0]) begin
        if (!KEY[0]) begin
            // 系統復位
            mode <= 2'b00;
            timer_running <= 0;
            clock_hours <= 5'd11;
            clock_minutes <= 6'd04;
            clock_seconds <= 6'd42;
            timer_hours <= 0;
            timer_minutes <= 0;
            timer_seconds <= 0;
        end else begin
            // 模式切換 (KEY[1])
            if (!KEY[1] && !timer_running) begin
                mode <= mode + 1;
                if (mode == 2'b10) mode <= 2'b00;
            end
            
            // 計時器控制 (KEY[2]: 啟動/暫停)
            if (!KEY[2] && mode == 2'b01) begin
                timer_running <= !timer_running;
            end
            
            // 計時器重置 (KEY[3])
            if (!KEY[3] && mode == 2'b01) begin
                timer_hours <= 0;
                timer_minutes <= 0;
                timer_seconds <= 0;
                timer_running <= 0;
            end
            
            // 時間更新 (1Hz)
            if (clk_divider == 0) begin
                // 時鐘更新
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
                
                // 計時器更新
                if (mode == 2'b01 && timer_running) begin
                    if (timer_seconds == 59) begin
                        timer_seconds <= 0;
                        if (timer_minutes == 59) begin
                            timer_minutes <= 0;
                            if (timer_hours == 23)
                                timer_hours <= 0;
                            else
                                timer_hours <= timer_hours + 1;
                        end else
                            timer_minutes <= timer_minutes + 1;
                    end else
                        timer_seconds <= timer_seconds + 1;
                end
            end
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
                LEDR <= SW;
            end
        endcase
    end

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

    // 七段顯示更新
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
        endcase
    end

   // LCD狀態機狀態定義
    parameter INIT      = 8'h00;  // 初始化狀態
    parameter INIT_WAIT = 8'h01;  // 初始化等待
    parameter READY     = 8'h02;  // 準備狀態
    parameter WRITE_CMD = 8'h03;  // 寫命令
    parameter WRITE_DATA = 8'h04; // 寫數據
    parameter DELAY     = 8'h05;  // 延遲狀態

    // LCD命令定義
    parameter LCD_INIT1  = 8'h38;  // 8-bit, 2-line, 5x7 dots
    parameter LCD_INIT2  = 8'h0C;  // Display ON, cursor OFF
    parameter LCD_INIT3  = 8'h06;  // Auto increment address
    parameter LCD_INIT4  = 8'h01;  // Clear display
    parameter LCD_INIT5  = 8'h80;  // Set DDRAM address

    // LCD控制狀態機
    always @(posedge CLOCK_50 or negedge KEY[0]) begin
        if (!KEY[0]) begin
            lcd_state <= INIT;
            LCD_EN <= 0;
            LCD_RS <= 0;
            LCD_RW <= 0;
            delay_cnt <= 0;
            lcd_data_out <= 8'h00;
        end else begin
            case (lcd_state)
                INIT: begin
                    case (delay_cnt[19:17])
                        3'b000: begin
                            LCD_EN <= 0;
                            LCD_RS <= 0;
                            LCD_RW <= 0;
                            lcd_data_out <= LCD_INIT1;
                            if (delay_cnt[16:0] == 17'h1FFFF) begin
                                LCD_EN <= 1;
                                delay_cnt <= delay_cnt + 1;
                            end else begin
                                delay_cnt <= delay_cnt + 1;
                            end
                        end
                        3'b001: begin
                            LCD_EN <= 0;
                            lcd_data_out <= LCD_INIT2;
                            if (delay_cnt[16:0] == 17'h1FFFF) begin
                                LCD_EN <= 1;
                                delay_cnt <= delay_cnt + 1;
                            end else begin
                                delay_cnt <= delay_cnt + 1;
                            end
                        end
                        3'b010: begin
                            LCD_EN <= 0;
                            lcd_data_out <= LCD_INIT3;
                            if (delay_cnt[16:0] == 17'h1FFFF) begin
                                LCD_EN <= 1;
                                delay_cnt <= delay_cnt + 1;
                            end else begin
                                delay_cnt <= delay_cnt + 1;
                            end
                        end
                        3'b011: begin
                            LCD_EN <= 0;
                            lcd_data_out <= LCD_INIT4;
                            if (delay_cnt[16:0] == 17'h1FFFF) begin
                                LCD_EN <= 1;
                                delay_cnt <= delay_cnt + 1;
                            end else begin
                                delay_cnt <= delay_cnt + 1;
                            end
                        end
                        3'b100: begin
                            LCD_EN <= 0;
                            lcd_data_out <= LCD_INIT5;
                            if (delay_cnt[16:0] == 17'h1FFFF) begin
                                LCD_EN <= 1;
                                lcd_state <= READY;
                                delay_cnt <= 0;
                            end else begin
                                delay_cnt <= delay_cnt + 1;
                            end
                        end
                        default: delay_cnt <= delay_cnt + 1;
                    endcase
                end

                READY: begin
                    LCD_EN <= 0;
                    if (delay_cnt == 20'hFFFFF) begin
                        LCD_RS <= 0;
                        LCD_RW <= 0;
                        lcd_data_out <= 8'h80;  // 設置第一行DDRAM地址
                        lcd_state <= WRITE_CMD;
                        delay_cnt <= 0;
                    end else begin
                        delay_cnt <= delay_cnt + 1;
                    end
                end

                WRITE_CMD: begin
                    if (delay_cnt < 20'hFFFF) begin
                        LCD_EN <= 1;
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        LCD_EN <= 0;
                        LCD_RS <= 1;  // 準備寫數據
                        lcd_state <= WRITE_DATA;
                        delay_cnt <= 0;
                    end
                end

                WRITE_DATA: begin
                    case (delay_cnt[19:16])
                        4'h0: begin  // 第一行顯示模式
                            LCD_RS <= 0;
                            lcd_data_out <= 8'h80;
                        end
                        4'h1: begin
                            LCD_RS <= 1;
                            case (mode)
                                2'b00: lcd_data_out <= "C";  // Clock Mode
                                2'b01: lcd_data_out <= timer_running ? "R" : "S";  // Running/Stop
                                2'b10: lcd_data_out <= "M";  // Mode Set
                            endcase
                        end
                        4'h2: begin  // 移到第二行
                            LCD_RS <= 0;
                            lcd_data_out <= 8'hC0;
                        end
                        4'h3: begin  // 時間顯示
                            LCD_RS <= 1;
                            case (mode)
                                2'b00: begin  // 時鐘模式
                                    case (delay_cnt[18:16])
                                        3'b000: lcd_data_out <= ((clock_hours / 10) + 8'h30);
                                        3'b001: lcd_data_out <= ((clock_hours % 10) + 8'h30);
                                        3'b010: lcd_data_out <= 8'h3A;  // :
                                        3'b011: lcd_data_out <= ((clock_minutes / 10) + 8'h30);
                                        3'b100: lcd_data_out <= ((clock_minutes % 10) + 8'h30);
                                        3'b101: lcd_data_out <= 8'h3A;  // :
                                        3'b110: lcd_data_out <= ((clock_seconds / 10) + 8'h30);
                                        3'b111: lcd_data_out <= ((clock_seconds % 10) + 8'h30);
                                    endcase
                                end
                                2'b01: begin  // 計時器模式
                                    case (delay_cnt[18:16])
                                        3'b000: lcd_data_out <= ((timer_hours / 10) + 8'h30);
                                        3'b001: lcd_data_out <= ((timer_hours % 10) + 8'h30);
                                        3'b010: lcd_data_out <= 8'h3A;
                                        3'b011: lcd_data_out <= ((timer_minutes / 10) + 8'h30);
                                        3'b100: lcd_data_out <= ((timer_minutes % 10) + 8'h30);
                                        3'b101: lcd_data_out <= 8'h3A;
                                        3'b110: lcd_data_out <= ((timer_seconds / 10) + 8'h30);
                                        3'b111: lcd_data_out <= ((timer_seconds % 10) + 8'h30);
                                    endcase
                                end
                                2'b10: begin  // 設定模式
                                    case (delay_cnt[18:16])
                                        3'b000: lcd_data_out <= "S";
                                        3'b001: lcd_data_out <= "E";
                                        3'b010: lcd_data_out <= "T";
                                        3'b011: lcd_data_out <= " ";
                                        3'b100: lcd_data_out <= ("0" + set_position);
                                        default: lcd_data_out <= " ";
                                    endcase
                                end
                            endcase
                        end
                        default: begin
                            lcd_state <= DELAY;
                            LCD_EN <= 0;
                        end
                    endcase

                    if (delay_cnt[15:0] < 16'hFFFF) begin
                        LCD_EN <= 1;
                        delay_cnt <= delay_cnt + 1;
                    end else begin
                        LCD_EN <= 0;
                        delay_cnt <= delay_cnt + 1;
                    end
                end

                DELAY: begin
                    LCD_EN <= 0;
                    if (delay_cnt < 20'hFFFFF)
                        delay_cnt <= delay_cnt + 1;
                    else begin
                        lcd_state <= READY;
                        delay_cnt <= 0;
                    end
                end

                default: lcd_state <= INIT;
            endcase
        end
    end

endmodule