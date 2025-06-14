using Flux
using Flux: onehotbatch, flatten, Conv, BatchNorm, relu, Dense, Dropout
using Statistics: mean
using CUDA
using BSON: @save
using Dates
using Printf

CUDA.has_cuda()

@inline function to_device(x)
    CUDA.has_cuda() ? gpu(x) : x
end

function res_block(in_channels, out_channels)
    return Chain(
        Conv((3, 3), in_channels => out_channels, pad=1),
        BatchNorm(out_channels),
        relu,
        Conv((3, 3), out_channels => out_channels, pad=1),
        BatchNorm(out_channels),
        x -> relu.(x .+ (in_channels == out_channels ? x : zeros(size(x))))
    )
end

function evaluate_on_game(model, game_str::AbstractString)
    board = Board()
    set_by_fen!(board, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

    correct = 0
    total = 0

    for move_str in split(game_str)
        _, legals = generate_legals(board)
        move = extract_move_by_san(board, move_str)

        best_idx = findfirst(mv -> mv.src == move.src && mv.dst == move.dst && mv.type == move.type, legals)
        if isnothing(best_idx) || length(legals) < 2
            do_move!(board, move)
            continue
        end

        legals[1], legals[best_idx] = legals[best_idx], legals[1]
        tensors = boards_to_tensors(board, legals)
        inputs = [to_device(reshape(permutedims(t, (2,3,1)), 8,8,N_PLANES,1)) for t in tensors]
        outputs = map(x -> model(x)[1], inputs)

        predicted = argmax(outputs)
        correct += (predicted == 1 ? 1 : 0)
        total += 1

        do_move!(board, move)
    end

    return total == 0 ? 0.0 : correct / total
end


function upload_to_s3(path::String, s3_bucket::String)
    s3_key = splitpath(path)[end]  # just the filename
    s3_path = "s3://$s3_bucket/models/$s3_key"
    try
        run(`aws s3 cp $path $s3_path`)
        println("Uploaded $path to $s3_path")
    catch e
        println("Failed to upload to S3: $e")
    end
end

function train_model_nn(training_file::String; test_and_dump_every=1000, s3_bucket="")
    println("Running system checks...")

    if CUDA.has_cuda()
        println("CUDA available")
    else
        println("CUDA not available— aborting.")

        return
    end

    if s3_bucket != ""
        test_file = "/tmp/s3_test_file.txt"
        open(test_file, "w") do f
            write(f, "s3 test")
        end
        try
            upload_to_s3(test_file, s3_bucket)
            println("S3 upload test passed")
        catch e
            println("S3 upload test failed — aborting.")
            println(e)
            return
        end
    else
        println("No S3 bucket provided — skipping S3 test.")
    end

    println("System checks done.")


    metadata = TrainingMetadata(training_file)

    model = Chain(
        Conv((3,3), N_PLANES => 64, pad=1), BatchNorm(64), relu,
        res_block(64, 64),
        res_block(64, 64),
        flatten,
        Dense(64 * 8 * 8, 256), relu, Dropout(0.3),
        Dense(256, 1)
    ) |> to_device

    opt = ADAM(0.001)
    opt_state = Flux.setup(opt, model)

    mkpath("models")

    num_lines = count_lines_in_files(training_file)
    println("Training on file: $training_file with $num_lines lines")

    open(training_file) do games    
        while !eof(games)
            metadata.count += 1
            game_str = strip(readline(games))
            

            if metadata.count % test_and_dump_every == 0
                acc = evaluate_on_game(model, game_str)
                println("\nAccuracy = $acc")

                timestamp = Dates.format(now(), "yyyymmdd_HHMM")
                path = @sprintf "models/model_%s_%d.bson" timestamp metadata.count
                @save path model opt opt_state
                println("Saved model after test to $path")

                if s3_bucket != ""
                    upload_to_s3(path, s3_bucket)
                end

                continue  # skip training on this game
            end

            train_on_game_nn!(model, opt_state, opt, game_str)
            print(metadata)
        end
    end

    final_path = "models/model_final.bson"
    @save final_path model opt opt_state
    println("Finished training ", metadata.count, " games and saved final model")

    if s3_bucket != ""
        upload_to_s3(final_path, s3_bucket)
    end
end

function ranking_update_nn!(model, opt_state, opt, tensors::Vector{Array{Float32, 3}})
    expert_tensor = to_device(reshape(permutedims(tensors[1], (2, 3, 1)), 8, 8, N_PLANES, 1))
    other_tensors = [to_device(reshape(t, (8, 8, N_PLANES, 1))) for t in tensors[2:end]]

    grads = Flux.gradient(model) do m
        V_star = m(expert_tensor)[1]
        losses = map(t -> max(0.0f0, 1.0f0 - (V_star - m(t)[1])), other_tensors)
        mean(losses)
    end

    Flux.Optimise.update!(opt_state, model, grads[1])
end

function train_on_game_nn!(model, opt_state, opt, game_str::AbstractString)
    board = Board()
    set_by_fen!(board, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

    move_strings = split(game_str)
    for move_str in move_strings
        _, legals = generate_legals(board)
        move = extract_move_by_san(board, move_str)

        best_idx = findfirst(mv -> mv.src == move.src && mv.dst == move.dst && mv.type == move.type, legals)
        legals[1], legals[best_idx] = legals[best_idx], legals[1]

        if length(legals) > 1
            board_tensors = boards_to_tensors(board, legals)
            ranking_update_nn!(model, opt_state, opt, board_tensors)
        end

        do_move!(board, move)
    end
end


const N_PIECE_PLANES = 12  # 6 white + 6 black
const N_PLANES = 14        # piece planes + side + castling

const piece_to_plane = Dict(
    WHITE_PAWN   => 1,
    WHITE_KNIGHT => 2,
    WHITE_BISHOP => 3,
    WHITE_ROOK   => 4,
    WHITE_QUEEN  => 5,
    WHITE_KING   => 6,
    BLACK_PAWN   => 7,
    BLACK_KNIGHT => 8,
    BLACK_BISHOP => 9,
    BLACK_ROOK   => 10,
    BLACK_QUEEN  => 11,
    BLACK_KING   => 12,
)

@inline function board_to_tensor(board::Board)::Array{Float32,3}
    tensor = zeros(Float32, N_PLANES, 8, 8)
    squares = board.squares  # local var for faster access
    for sq in 0:63
        piece = squares[sq + 1]
        plane = get(piece_to_plane, piece, 0)
        if plane != 0
            rank = 8 - (sq ÷ 8)
            file = (sq % 8) + 1
            @inbounds tensor[plane, rank, file] = 1.0f0
        end
    end

    tensor[N_PIECE_PLANES + 1, :, :] .= board.side_to_move == WHITE ? 1.0f0 : 0.0f0

    castling = board.history[end].castling_rights
    mask = (castling & CASTLING_WK != 0 ? 1 : 0) +
           (castling & CASTLING_WQ != 0 ? 2 : 0) +
           (castling & CASTLING_BK != 0 ? 4 : 0) +
           (castling & CASTLING_BQ != 0 ? 8 : 0)

    tensor[N_PIECE_PLANES + 2, :, :] .= Float32(mask)
    return tensor
end

function boards_to_tensors(board::Board, legals::Vector{Move})
    result = Vector{Array{Float32,3}}(undef, length(legals))
    for (i, mv) in enumerate(legals)
        do_move!(board, mv)
        result[i] = board_to_tensor(board)
        undo_move!(board, mv)
    end
    return result
end

