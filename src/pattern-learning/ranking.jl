using Printf
using Plots

function ranking_update_boardval_model!(feature_values::Dict{UInt64, Gaussian}, boards::AbstractArray; beta::Float64, loop_eps::Float64)    
    #############################################
    # FACTOR GRAPH CREATION
    
    board_values = Vector{Gaussian}()
    sum_factors = Vector{SumFactor}()

    # INITIALIZE FEATURE NODES, BOARD NODES AND SUM FACTORS
    for board in boards
        summands = Vector{Gaussian}()
        nr_of_features = length(board)
        for feature in board
            if !haskey(feature_values, feature)
                feature_values[feature] = GaussianByMeanVariance(0.0, 1.0 / nr_of_features)
            end

            push!(summands, feature_values[feature])
        end
        
        board_value = GaussianUniform()
        push!(board_values, board_value)
        push!(sum_factors, SumFactor(summands, board_value))
    end

    # INITIALIZE LATENT NODES AND FACTORS

    latent_values = Vector{Gaussian}()
    gaussian_mean_factors = Vector{GaussianMeanFactor}()

    for i in eachindex(board_values)
        latent_value = GaussianUniform()
        push!(latent_values, latent_value)
        push!(gaussian_mean_factors, GaussianMeanFactor(latent_value, board_values[i], beta^2))
    end

    # INITIALIZE DIFF NODES, DIFFERENCE FACTORS AND GREATER THAN FACTORS

    difference_values = Vector{Gaussian}()
    difference_factors = Vector{DifferenceFactor}()
    greather_than_factors = Vector{GreaterThanFactor}()

    for i in 2:length(latent_values)
        diff = GaussianUniform()
        push!(difference_values, diff)
        push!(difference_factors, DifferenceFactor(latent_values[1], latent_values[i], diff))
        push!(greather_than_factors, GreaterThanFactor(diff))
    end

    #############################################
    # SUM PRODUCT ALGORITHM

    # FORWARD-PASS: BOARD NODES
    for (i, factor) in enumerate(sum_factors)
        update_msg_to_sum!(factor)
    end


    # FORWARD-PASS: LATENT NODES
    for (i, factor) in enumerate(gaussian_mean_factors)
        update_msg_to_x!(factor)
    end

    # RUN UNTIL LOOP CONVERGES
    ϵ = 10 * loop_eps
    while ϵ > loop_eps
        ϵ = 0.0
        for (i, factor) in enumerate(difference_factors)
            ϵ = max(ϵ, update_msg_to_z!(factor))
            ϵ = max(ϵ, update_msg_to_x!(greather_than_factors[i]))
            ϵ = max(ϵ, update_msg_to_x!(factor))
        end
    end

    # BACKPASS: LATENT NODES
    for (i, factor) in enumerate(difference_factors)
        update_msg_to_y!(factor)
    end

    # BACKPASS: BOARD NODES
    for (i, factor) in enumerate(gaussian_mean_factors)
        update_msg_to_y!(factor)
    end

    # UPDATE FEATURE NODES
    for (i, factor) in enumerate(sum_factors)
        update_msg_to_summands!(factor)
    end
end

function ranking_update_urgency_model!(urgencies::Dict{UInt64, Gaussian}, move_ids::AbstractArray; beta::Float64, loop_eps::Float64)    
    #############################################
    # FACTOR GRAPH CREATION
    
    # INITIALIZE URGENCY NODES
    for move_id in move_ids
        if !haskey(urgencies, move_id)
            urgencies[move_id] = GaussianByMeanVariance(0.0, 1.0)
        end
    end

    # INITIALIZE LATENT NODES AND FACTORS

    latent_values = Vector{Gaussian}()
    gaussian_mean_factors = Vector{GaussianMeanFactor}()

    for move_id in move_ids
        latent_value = GaussianUniform()
        push!(latent_values, latent_value)
        push!(gaussian_mean_factors, GaussianMeanFactor(latent_value, urgencies[move_id], beta^2))
    end

    # INITIALIZE DIFF NODES, DIFFERENCE FACTORS AND GREATER THAN FACTORS

    difference_values = Vector{Gaussian}()
    difference_factors = Vector{DifferenceFactor}()
    greather_than_factors = Vector{GreaterThanFactor}()

    for i in 2:length(latent_values)
        diff = GaussianUniform()
        push!(difference_values, diff)
        push!(difference_factors, DifferenceFactor(latent_values[1], latent_values[i], diff))
        push!(greather_than_factors, GreaterThanFactor(diff))
    end

    #############################################
    # SUM PRODUCT ALGORITHM


    # FORWARD-PASS: LATENT NODES
    for (i, factor) in enumerate(gaussian_mean_factors)
        update_msg_to_x!(factor)
    end

    # RUN UNTIL LOOP CONVERGES
    ϵ = 10 * loop_eps
    while ϵ > loop_eps
        ϵ = 0.0
        for (i, factor) in enumerate(difference_factors)
            ϵ = max(ϵ, update_msg_to_z!(factor))
            ϵ = max(ϵ, update_msg_to_x!(greather_than_factors[i]))
            ϵ = max(ϵ, update_msg_to_x!(factor))
        end
    end

    # BACKPASS: LATENT NODES
    for (i, factor) in enumerate(difference_factors)
        update_msg_to_y!(factor)
    end

    # BACKPASS: BOARD NODES
    for (i, factor) in enumerate(gaussian_mean_factors)
        update_msg_to_y!(factor)
    end
end