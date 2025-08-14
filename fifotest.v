`timescale 1ns / 1ps

module tb_fifo1();

    // Parameters
    parameter DSIZE = 8;
    parameter ASIZE = 7;
    parameter FIFO_DEPTH = 75;
    parameter BURST_SIZE = 100;
    
    // Clock periods
    parameter WCLK_PERIOD = 25;  // 40MHz = 25ns period
    parameter RCLK_PERIOD = 100; // 10MHz = 100ns period
    
    // Testbench signals
    reg [DSIZE-1:0] wdata;
    reg winc, wclk, wrst_n;
    reg rinc, rclk, rrst_n;
    
    wire [DSIZE-1:0] rdata;
    wire wfull, rempty;
    
    // Test control variables
    reg [DSIZE-1:0] reference_memory [0:1023];  // Reference memory for comparison
    integer write_ptr, read_ptr;
    integer write_count, read_count;
    integer error_count;
    reg [DSIZE-1:0] test_data;
    
    // DUT instantiation
    fifo1 #(
        .DSIZE(DSIZE),
        .ASIZE(ASIZE)
    ) dut (
        .rdata(rdata),
        .wfull(wfull),
        .rempty(rempty),
        .wdata(wdata),
        .winc(winc),
        .wclk(wclk),
        .wrst_n(wrst_n),
        .rinc(rinc),
        .rclk(rclk),
        .rrst_n(rrst_n)
    );
    
    // Write clock generation
    initial begin
        wclk = 0;
        forever #(WCLK_PERIOD/2) wclk = ~wclk;
    end
    
    // Read clock generation  
    initial begin
        rclk = 0;
        forever #(RCLK_PERIOD/2) rclk = ~rclk;
    end
    
    // Reset generation
    initial begin
        wrst_n = 0;
        rrst_n = 0;
        #(WCLK_PERIOD * 5);
        wrst_n = 1;
        rrst_n = 1;
    end
    
    // Initialize signals
    initial begin
        wdata = 0;
        winc = 0;
        rinc = 0;
        write_ptr = 0;
        read_ptr = 0;
        write_count = 0;
        read_count = 0;
        error_count = 0;
    end
    
    // Write process
    initial begin
        // Wait for reset
        wait(wrst_n);
        repeat(3) @(posedge wclk);
      
        
        // Write burst of data
        for (int i = 0; i < BURST_SIZE; i++) begin
            // Generate test data
            test_data = $random & 8'hFF;
            
            // Wait until FIFO is not full
            while (wfull) begin
                @(posedge wclk);
                $display("Time: %0t, FIFO Full - waiting", $time);
            end
            
            // Write data
            @(posedge wclk);
            wdata = test_data;
            winc = 1;
            reference_memory[write_ptr] = test_data;
            write_ptr = write_ptr + 1;
            write_count = write_count + 1;
            
            $display("Time: %0t, Write[%0d]: 0x%02h", $time, write_count, test_data);
            
            @(posedge wclk);
            winc = 0;
        end
        
      $display("Write process completed");
        
        // Write more data after reads
        #(RCLK_PERIOD * 10);
        for (int i = 0; i < 25; i++) begin
            test_data = $random & 8'hFF;
            
            while (wfull) begin
                @(posedge wclk);
            end
            
            @(posedge wclk);
            wdata = test_data;
            winc = 1;
            reference_memory[write_ptr] = test_data;
            write_ptr = write_ptr + 1;
            write_count = write_count + 1;
            
            $display("Time: %0t, Write[%0d]: 0x%02h", $time, write_count, test_data);
            
            @(posedge wclk);
            winc = 0;
        end
        
      $display("Second write phase completed");
    end
    
    // Read process
    initial begin
        reg [DSIZE-1:0] expected_data;
        
        // Wait for reset and some data to be written
        wait(rrst_n);
        wait(write_count > 5);
        repeat(3) @(posedge rclk);
        
        
        // Read all written data
        while (read_count < write_count || !rempty) begin
            // Wait until data is available
            while (rempty && read_count < write_count) begin
                @(posedge rclk);
            end
            
            if (!rempty) begin
                // Get expected data
                expected_data = reference_memory[read_ptr];
                
                // Assert read increment
                @(posedge rclk);
                rinc = 1;
                
                // Wait for read to complete
                @(posedge rclk);
                rinc = 0;
                
                // Check data
                read_count = read_count + 1;
                read_ptr = read_ptr + 1;
                
                if (rdata == expected_data) begin
                    $display("Time: %0t, Read[%0d]: 0x%02h", $time, read_count, rdata);
                end else begin
                    $display("Time: %0t, Read[%0d]: 0x%02h (Expected: 0x%02h)", 
                            $time, read_count, rdata, expected_data);
                    error_count = error_count + 1;
                end
            end
            
            // Delay to prevent infinite loop
            if (rempty && read_count >= write_count) break;
        end
        
      $display("Read process completed");
    end
    
    // Test completion and results
    initial begin
        // Wait for all operations to complete
        wait(read_count >= write_count);
        #(RCLK_PERIOD * 5);
        
        $display("FIFO TEST RESULTS");
        $display("Total Writes: %0d", write_count);
        $display("Total Reads:  %0d", read_count);
        $display("Data Errors:  %0d", error_count);
        
        if (error_count == 0 && write_count == read_count) begin
            $display("TEST PASSED");
        end else begin
            $display("TEST FAILED");
            
            // Debug info
            $display("First few reference values:");
            for (int i = 0; i < 10 && i < write_count; i++) begin
                $display("  ref[%0d] = 0x%02h", i, reference_memory[i]);
            end
        end
        
        $finish;
    end
    
    
    // Waveform dump
    initial begin
        $dumpfile("fifo_test.vcd");
        $dumpvars(0, tb_fifo1);
    end

endmodule