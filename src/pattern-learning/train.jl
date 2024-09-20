function train_on_game(game_str::T, urgencies::Dict{UInt64, Gaussian}, metadata::TrainingMetadata; with_prediction=false, mask_in_prior, beta, loop_eps) where T<:AbstractString
    # SET BOARD INTO INITIAL STATE
    board = Board()
    set_by_fen!(board, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

    move_strings = split(game_str)
    for (i, move_str) in enumerate(move_strings)
        # if i == 1
        #     continue
        # end
        print("\r$(metadata.count) games, $(i) moves")
        # generate all legal moves for board b
        # and sort the played move to the front of the list
        # since it is the best move in the expert's opinion
        _, legals = generate_legals(board)
        move = extract_move_by_san(board, move_str)
        best_move_idx = findfirst(mv -> mv.src == move.src && mv.dst == move.dst && mv.type == move.type, legals)
        legals[1], legals[best_move_idx] = legals[best_move_idx], legals[1]

        # make an prediction given the current model
        if with_prediction
            prediction = predict_on(urgencies, board, legals, mask_in_prior=mask_in_prior, beta=beta, loop_eps=loop_eps)
            push!(metadata.predictions, prediction)
        end

        if length(legals) == 1
            do_move!(board, move)
            continue
        end

        # UPDATE THE MODEL (i.e. the feature values)
        features_of_all_boards = extract_features_from_all_boards(board, legals)
        ranking_update!(urgencies, features_of_all_boards, mask_in_prior=mask_in_prior, beta=beta, loop_eps=loop_eps)
        do_move!(board, move)
    end
end

function train_model(training_file::String; exclude=[], folder="./data/models", dump_frequency=5000, with_prediction=false, mask_in_prior=2, beta=0.5)
    # FIND LATEST MODEL VERSION
    files = filter(x -> occursin(r"model_v\d+.*", x), readdir(folder))
    model_version = (isempty(files)) ? 1 : maximum(map(x -> parse(Int, match(r"model_v(\d+).*", x).captures[1]), files)) + 1

    # INITIALIZE EMPTY MODEL
    urgencies = Dict{UInt64, Gaussian}()

    # HELPER VARIABLES
    metadata = TrainingMetadata(training_file)

    # TRAIN MODEL
    games = open(training_file, "r")
    while !eof(games)
        metadata.count += 1
        game_str = strip(readline(games))

        if count in exclude continue end

        # TRAIN ON GAME
        train_on_game(game_str, urgencies, metadata, with_prediction=with_prediction, mask_in_prior=mask_in_prior, beta=beta, loop_eps=0.1)
        print(metadata)

        # DUMP MODEL
        if metadata.count % dump_frequency == 0
            filename_dump = abspath(expanduser("$folder/model_v$(model_version)_dump$(metadata.count).txt"))
            save_model(urgencies, filename_dump)
        end
    end

    plot_metadata(metadata, model_version)

    close(games)

    # SAVE MODEL
    filename_model = "$folder/model_v$(model_version).txt"
    save_model(urgencies, filename_model)

    return filename_model
end


function train_model_by_sampling(fen::String="7K/8/k1P5/7p/8/8/8/8 w - - 0 1"; mask_in_prior::Int=2, no_samples=100000, beta=1.0, logging=false)
    urgencies = Dict{UInt64, Gaussian}()
    urgencies2 = Dict{UInt64, Gaussian}()

    board = Board()
    set_by_fen!(board, fen)

    _ , legals = generate_legals(board)
    features_of_all_boards = extract_features_from_all_boards(board, legals)

    ranking_update_by_sampling!(urgencies, features_of_all_boards, mask_in_prior=mask_in_prior, no_samples=no_samples, beta=beta, logging=logging)


    ranking_update!(urgencies2, features_of_all_boards, mask_in_prior=mask_in_prior, beta=beta, loop_eps=0.01)

    # println();
    # if (logging)
    #     println("urgencies")
    #     for (k,v) in urgencies
    #         println(k, " ", v, " <=> ", urgencies2[k])  
    #     end
    # end

    
    # features_of_all_boards = extract_features_from_all_boards(board, legals)
    # values = calculate_board_values(urgencies, features_of_all_boards, mask_in_prior=mask_in_prior, no_samples=no_samples, beta=beta)
    # best_board_idx = argmax(values)
    
    # for (k,board) in enumerate(legals)
    #     (values[k] > 0.0) ? @printf("board %d:\t+%.4f %s\n", k, values[k], k == best_board_idx ? "✅" : "") : @printf("board %d:\t%.4f %s\n", k, values[k], k == best_board_idx ? "✅" : "")
    # end
end

function test_gated_copy_factor(μ_x, σ_x, μ_y, σ_y, p; fix_variance=false)
    while true
        s = BinaryByProbability(p)
        x = GaussianByMeanVariance(μ_x, σ_x^2)
        y = GaussianByMeanVariance(μ_y, σ_y^2)

        f = BinaryGatedCopyFactor(x, y, s)

        update_msg_to_x!(f)
        update_msg_to_y!(f)
        update_msg_to_s!(f)

        if fix_variance && (variance(f.msg_to_x) < 0.0 || variance(f.msg_to_y) < 0.0)
            p = mean(s)

            if p > 1.0
                p = 1.0
            elseif p < 1e-4
                p = 0.0
            end 
        else
            return variance(f.x), variance(f.y), variance(f.msg_to_x), variance(f.msg_to_y), mean(f.s), mean(f.x), mean(f.y)
        end
    end
end

using Plots
using LaTeXStrings

function plot_gated_copy_factor(μ_x, σ_x, σ_y, p; μ_ys=range(-1.5, 1.5, length=300), fix_variance=false)
    deltas =[μ_x - μ_y for μ_y in μ_ys]

    sigmas_x = [test_gated_copy_factor(μ_x, σ_x, μ_y, σ_y, p, fix_variance = fix_variance)[1] for μ_y in μ_ys]
    sigmas_y = [test_gated_copy_factor(μ_x, σ_x, μ_y, σ_y, p, fix_variance = fix_variance)[2] for μ_y in μ_ys]
    sigmas_msg_to_x = [test_gated_copy_factor(μ_x, σ_x, μ_y, σ_y, p, fix_variance = fix_variance)[3] for μ_y in μ_ys]
    sigmas_msg_to_y = [test_gated_copy_factor(μ_x, σ_x, μ_y, σ_y, p, fix_variance = fix_variance)[4] for μ_y in μ_ys]
    ps = [test_gated_copy_factor(μ_x, σ_x, μ_y, σ_y, p, fix_variance = fix_variance)[5] for μ_y in μ_ys]
    mus_x = [test_gated_copy_factor(μ_x, σ_x, μ_y, σ_y, p, fix_variance = fix_variance)[6] for μ_y in μ_ys]
    mus_y = [test_gated_copy_factor(μ_x, σ_x, μ_y, σ_y, p, fix_variance = fix_variance)[7] for μ_y in μ_ys]

    plt = plot(μ_ys, mus_x, xlabel=L"\mu_y", label=L"\mu_x", lw=5, color=:blue, ribbon=sqrt.(sigmas_x), fillalpha=0.5)
    plot!(μ_ys, mus_y, xlabel=L"\mu_y", label=L"\mu_y", lw=5, color=:red, ribbon=sqrt.(sigmas_y), fillalpha=0.5)
    # plt = plot(μ_ys, sigmas_x, xlabel=L"\mu_y", label=L"\sigma_x^2", lw=5, color=:blue)
    # plot!(μ_ys, sigmas_y, label=L"\sigma_y^2", lw=2, color=:red)    
    # plot!(μ_ys, [σ_x^2 for _ in 1:length(μ_ys)], label=L"\sigma_x^2", lw=4, color=:blue, linestyle=:dash)
    # plot!(μ_ys, [σ_y^2 for _ in 1:length(μ_ys)], label=L"\sigma_y^2", lw=2, color=:red, linestyle=:dash)
    # plot!(μ_ys, sigmas_msg_to_x, label=L"\sigma_{\text{msg to }x}^2", lw=2, color=:blue, linestyle=:dot)
    # plot!(μ_ys, sigmas_msg_to_y, label=L"\sigma_{\text{msg to }y}^2", lw=2, color=:red, linestyle=:dot)
    plot!(μ_ys, ps, label=L"p", lw=2, color=:green)

    title!(string(L"\mu_x=", μ_x, L"\sigma_x=", σ_x, L"\sigma_y=", σ_y, L"p=", p))
    display(plt)
end

function plot_z_function()
    plt = plot(z -> z_function(0.0, 2.0, 1/z, 1/z), 0, 10000, xlabel="z", ylabel="p(z)")
    display(plt)
end