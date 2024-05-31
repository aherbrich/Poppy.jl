function ranking_update!(feature_values::ValueTable, boards::AbstractArray; loop_eps=1e-3)
    board_values = Vector{Gaussian}()
    sum_factors = Vector{SumFactor}()

    # INITIALIZE FEATURE NODES, BOARD NODES AND SUM FACTORS
    for board in boards
        summands = Vector{Gaussian}()
        for feature in board
            if isnothing(feature_values[feature])
                feature_values[feature] = GaussianByMeanVariance(0.0, 1.0)
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
        push!(gaussian_mean_factors, GaussianMeanFactor(latent_value, board_values[i], 0.5^2))
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
