function train_on_game(game_str::T, model::ValueTable, metadata::TrainingMetadata; with_prediction=false) where T<:AbstractString
    # SET BOARD INTO INITIAL STATE
    board = Board()
    set_by_fen!(board, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

    move_strings = split(game_str)
    for (i, move_str) in enumerate(move_strings)
        # generate all legal moves for board b
        # and sort the played move to the front of the list
        # since it is the best move in the expert's opinion
        _, legals = generate_legals(board)
        move = extract_move_by_san(board, move_str)
        best_move_idx = findfirst(mv -> mv.src == move.src && mv.dst == move.dst && mv.type == move.type, legals)
        legals[1], legals[best_move_idx] = legals[best_move_idx], legals[1]

        # make an prediction given the current model
        if with_prediction
            prediction = predict_on(model, board, legals)
            push!(metadata.predictions, prediction)
        end

        # UPDATE THE MODEL (i.e. the feature values)
        features_of_all_boards = extract_features_from_all_boards(board, legals)
        ranking_update!(model, features_of_all_boards, loop_eps=0.1, beta=5.0)

        do_move!(board, move)
    end
end

function train_on_game_new(game_str::T, urgencies::Dict{UInt64, Gaussian}, weights::Dict{Tuple{UInt64, UInt64}, Gaussian}, metadata::TrainingMetadata; with_prediction=false) where T<:AbstractString
    # SET BOARD INTO INITIAL STATE
    board = Board()
    set_by_fen!(board, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

    move_strings = split(game_str)
    for (i, move_str) in enumerate(move_strings)

        # generate all legal moves for board b
        # and sort the played move to the front of the list
        # since it is the best move in the expert's opinion
        _, legals = generate_legals(board)
        move = extract_move_by_san(board, move_str)
        best_move_idx = findfirst(mv -> mv.src == move.src && mv.dst == move.dst && mv.type == move.type, legals)
        legals[1], legals[best_move_idx] = legals[best_move_idx], legals[1]
        
        if length(legals) == 1
            do_move!(board, move)
            continue
        end

        # make an prediction given the current model
        if with_prediction
            prediction = predict_on(urgencies, weights, board, legals, beta=5.0)
            push!(metadata.predictions, prediction)
        end

        # UPDATE THE MODEL (i.e. the feature values)
        features_of_all_boards = extract_features_from_all_boards(board, legals)
        ranking_update_new!(urgencies, weights, features_of_all_boards, loop_eps=0.1, beta=5.0)

        do_move!(board, move)
    end
end

function train_model(training_file::String; exclude=[], folder="./data/models", dump_frequency=5000, with_prediction=false)
    # FIND LATEST MODEL VERSION
    files = filter(x -> occursin(r"model_v\d+.*", x), readdir(folder))
    model_version = (isempty(files)) ? 1 : maximum(map(x -> parse(Int, match(r"model_v(\d+).*", x).captures[1]), files)) + 1

    # INITIALIZE EMPTY MODEL
    model = ValueTable(no_bits = 24)

    # HELPER VARIABLES
    metadata = TrainingMetadata(training_file)

    # TRAIN MODEL
    games = open(training_file, "r")
    while !eof(games)
        metadata.count += 1
        game_str = strip(readline(games))

        if count in exclude continue end

        # TRAIN ON GAME
        train_on_game(game_str, model, metadata, with_prediction=with_prediction)
        print(metadata)

        # DUMP MODEL
        if metadata.count % dump_frequency == 0
            filename_dump = abspath(expanduser("$folder/model_v$(model_version)_dump$(metadata.count).txt"))
            save_model(model, filename_dump)
        end
    end

    plot_metadata(metadata, model_version)

    close(games)

    # SAVE MODEL
    filename_model = "$folder/model_v$(model_version).txt"
    save_model(model, filename_model)

    return filename_model
end

function train_model_new(training_file::String; exclude=[], folder="./data/models", dump_frequency=5000, with_prediction=false)
    # FIND LATEST MODEL VERSION
    files = filter(x -> occursin(r"model_v\d+.*", x), readdir(folder))
    model_version = (isempty(files)) ? 1 : maximum(map(x -> parse(Int, match(r"model_v(\d+).*", x).captures[1]), files)) + 1

    # INITIALIZE EMPTY MODEL
    urgencies = Dict{UInt64, Gaussian}()
    weights = Dict{Tuple{UInt64, UInt64}, Gaussian}()

    # HELPER VARIABLES
    metadata = TrainingMetadata(training_file)

    # TRAIN MODEL
    games = open(training_file, "r")
    while !eof(games)
        metadata.count += 1
        game_str = strip(readline(games))

        if count in exclude continue end

        # TRAIN ON GAME
        train_on_game_new(game_str, urgencies, weights, metadata, with_prediction=with_prediction)
        print(metadata)

        # DUMP MODEL
        if metadata.count % dump_frequency == 0
            filename_dump = abspath(expanduser("$folder/model_v$(model_version)_dump$(metadata.count).txt"))
            save_model(model, filename_dump)
        end
    end

    plot_metadata(metadata, model_version)

    close(games)

    # SAVE MODEL
    filename_model = "$folder/model_v$(model_version).txt"
    save_model(model, filename_model)

    return filename_model
end


function train_model_by_sampling(fen::String="8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1"; no_samples=100000, beta=1.0, loop_eps=0.1)
    urgencies = Dict{UInt64, Gaussian}()
    weights = Dict{Tuple{UInt64, UInt64}, Gaussian}()

    board = Board()
    set_by_fen!(board, fen)

    _ , legals = generate_legals(board)
    println("legals: ", legals)
    features_of_all_boards = extract_features_from_all_boards(board, legals)

    # ranking_update_by_sampling!(urgencies, weights, features_of_all_boards, no_samples=no_samples, beta=beta)
    
    urgencies2 = Dict{UInt64, Gaussian}()
    weights2 = Dict{Tuple{UInt64, UInt64}, Gaussian}()
    for i = 1:10000
        ranking_update_new!(urgencies2, weights2, features_of_all_boards, beta=beta, loop_eps=loop_eps)
    end
end