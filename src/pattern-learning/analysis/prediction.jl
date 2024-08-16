struct Prediction
    predicted_values::Vector{Float64}
    predicted_rank::Int

    ply_number::Int
    nr_of_possible_moves::Int

    move_type::UInt8
end

function calculate_board_values(urgencies::Dict{UInt64, Gaussian}, boards::Vector{BoardFeatures}; mask_in_prior::Int, no_samples::Int, beta::Float64)
    feature_set = Set{UInt64}()
    for board in boards
        for feature in board
            push!(feature_set, feature)
        end
    end

    mask_prior = mask_in_prior / length(feature_set)

    values = zeros(Float64, length(boards))
    for i in 1:5000
        urgencies_sample = Dict{UInt64, Float64}()
        mask_sample = Dict{UInt64, Float64}()
        for feature in feature_set
            μ = haskey(urgencies, feature) ? gmean(urgencies[feature]) : 0.0
            σ = haskey(urgencies, feature) ? sqrt(variance(urgencies[feature])) : 1.0
            
            urgencies_sample[feature] = rand(Normal(μ, σ))
            mask_sample[feature] = (rand(Bernoulli(mask_prior)) == true) ? 1.0 : 0.0
        end
        
        for (k,board) in enumerate(boards)
            value = 0.0

            for feature in board
                latent_urgency = rand(Normal(urgencies_sample[feature], beta))
                masked_urgency = latent_urgency * mask_sample[feature]
                # if feature == 282
                #     println("masked_urgency: ", masked_urgency)
                # end
                value += masked_urgency
            end

            old_value = values[k]
            new_value = old_value + (value - old_value) / i
            values[k] = new_value
        end
    end

    return values
end

function predict_on(urgencies::Dict{UInt64, Gaussian}, board::Board, legals::Vector{Move}; mask_in_prior::Int, no_samples::Int, beta::Float64)
    features_of_all_boards = extract_features_from_all_boards(board, legals)
    values = calculate_board_values(urgencies, features_of_all_boards, mask_in_prior=mask_in_prior, no_samples=no_samples, beta=beta)
    
    predicted_rank = count(x -> x >= values[1], values) # >= forces s.t. predicted rank is only 1, if it is the (true) maximum (not one of possibly multiple maxima)
    return Prediction(values, predicted_rank, board.ply, length(legals), legals[1].type)
end

function accuracy(predictions::Vector{Prediction})
    return count(x -> x.predicted_rank == 1, predictions) / length(predictions)
end

