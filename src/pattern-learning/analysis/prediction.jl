struct Prediction
    predicted_values::Vector{Float64}
    predicted_rank::Int

    ply_number::Int
    nr_of_possible_moves::Int

    move_type::UInt8
end

function calculate_board_values(urgencies::Dict{UInt64, Gaussian}, boards::AbstractArray; mask_in_prior::Int=2, beta::Float64=1.0, loop_eps::Float64=0.1)
    # BLOCK 1
    feature_set = Set{UInt64}()
    for board in boards
        for feature in board
            if !haskey(urgencies, feature)
                urgencies[feature] = GaussianByMeanVariance(0.0, 1.0 / length(board))
            end
            push!(feature_set, feature)
        end
    end

    mask_prior = min(1.0, mask_in_prior / length(feature_set))

    mask_values = Dict{UInt64, Binary}()
    masked_features = Dict{UInt64, Gaussian}()
    gated_copy_factors = Vector{BinaryGatedCopyFactor}()

    for feature in feature_set
        mask_values[feature] = BinaryByProbability(mask_prior)
        masked_features[feature] = GaussianUniform()
        push!(gated_copy_factors, BinaryGatedCopyFactor(urgencies[feature], masked_features[feature], mask_values[feature]))
    end

    
    # BLOCK 3
    board_values = Vector{Gaussian}()
    sum_factors = Vector{SumFactor}()

    for (k, _) in enumerate(boards)
        summands = Vector{Gaussian}()
        for feature in boards[k]
            push!(summands, masked_features[feature])
        end

        board_value = GaussianUniform()
        push!(board_values, board_value)
        push!(sum_factors, SumFactor(summands, board_value))
    end

    #############################################
    # SUM PRODUCT ALGORITHM

    # FOWARD-PASS: GATED COPY FACTORS
    for factor in gated_copy_factors
        update_msg_to_y!(factor)
    end

    # FORWARD-PASS: SUM NODES
    for factor in sum_factors
        update_msg_to_sum!(factor)
    end
    
    return [mean(board_values[k]) for k in 1:length(boards)]
end

function predict_on(urgencies::Dict{UInt64, Gaussian}, board::Board, legals::Vector{Move}; mask_in_prior::Int, beta::Float64, loop_eps::Float64)
    features_of_all_boards = extract_features_from_all_boards(board, legals)
    values = calculate_board_values(urgencies, features_of_all_boards, mask_in_prior=mask_in_prior, beta=beta, loop_eps=loop_eps)
    
    predicted_rank = count(x -> x >= values[1], values) # >= forces s.t. predicted rank is only 1, if it is the (true) maximum (not one of possibly multiple maxima)
    return Prediction(values, predicted_rank, board.ply, length(legals), legals[1].type)
end

function accuracy(predictions::Vector{Prediction})
    return count(x -> x.predicted_rank == 1, predictions) / length(predictions)
end

