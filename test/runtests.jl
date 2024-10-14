using Poppy
using Test

macro namedtest(name, test)
    esc(:(@testset $name begin @test $test end))
end

function pad_string(s, width)
    length_s = length(s)
    if length_s >= width
        return s
    else
        return s * " "^(width - length_s)
    end
end

@testset "Poppy" begin
    @testset "PoppyCore" begin
        @testset "Set & Extract FEN" begin
            positions = readlines("data/perft_big.txt")
            for position in positions
                if startswith(position, "#") continue end
                fen, _ = split(position, ";")
                fen = string(strip(fen))
                @namedtest "$fen" begin
                    board = PoppyCore.Board()
                    PoppyCore.set_by_fen!(board, fen)
                    PoppyCore.extract_fen(board) == fen
                end
            end
        end
        @testset "Perft" begin
            positions = readlines("data/perft_big.txt")
            println("+--------------------------------------------------------------------------------------+--------+------------+------------+-------------------+");
            println("| FEN                                                                                  | Depth  | Expected   | Result     | MNodes per second |");
            println("+--------------------------------------------------------------------------------------+--------+------------+------------+-------------------+");
            
            global_nodes = 0
            global_start = time_ns()
            global_fail_count = 0

            for position in positions
                if startswith(position, "#") continue end
                split_str = split(position, ";")
                fen = string(strip(split_str[1]))
                for depth_result_tuple in split_str[2:end]
                    depth, result = split(string(strip(depth_result_tuple)), " ")
                    @namedtest "$fen depth:$depth" begin
                        board = PoppyCore.Board()
                        PoppyCore.set_by_fen!(board, fen)
                        start = time_ns()
                        nodes = PoppyCore.perft!(board, parse(Int, depth))
                        duration = time_ns() - start
                        global_nodes += nodes
                        println("| $(pad_string(fen, 84)) | $(pad_string(string(depth), 6)) | $(pad_string(string(nodes), 10)) | $(pad_string(string(result), 10)) | $(pad_string(string(round((nodes/duration)*1000, digits=3)), 17)) |")
                        println("+--------------------------------------------------------------------------------------+--------+------------+------------+-------------------+");
                        nodes == parse(Int, result)
                    end
                end
            end

            global_duration = time_ns() - global_start
            global_nodes_per_second = round((global_nodes/global_duration)*1000, digits=3)
            println("Total nodes: $(global_nodes)")
            println("Total time: $(round(1e-9*global_duration, digits=2)) seconds")
            println("Total nodes per second: $(global_nodes_per_second) MNodes/s")
            
        end
    end
end